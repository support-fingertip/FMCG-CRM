'use strict';

require('dotenv').config();

const REQUIRED = ['SF_CLIENT_ID', 'SF_CLIENT_SECRET', 'JWT_SECRET'];

function loadConfig() {
  const missing = REQUIRED.filter((k) => !process.env[k] || process.env[k].startsWith('your_') || process.env[k].startsWith('replace_me'));
  if (missing.length > 0) {
    // Fail fast at boot rather than produce cryptic runtime errors.
    throw new Error(
      `Missing or placeholder env vars: ${missing.join(', ')}. ` +
        `Copy .env.example to .env and fill in real values.`
    );
  }

  return {
    SF_LOGIN_URL: process.env.SF_LOGIN_URL || 'https://login.salesforce.com',
    SF_CLIENT_ID: process.env.SF_CLIENT_ID,
    SF_CLIENT_SECRET: process.env.SF_CLIENT_SECRET,
    JWT_SECRET: process.env.JWT_SECRET,
    JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '1h',
    PORT: parseInt(process.env.PORT || '3000', 10),
    CORS_ORIGIN: process.env.CORS_ORIGIN || '*',
  };
}

// In tests we want to construct config on demand with mocked env, so export
// a factory in addition to a lazy singleton.
let cached;
module.exports = new Proxy(
  {},
  {
    get(_target, prop) {
      if (prop === '__load') return loadConfig;
      if (!cached) cached = loadConfig();
      return cached[prop];
    },
  }
);
