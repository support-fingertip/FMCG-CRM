'use strict';

const express = require('express');
const cors = require('cors');

const config = require('./config');
const authRoutes = require('./routes/auth');

function createApp() {
  const app = express();

  app.use(cors({ origin: config.CORS_ORIGIN }));
  app.use(express.json({ limit: '64kb' }));

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));
  app.use('/auth', authRoutes);

  // Fallback 404
  app.use((_req, res) => res.status(404).json({ error: 'not_found' }));

  return app;
}

if (require.main === module) {
  const app = createApp();
  app.listen(config.PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`Auth backend listening on http://localhost:${config.PORT}`);
  });
}

module.exports = { createApp };
