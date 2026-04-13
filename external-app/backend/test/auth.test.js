'use strict';

// Populate env BEFORE requiring any modules that read config.
process.env.SF_LOGIN_URL = 'https://login.salesforce.com';
process.env.SF_CLIENT_ID = 'test_client_id';
process.env.SF_CLIENT_SECRET = 'test_client_secret';
process.env.JWT_SECRET = 'test_jwt_secret_value_long_enough_for_hs256_signing';
process.env.JWT_EXPIRES_IN = '1h';

// Mock the Salesforce service so tests never hit the network.
jest.mock('../src/services/salesforce', () => ({
  authenticateWithSalesforce: jest.fn(),
}));

const request = require('supertest');
const { authenticateWithSalesforce } = require('../src/services/salesforce');
const { createApp } = require('../src/server');
const { signToken } = require('../src/utils/jwt');

const app = createApp();

afterEach(() => {
  jest.clearAllMocks();
});

describe('POST /auth/login', () => {
  test('returns a JWT when Salesforce accepts the credentials', async () => {
    authenticateWithSalesforce.mockResolvedValueOnce({
      ok: true,
      sfAccessToken: 'sf_access_token_xyz',
      instanceUrl: 'https://example.my.salesforce.com',
      sfUserId: 'https://login.salesforce.com/id/00Dxx/005xx',
    });

    const res = await request(app)
      .post('/auth/login')
      .send({ username: 'user@example.com', password: 'pw+token' });

    expect(res.status).toBe(200);
    expect(res.body.token).toMatch(/^eyJ/);
    expect(res.body.expiresIn).toBe('1h');
    expect(authenticateWithSalesforce).toHaveBeenCalledWith('user@example.com', 'pw+token');
  });

  test('returns 401 when Salesforce rejects the credentials', async () => {
    authenticateWithSalesforce.mockResolvedValueOnce({
      ok: false,
      status: 400,
      error: 'authentication failure',
    });

    const res = await request(app)
      .post('/auth/login')
      .send({ username: 'user@example.com', password: 'wrong' });

    expect(res.status).toBe(401);
    expect(res.body.error).toBe('invalid_credentials');
  });

  test('returns 400 when body is missing fields', async () => {
    const res = await request(app).post('/auth/login').send({ username: 'only-user' });
    expect(res.status).toBe(400);
    expect(authenticateWithSalesforce).not.toHaveBeenCalled();
  });
});

describe('GET /auth/me', () => {
  test('rejects a request with no Authorization header', async () => {
    const res = await request(app).get('/auth/me');
    expect(res.status).toBe(401);
  });

  test('rejects an invalid token', async () => {
    const res = await request(app)
      .get('/auth/me')
      .set('Authorization', 'Bearer not.a.real.token');
    expect(res.status).toBe(401);
  });

  test('accepts a valid token and returns its claims', async () => {
    const token = signToken({ sub: 'sf-id-1', username: 'user@example.com', instanceUrl: 'https://x' });
    const res = await request(app)
      .get('/auth/me')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.user.username).toBe('user@example.com');
    expect(res.body.user.instanceUrl).toBe('https://x');
  });
});
