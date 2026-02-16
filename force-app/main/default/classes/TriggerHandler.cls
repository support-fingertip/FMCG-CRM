/**
 * @description Abstract base class for all trigger handlers in the SFA application.
 *              Provides a standardized framework for trigger execution with recursion
 *              prevention, bypass capabilities, and context-aware dispatch.
 *
 * Usage:
 *   public class MyObjectHandler extends TriggerHandler {
 *       protected override void beforeInsert() { // logic }
 *   }
 *
 *   trigger MyObjectTrigger on MyObject__c (...) {
 *       new MyObjectHandler().run();
 *   }
 *
 * @author  SFA Development Team
 * @date    2024
 */
public abstract class TriggerHandler {

    // ── Static recursion & bypass management ──────────────────────────────────

    /** Tracks the number of times each handler executed per handler + context. */
    @TestVisible
    private static Map<String, Integer> executionCountMap = new Map<String, Integer>();

    /** Maximum allowed executions per handler + context per transaction. */
    @TestVisible
    private static Map<String, Integer> maxExecutionMap = new Map<String, Integer>();

    /** Set of handler names currently bypassed. */
    @TestVisible
    private static Set<String> bypassedHandlers = new Set<String>();

    // ── Instance variables ────────────────────────────────────────────────────

    /** Handler name used for bypass tracking. */
    @TestVisible
    private String handlerName;

    /** Current trigger context. */
    @TestVisible
    private System.TriggerOperation triggerContext;

    // ── Constructor ───────────────────────────────────────────────────────────

    public TriggerHandler() {
        // Works in older orgs: avoid getClass()
        this.handlerName = resolveHandlerName();
        this.setTriggerContext();
    }

    // ── Public entry point ────────────────────────────────────────────────────

    public void run() {
        if (this.triggerContext == null) {
            throw new TriggerHandlerException(
                'TriggerHandler.run() was called outside of a trigger context. ' +
                'Handler: ' + this.handlerName
            );
        }

        if (isBypassed(this.handlerName)) {
            return;
        }

        if (hasExceededMaxExecutions()) {
            return;
        }

        incrementExecutionCount();

        switch on this.triggerContext {
            when BEFORE_INSERT  { this.beforeInsert(); }
            when BEFORE_UPDATE  { this.beforeUpdate(); }
            when BEFORE_DELETE  { this.beforeDelete(); }
            when AFTER_INSERT   { this.afterInsert(); }
            when AFTER_UPDATE   { this.afterUpdate(); }
            when AFTER_DELETE   { this.afterDelete(); }
            when AFTER_UNDELETE { this.afterUndelete(); }
        }
    }

    // ── Virtual methods for subclass override ─────────────────────────────────

    protected virtual void beforeInsert() {}
    protected virtual void beforeUpdate() {}
    protected virtual void beforeDelete() {}
    protected virtual void afterInsert() {}
    protected virtual void afterUpdate() {}
    protected virtual void afterDelete() {}
    protected virtual void afterUndelete() {}

    // ── Bypass management (static) ────────────────────────────────────────────

    public static void bypass(String handlerName) {
        bypassedHandlers.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        bypassedHandlers.remove(handlerName);
    }

    public static Boolean isBypassed(String handlerName) {
        return bypassedHandlers.contains(handlerName);
    }

    public static void clearAllBypasses() {
        bypassedHandlers.clear();
    }

    // ── Max-execution management ──────────────────────────────────────────────

    /**
     * @description Sets max executions for this handler in the current trigger context.
     *              Call this inside constructor or inside overridden methods if needed.
     */
    public void setMaxExecutions(Integer max) {
        if (this.triggerContext == null) {
            // if someone calls this outside trigger, ignore
            return;
        }
        maxExecutionMap.put(getExecutionKey(), max);
    }

    /** Clears max executions for all handlers (useful in tests). */
    public static void resetAllMaxExecutions() {
        maxExecutionMap.clear();
    }

    // ── Execution-count helpers ───────────────────────────────────────────────

    /** Resets execution count for all handlers (useful in tests). */
    public static void resetAllExecutionCounts() {
        executionCountMap.clear();
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @description Sets trigger context from runtime (null if not in trigger).
     */
    @TestVisible
    private void setTriggerContext() {
        if (Trigger.isExecuting) {
            this.triggerContext = Trigger.operationType;
        }
    }

    /**
     * @description Stable handler name resolution without getClass().
     *              Example String.valueOf(this): "MyHandler: [some id]"
     */
    @TestVisible
    private String resolveHandlerName() {
        String s = String.valueOf(this);
        if (s != null && s.contains(':')) {
            return s.substringBefore(':');
        }
        return s;
    }

    /**
     * @description Returns key for recursion limit tracking.
     *              Uses handlerName + triggerContext so contexts don't collide.
     */
    private String getExecutionKey() {
        return this.handlerName + '|' + String.valueOf(this.triggerContext);
    }

    /**
     * @description Increments execution count for this handler + context.
     */
    private void incrementExecutionCount() {
        String key = getExecutionKey();
        Integer count = executionCountMap.containsKey(key) ? executionCountMap.get(key) : 0;
        executionCountMap.put(key, count + 1);
    }

    /**
     * @description Checks whether this handler exceeded configured max executions.
     */
    private Boolean hasExceededMaxExecutions() {
        String key = getExecutionKey();
        if (!maxExecutionMap.containsKey(key)) {
            return false; // unlimited by default
        }
        Integer max = maxExecutionMap.get(key);
        Integer current = executionCountMap.containsKey(key) ? executionCountMap.get(key) : 0;
        return current >= max;
    }
}