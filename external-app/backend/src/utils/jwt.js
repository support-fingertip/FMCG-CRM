'use strict';

const jwt = require('jsonwebtoken');
const config = require('../config');

function signToken(payload) {
  return jwt.sign(payload, config.JWT_SECRET, {
    expiresIn: config.JWT_EXPIRES_IN,
    algorithm: 'HS256',
  });
}

function verifyToken(token) {
  return jwt.verify(token, config.JWT_SECRET, { algorithms: ['HS256'] });
}

module.exports = { signToken, verifyToken };
