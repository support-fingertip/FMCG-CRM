# Salesforce Login Integration (JWT) for the Flutter App

This folder contains everything needed to let a Flutter mobile app authenticate
Salesforce users with their SF username + password and then use a **JSON Web
Token (JWT)** as the session credential for subsequent API calls.

```
Flutter app ──(username+password)──▶ Node backend ──(OAuth2 password grant)──▶ Salesforce
        ▲                                 │
        └───────── JWT session token ◀────┘
```

## Why a backend proxy?

Salesforce's Username-Password OAuth flow requires the Connected App's
`consumer_secret`. Shipping a secret inside a mobile binary is insecure — it
is trivially extracted. The backend in `backend/` keeps the secret
server-side, validates credentials against Salesforce, and mints an app-scoped
JWT that the Flutter app can safely hold.

## 1. One-time: create the Salesforce Connected App

In your Salesforce org: **Setup → App Manager → New Connected App**.

1. Enable **OAuth Settings**.
2. Callback URL: `http://localhost` (unused by this flow but required by SF).
3. Selected OAuth Scopes:
   - Access and manage your data (`api`)
   - Perform requests on your behalf at any time (`refresh_token, offline_access`)
   - Access the identity URL service (`id, profile, email, address, phone`)
4. Save, then open **Manage → Edit Policies**:
   - Permitted Users: *All users may self-authorize*
   - IP Relaxation: *Relax IP restrictions* (for dev; tighten for prod)
5. From the Connected App detail page, copy:
   - **Consumer Key** → `SF_CLIENT_ID`
   - **Consumer Secret** → `SF_CLIENT_SECRET`

> Users logging in from an untrusted IP range must append their **security
> token** to their password. The token is emailed to them by Salesforce the
> first time they log in from a new IP, or regeneratable under *Settings →
> Reset My Security Token*.

## 2. Run the backend

```bash
cd external-app/backend
cp .env.example .env
# Fill in SF_CLIENT_ID, SF_CLIENT_SECRET, and a long random JWT_SECRET.
# Generate a JWT_SECRET with:
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"

npm install
npm start
# → Auth backend listening on http://localhost:3000
```

### Endpoints

| Method | Path         | Description                                                                          |
|--------|--------------|--------------------------------------------------------------------------------------|
| GET    | `/health`    | Liveness probe.                                                                      |
| POST   | `/auth/login`| Body `{username, password}`. Returns `{token, expiresIn}` on success, 401 on failure.|
| GET    | `/auth/me`   | Protected. Requires `Authorization: Bearer <jwt>`. Returns decoded claims.           |

### Manual smoke test

```bash
# 1. Valid credentials (password includes security token if needed)
curl -s -X POST http://localhost:3000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"user@example.com","password":"MyPass<SECURITY_TOKEN>"}'
# → {"token":"eyJ...","expiresIn":"1h"}

# 2. Invalid credentials
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:3000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"user@example.com","password":"wrong"}'
# → 401

# 3. Protected call with JWT
curl -s http://localhost:3000/auth/me -H "Authorization: Bearer <token>"
# → {"user":{"sub":"...","username":"user@example.com","instanceUrl":"...","iat":...,"exp":...}}
```

### Tests

```bash
cd external-app/backend
npm test
```

Unit tests mock the Salesforce service, so they never hit the network.

## 3. Integrate with the Flutter app

The files under `mobile/lib/` are **reference snippets** — copy them into
your existing Flutter project and adapt as needed.

Add to `pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
```

Wire-up:

- `mobile/lib/services/auth_service.dart` — `login()`, `logout()`, `getToken()`, `isLoggedIn()`. Stores the JWT in OS secure storage (Keychain / Keystore). Never use `SharedPreferences` for tokens.
- `mobile/lib/services/api_client.dart` — Dio instance with an interceptor that attaches `Authorization: Bearer <jwt>` automatically and clears the token on `401`.
- `mobile/lib/screens/login_screen.dart` — a minimal username/password form.
- `mobile/lib/main.dart` — example of routing between `LoginScreen` and a home screen based on `isLoggedIn()`.

### Point the app at the backend

The example `main.dart` uses the `BACKEND_BASE_URL` compile-time env var with
a default of `http://10.0.2.2:3000` (the Android emulator's route to the
host's `localhost`). Pass a real URL when building:

```bash
flutter run --dart-define=BACKEND_BASE_URL=https://api.yourcompany.com
```

For iOS simulator use `http://localhost:3000`; for a physical device use your
LAN IP during development, or the deployed HTTPS URL in production.

## Security checklist

- `client_secret` lives **only** in `backend/.env`, never in the Flutter app.
- The backend MUST be reached over HTTPS in production.
- `JWT_SECRET` is ≥32 random bytes; rotate if compromised.
- The backend never logs or persists the password.
- `/auth/login` is rate-limited (20 requests / 15 min / IP) to slow credential stuffing.
- `.env` is gitignored; only `.env.example` is committed.
- The SF access token is **not** returned to the mobile app — it stays server-side. If you later need to call Salesforce REST APIs on the user's behalf, proxy those calls through a new backend endpoint so the access token never leaves the server.

## Out of scope (future work)

- Refresh tokens / silent re-auth when JWT expires.
- Proxy endpoints for Salesforce REST/SOQL calls using the cached SF access token (likely backed by Redis).
- MFA / SSO flows — requires switching from Username-Password to the OAuth2 Web Server Flow (browser redirect).
- Production deploy: Docker image, reverse proxy (nginx/Caddy), secrets manager (AWS SM / GCP SM).
