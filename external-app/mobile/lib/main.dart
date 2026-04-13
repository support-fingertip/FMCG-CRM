// Reference entry point showing how to wire AuthService + LoginScreen into
// an existing Flutter app. On real devices, `backendBaseUrl` should point at
// your deployed backend over HTTPS. During development with an Android
// emulator, localhost on the host machine is reachable via 10.0.2.2.

import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

void main() {
  runApp(const FmcgCrmApp());
}

class FmcgCrmApp extends StatefulWidget {
  const FmcgCrmApp({super.key});

  @override
  State<FmcgCrmApp> createState() => _FmcgCrmAppState();
}

class _FmcgCrmAppState extends State<FmcgCrmApp> {
  late final AuthService _auth = AuthService(backendBaseUrl: backendBaseUrl);
  late final ApiClient _api = ApiClient(baseUrl: backendBaseUrl, authService: _auth);
  bool? _loggedIn;

  @override
  void initState() {
    super.initState();
    _auth.isLoggedIn().then((v) => setState(() => _loggedIn = v));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FMCG CRM',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: _loggedIn == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _loggedIn!
              ? _HomeScreen(api: _api, onLogout: () async {
                  await _auth.logout();
                  setState(() => _loggedIn = false);
                })
              : LoginScreen(
                  authService: _auth,
                  onLoginSuccess: () => setState(() => _loggedIn = true),
                ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({required this.api, required this.onLogout});

  final ApiClient api;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [IconButton(onPressed: onLogout, icon: const Icon(Icons.logout))],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: api.me(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Signed in as: ${snapshot.data}'),
          );
        },
      ),
    );
  }
}
