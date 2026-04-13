'use strict';

const express = require('express');
const rateLimit = require('express-rate-limit');

const config = require('../config');
const { authenticateWithSalesforce } = require('../services/salesforce');
const { signToken } = require('../utils/jwt');
const { verifyJwt } = require('../middleware/authMiddleware');

const router = express.Router();

// Basic protection against credential-stuffing. Tune for your traffic.
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too_many_login_attempts' },
});

/**
 * POST /auth/login
 * Body: { username: string, password: string }
 * Note: if the user is logging in from an untrusted IP, `password` must be
 * the SF password concatenated with their security token.
 */
router.post('/login', loginLimiter, async (req, res) => {
  const { username, password } = req.body || {};

  if (typeof username !== 'string' || typeof password !== 'string' || !username || !password) {
    return res.status(400).json({ error: 'username_and_password_required' });
  }

  const result = await authenticateWithSalesforce(username, password);

  if (!result.ok) {
    // Do not leak Salesforce's raw error text to the client beyond a generic
    // message — it can aid enumeration.
    return res.status(401).json({ error: 'invalid_credentials' });
  }

  const token = signToken({
    sub: result.sfUserId,
    username,
    instanceUrl: result.instanceUrl,
  });

  return res.json({ token, expiresIn: config.JWT_EXPIRES_IN });
});

/**
 * GET /auth/me
 * Example protected route. Returns the decoded JWT claims for the caller.
 */
router.get('/me', verifyJwt, (req, res) => {
  res.json({ user: req.user });
});

module.exports = router;
