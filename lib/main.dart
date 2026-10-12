import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'theme.dart';

final api = Api();

/// MediaLedger for Android. Native screens talk to the server's own channels; any page that has no native
/// screen yet opens the server's web page inside the app (see screens/web_page.dart).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Ml.bg, systemNavigationBarColor: Ml.panel));
  await api.load();
  HttpOverrides.global = TrustSavedHosts(api);
  final valid = await api.sessionValid();
  runApp(LedgerApp(signedIn: valid));
}

class LedgerApp extends StatefulWidget {
  final bool signedIn;
  const LedgerApp({super.key, required this.signedIn});
  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> {
  late bool signedIn = widget.signedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediaLedger',
      debugShowCheckedModeBanner: false,
      theme: Ml.theme(),
      home: signedIn
          ? Shell(onSignedOut: () => setState(() => signedIn = false))
          : LoginScreen(onSignedIn: () => setState(() => signedIn = true)),
    );
  }
}
