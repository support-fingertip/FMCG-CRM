'use strict';

const { verifyToken } = require('../utils/jwt');

/**
 * Express middleware that requires a valid Bearer JWT.
 * On success, attaches decoded claims to `req.user`.
 */
function verifyJwt(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'missing_or_malformed_authorization_header' });
  }

  try {
    req.user = verifyToken(token);
    return next();
  } catch (err) {
    return res.status(401).json({ error: 'invalid_or_expired_token' });
  }
}

module.exports = { verifyJwt };
