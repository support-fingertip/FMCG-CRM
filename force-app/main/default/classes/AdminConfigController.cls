/**
 * @description Controller for the Admin Configuration LWC component.
 *              Provides read/write access to custom metadata configuration records
 *              including Feature Toggles, App Configs, and Geo Configs.
 *              Uses the Metadata.DeployContainer approach for custom metadata updates.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class AdminConfigController {

    // ── Get Feature Toggles ─────────────────────────────────────────────────────

    /**
     * @description Retrieves all Feature_Toggle__mdt custom metadata records.
     * @return List of Feature_Toggle__mdt records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Feature_Toggle__mdt> getFeatureToggles() {
        return [
            SELECT Id, DeveloperName, MasterLabel, Feature_Code__c, Is_Enabled__c,
                   Module__c, Description__c, Package_Tier__c
            FROM Feature_Toggle__mdt
            ORDER BY Module__c, MasterLabel
        ];
    }

    // ── Update Feature Toggle ───────────────────────────────────────────────────

    /**
     * @description Updates the Is_Enabled__c field on a Feature_Toggle__mdt record
     *              using the Metadata.DeployContainer approach (the only way to
     *              update custom metadata from Apex at runtime).
     * @param developerName The DeveloperName of the Feature Toggle to update.
     * @param isEnabled     The new enabled/disabled state.
     * @return Success message string.
     */
    @AuraEnabled
    public static String updateFeatureToggle(String developerName, Boolean isEnabled) {
        try {
            if (String.isBlank(developerName)) {
                throw new AuraHandledException('Developer name is required.');
            }

            // Verify the record exists
            List<Feature_Toggle__mdt> existing = [
                SELECT Id, DeveloperName, MasterLabel
                FROM Feature_Toggle__mdt
                WHERE DeveloperName = :developerName
                LIMIT 1
            ];
            if (existing.isEmpty()) {
                throw new AuraHandledException(
                    'Feature toggle with developer name "' + developerName + '" not found.'
                );
            }

            // Build the custom metadata record for deployment
            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            customMetadata.fullName = 'Feature_Toggle__mdt.' + developerName;
            customMetadata.label = existing[0].MasterLabel;

            Metadata.CustomMetadataValue isEnabledField = new Metadata.CustomMetadataValue();
            isEnabledField.field = 'Is_Enabled__c';
            isEnabledField.value = isEnabled;
            customMetadata.values.add(isEnabledField);

            // Deploy using container
            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(customMetadata);

            // Enqueue the deployment
            Id deployJobId = Metadata.Operations.enqueueDeployment(
                container,
                new AdminConfigDeployCallback()
            );

            return 'Feature toggle update queued. Deployment Job Id: ' + deployJobId;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to update feature toggle: ' + e.getMessage());
        }
    }

    // ── Get App Configs ─────────────────────────────────────────────────────────

    /**
     * @description Retrieves all App_Config__mdt custom metadata records.
     * @return List of App_Config__mdt records.
     */
    @AuraEnabled(cacheable=true)
    public static List<App_Config__mdt> getAppConfigs() {
        return [
            SELECT Id, DeveloperName, MasterLabel, Config_Key__c, Config_Value__c,
                   Data_Type__c, Description__c, Module__c
            FROM App_Config__mdt
            ORDER BY Module__c, Config_Key__c
        ];
    }

    // ── Get Geo Configs ─────────────────────────────────────────────────────────

    /**
     * @description Retrieves all Geo_Config__mdt custom metadata records.
     * @return List of Geo_Config__mdt records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Geo_Config__mdt> getGeoConfigs() {
        return [
            SELECT Id, DeveloperName, MasterLabel, Config_Type__c, Value__c
            FROM Geo_Config__mdt
            ORDER BY Config_Type__c
        ];
    }

    // ── Export Config ───────────────────────────────────────────────────────────

    /**
     * @description Exports all custom metadata configuration as a JSON string.
     *              Useful for backup, migration, or environment comparison.
     * @return JSON string containing all configuration records.
     */
    @AuraEnabled
    public static String exportConfig() {
        try {
            Map<String, Object> configExport = new Map<String, Object>();

            // Feature Toggles
            List<Feature_Toggle__mdt> toggles = [
                SELECT DeveloperName, MasterLabel, Feature_Code__c, Is_Enabled__c,
                       Module__c, Description__c, Package_Tier__c
                FROM Feature_Toggle__mdt
                ORDER BY DeveloperName
            ];
            List<Map<String, Object>> toggleList = new List<Map<String, Object>>();
            for (Feature_Toggle__mdt ft : toggles) {
                Map<String, Object> m = new Map<String, Object>();
                m.put('developerName', ft.DeveloperName);
                m.put('label', ft.MasterLabel);
                m.put('featureCode', ft.Feature_Code__c);
                m.put('isEnabled', ft.Is_Enabled__c);
                m.put('module', ft.Module__c);
                m.put('description', ft.Description__c);
                m.put('packageTier', ft.Package_Tier__c);
                toggleList.add(m);
            }
            configExport.put('featureToggles', toggleList);

            // App Configs
            List<App_Config__mdt> appConfigs = [
                SELECT DeveloperName, MasterLabel, Config_Key__c, Config_Value__c,
                       Data_Type__c, Description__c, Module__c
                FROM App_Config__mdt
                ORDER BY DeveloperName
            ];
            List<Map<String, Object>> appConfigList = new List<Map<String, Object>>();
            for (App_Config__mdt ac : appConfigs) {
                Map<String, Object> m = new Map<String, Object>();
                m.put('developerName', ac.DeveloperName);
                m.put('label', ac.MasterLabel);
                m.put('configKey', ac.Config_Key__c);
                m.put('configValue', ac.Config_Value__c);
                m.put('dataType', ac.Data_Type__c);
                m.put('description', ac.Description__c);
                m.put('module', ac.Module__c);
                appConfigList.add(m);
            }
            configExport.put('appConfigs', appConfigList);

            // Geo Configs
            List<Geo_Config__mdt> geoConfigs = [
                SELECT DeveloperName, MasterLabel, Config_Type__c, Value__c
                FROM Geo_Config__mdt
                ORDER BY DeveloperName
            ];
            List<Map<String, Object>> geoConfigList = new List<Map<String, Object>>();
            for (Geo_Config__mdt gc : geoConfigs) {
                Map<String, Object> m = new Map<String, Object>();
                m.put('developerName', gc.DeveloperName);
                m.put('label', gc.MasterLabel);
                m.put('configType', gc.Config_Type__c);
                m.put('value', gc.Value__c);
                geoConfigList.add(m);
            }
            configExport.put('geoConfigs', geoConfigList);

            // Add metadata
            Map<String, Object> metadata = new Map<String, Object>();
            metadata.put('exportDate', Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ'));
            metadata.put('exportedBy', UserInfo.getUserName());
            metadata.put('orgId', UserInfo.getOrganizationId());
            metadata.put('orgName', UserInfo.getOrganizationName());
            configExport.put('metadata', metadata);

            return JSON.serializePretty(configExport);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to export configuration: ' + e.getMessage());
        }
    }

    // ── Update App Config ───────────────────────────────────────────────────────

    /**
     * @description Updates an App_Config__mdt custom metadata record.
     * @param configId The Id of the App Config to update.
     * @param value The new value for the config.
     * @return Success message string.
     */
    @AuraEnabled
    public static String updateAppConfig(String configId, String value) {
        try {
            if (String.isBlank(configId)) {
                throw new AuraHandledException('Config ID is required.');
            }

            // Verify the record exists
            List<App_Config__mdt> existing = [
                SELECT Id, DeveloperName, MasterLabel
                FROM App_Config__mdt
                WHERE Id = :configId
                LIMIT 1
            ];
            if (existing.isEmpty()) {
                throw new AuraHandledException(
                    'App config with ID "' + configId + '" not found.'
                );
            }

            // Build the custom metadata record for deployment
            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            customMetadata.fullName = 'App_Config__mdt.' + existing[0].DeveloperName;
            customMetadata.label = existing[0].MasterLabel;

            Metadata.CustomMetadataValue valueField = new Metadata.CustomMetadataValue();
            valueField.field = 'Config_Value__c';
            valueField.value = value;
            customMetadata.values.add(valueField);

            // Deploy using container
            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(customMetadata);

            // Enqueue the deployment
            Id deployJobId = Metadata.Operations.enqueueDeployment(
                container,
                new AdminConfigDeployCallback()
            );

            return 'App config update queued. Deployment Job Id: ' + deployJobId;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to update app config: ' + e.getMessage());
        }
    }

    // ── Update Geo Config ───────────────────────────────────────────────────────

    /**
     * @description Updates a Geo_Config__mdt custom metadata record.
     *@param geoJson JSON string containing geo config data to update.
     * @return Success message string.
     */
    @AuraEnabled
    public static String updateGeoConfig(String geoJson) {
        try {
            if (String.isBlank(geoJson)) {
                throw new AuraHandledException('Geo config JSON is required.');
            }

            // Parse the JSON
            Map<String, Object> geoData = (Map<String, Object>) JSON.deserializeUntyped(geoJson);
            
            // Extract the geofence radius
            Integer geofenceRadius = (Integer) geoData.get('geofenceRadius');
            if (geofenceRadius == null) {
                throw new AuraHandledException('Geofence radius is required.');
            }
            
            // Find the existing geo config record
            List<Geo_Config__mdt> existing = [
                SELECT Id, DeveloperName, MasterLabel
                FROM Geo_Config__mdt
                WHERE Config_Type__c = 'Geofence_Radius'
                LIMIT 1
            ];
            
            if (existing.isEmpty()) {
                throw new AuraHandledException('Geofence Radius config not found.');
            }

            // Build the custom metadata record for deployment
            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            customMetadata.fullName = 'Geo_Config__mdt.' + existing[0].DeveloperName;
            customMetadata.label = existing[0].MasterLabel;

            Metadata.CustomMetadataValue valueField = new Metadata.CustomMetadataValue();
            valueField.field = 'Value__c';
            valueField.value = String.valueOf(geofenceRadius);
            customMetadata.values.add(valueField);

            // Deploy using container
            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(customMetadata);

            // Enqueue the deployment
            Id deployJobId = Metadata.Operations.enqueueDeployment(
                container,
                new AdminConfigDeployCallback()
            );

            return 'Geo config update queued. Deployment Job Id: ' + deployJobId;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to update geo config: ' + e.getMessage());
        }
    }

    // ── Import Config ───────────────────────────────────────────────────────────

    /**
     * @description Imports configuration from a JSON string.
     * @param configJson JSON string containing configuration data.
     * @return Success message string.
     */
    @AuraEnabled
    public static String importConfig(String configJson) {
        try {
            if (String.isBlank(configJson)) {
                throw new AuraHandledException('Configuration JSON is required.');
            }

            // Parse the JSON
            Map<String, Object> configData = (Map<String, Object>) JSON.deserializeUntyped(configJson);
            
            // Process feature toggles
            if (configData.containsKey('featureToggles')) {
                List<Object> toggles = (List<Object>) configData.get('featureToggles');
                for (Object toggleObj : toggles) {
                    Map<String, Object> toggle = (Map<String, Object>) toggleObj;
                    String developerName = (String) toggle.get('developerName');
                    Boolean isEnabled = (Boolean) toggle.get('isEnabled');
                    
                    if (developerName != null && isEnabled != null) {
                        updateFeatureToggle(developerName, isEnabled);
                    }
                }
            }
            
            // Process app configs
            if (configData.containsKey('appConfigs')) {
                List<Object> appConfigs = (List<Object>) configData.get('appConfigs');

                // Bulk-query all App_Config__mdt records and build a Map by DeveloperName
                Map<String, App_Config__mdt> appConfigByDevName = new Map<String, App_Config__mdt>();
                for (App_Config__mdt ac : [
                    SELECT Id, DeveloperName, MasterLabel
                    FROM App_Config__mdt
                ]) {
                    appConfigByDevName.put(ac.DeveloperName, ac);
                }

                for (Object configObj : appConfigs) {
                    Map<String, Object> config = (Map<String, Object>) configObj;
                    String developerName = (String) config.get('developerName');
                    String value = (String) config.get('configValue');

                    if (developerName != null && value != null) {
                        App_Config__mdt existing = appConfigByDevName.get(developerName);
                        if (existing != null) {
                            updateAppConfig(existing.Id, value);
                        }
                    }
                }
            }

            // Process geo configs
            if (configData.containsKey('geoConfigs')) {
                List<Object> geoConfigs = (List<Object>) configData.get('geoConfigs');

                // Bulk-query all Geo_Config__mdt records and build a Map by Config_Type__c
                Map<String, Geo_Config__mdt> geoConfigByType = new Map<String, Geo_Config__mdt>();
                for (Geo_Config__mdt gc : [
                    SELECT Id, DeveloperName, MasterLabel, Config_Type__c
                    FROM Geo_Config__mdt
                ]) {
                    geoConfigByType.put(gc.Config_Type__c, gc);
                }

                for (Object configObj : geoConfigs) {
                    Map<String, Object> config = (Map<String, Object>) configObj;
                    String configType = (String) config.get('configType');
                    String value = (String) config.get('value');

                    if (configType != null && value != null) {
                        // For simplicity, we'll just update the geofence radius
                        if (configType == 'Geofence_Radius') {
                            Geo_Config__mdt existing = geoConfigByType.get(configType);
                            if (existing != null) {
                                // Convert to integer and update
                                Integer intValue = Integer.valueOf(value);
                                updateGeoConfig(JSON.serialize(new Map<String, Object>{
                                    'geofenceRadius' => intValue
                                }));
                            }
                        }
                    }
                }
            }
            
            return 'Configuration imported successfully.';
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to import configuration: ' + e.getMessage());
        }
    }

    // ── Deploy Callback Inner Class ─────────────────────────────────────────────

    /**
     * @description Callback handler for Metadata API deployments. Logs results
     *              for admin visibility.
     */
    public class AdminConfigDeployCallback implements Metadata.DeployCallback {
        public void handleResult(Metadata.DeployResult result,
                                 Metadata.DeployCallbackContext context) {
            if (result.status == Metadata.DeployStatus.Succeeded) {
                System.debug(LoggingLevel.INFO,
                    'AdminConfig metadata deployment succeeded. Id: ' + result.id);
            } else {
                System.debug(LoggingLevel.ERROR,
                    'AdminConfig metadata deployment failed. Id: ' + result.id +
                    ' Status: ' + result.status);
                if (result.details != null && result.details.componentFailures != null) {
                    for (Metadata.DeployMessage msg : result.details.componentFailures) {
                        System.debug(LoggingLevel.ERROR,
                            'Component failure: ' + msg.fullName + ' - ' + msg.problem);
                    }
                }
            }
        }
    }
}