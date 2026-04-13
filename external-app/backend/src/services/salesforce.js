'use strict';

const axios = require('axios');
const config = require('../config');

/**
 * Authenticate a Salesforce user via the OAuth2 Username-Password flow.
 *
 * Docs: https://help.salesforce.com/s/articleView?id=sf.remoteaccess_oauth_username_password_flow.htm
 *
 * NOTE: If the user's login IP is NOT in the org's trusted IP range, the
 * `password` argument MUST be the user's password concatenated with their
 * Salesforce security token (no separator). Callers are responsible for that.
 *
 * @param {string} username - Salesforce username (typically an email).
 * @param {string} password - Password, or password + security token.
 * @returns {Promise<{ok: true, sfAccessToken: string, instanceUrl: string, sfUserId: string} | {ok: false, error: string, status: number}>}
 */
async function authenticateWithSalesforce(username, password) {
  const url = `${config.SF_LOGIN_URL}/services/oauth2/token`;

  const params = new URLSearchParams({
    grant_type: 'password',
    client_id: config.SF_CLIENT_ID,
    client_secret: config.SF_CLIENT_SECRET,
    username,
    password,
  });

  try {
    const { data } = await axios.post(url, params.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      timeout: 10_000,
    });

    return {
      ok: true,
      sfAccessToken: data.access_token,
      instanceUrl: data.instance_url,
      // `data.id` is the identity URL, e.g. https://login.salesforce.com/id/<orgId>/<userId>
      sfUserId: data.id,
      issuedAt: data.issued_at,
    };
  } catch (err) {
    const status = err.response?.status || 500;
    const error = err.response?.data?.error_description
      || err.response?.data?.error
      || 'authentication_failed';
    return { ok: false, status, error };
  }
}

module.exports = { authenticateWithSalesforce };
