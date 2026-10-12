import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  const LoginScreen({super.key, required this.onSignedIn});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final home = TextEditingController(text: api.servers.isNotEmpty ? api.servers[0] : '');
  final away = TextEditingController(text: api.servers.length > 1 ? api.servers[1] : '');
  final user = TextEditingController(text: api.username ?? '');
  final pass = TextEditingController();
  final code = TextEditingController();
  bool needCode = false, busy = false;
  String? error;

  Future<void> _go() async {
    setState(() { busy = true; error = null; });
    try {
      await api.saveServers([home.text, away.text]);
      await api.login(user.text.trim(), pass.text, code: code.text.trim());
      widget.onSignedIn();
    } on ApiError catch (e) {
      setState(() {
        error = e.message;
        if (e.reason == 'totp' || e.reason == 'totp_bad') needCode = true;
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: Image.asset('assets/logo.png', width: 88, height: 88)),
                const SizedBox(height: 8),
                Text('MediaLedger', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 22),
                TextField(controller: home, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Home address', hintText: 'https://medialedger.home')),
                const SizedBox(height: 10),
                TextField(controller: away, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Away address (optional)')),
                const SizedBox(height: 18),
                TextField(controller: user, autocorrect: false, decoration: const InputDecoration(labelText: 'Username')),
                const SizedBox(height: 10),
                TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), onSubmitted: (_) => _go()),
                if (needCode) ...[
                  const SizedBox(height: 10),
                  TextField(controller: code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Authenticator code')),
                ],
                if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Ml.bad))),
                const SizedBox(height: 18),
                FilledButton(onPressed: busy ? null : _go, child: busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
