import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'updater.dart';

/// MediaLedger for Android: the server's own web UI in a full-screen WebView,
/// so the app always looks and behaves exactly like the server. The app only
/// remembers the server addresses (home first, then Tailscale) and picks the
/// first one that answers.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Color(0xFF0F1115), systemNavigationBarColor: Color(0xFF0F1115)));
  runApp(const LedgerApp());
}

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MediaLedger',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF3B82F6), brightness: Brightness.dark, useMaterial3: true),
        home: const Launcher(),
      );
}

class Launcher extends StatefulWidget {
  const Launcher({super.key});
  @override
  State<Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<Launcher> {
  List<String> servers = [];
  String? url; // the address that answered
  String? error;
  bool busy = true, editing = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  static String _clean(String s) {
    s = s.trim().replaceAll(RegExp(r'/+$'), '');
    if (s.isNotEmpty && !s.contains('://')) s = 'https://$s';
    return s;
  }

  Future<void> _start() async {
    final p = await SharedPreferences.getInstance();
    servers = p.getStringList('servers') ?? [];
    if (servers.isEmpty) {
      setState(() { busy = false; editing = true; });
      return;
    }
    await _connect();
  }

  /// Any HTTP answer counts as reachable; the web UI handles sign-in itself.
  Future<bool> _reachable(String base) async {
    final c = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..badCertificateCallback = (_, __, ___) => true;
    try {
      final r = await (await c.getUrl(Uri.parse('$base/api/security:me'))).close().timeout(const Duration(seconds: 6));
      await r.drain();
      return true;
    } catch (_) {
      return false;
    } finally {
      c.close(force: true);
    }
  }

  Future<void> _connect() async {
    setState(() { busy = true; error = null; url = null; editing = false; });
    for (final s in servers) {
      if (await _reachable(s)) {
        if (mounted) setState(() { url = s; busy = false; });
        return;
      }
    }
    if (mounted) setState(() { busy = false; error = 'Cannot reach the server on any saved address.'; });
  }

  Future<void> _save(List<String> s) async {
    final p = await SharedPreferences.getInstance();
    servers = s.map(_clean).where((e) => e.isNotEmpty).toList();
    await p.setStringList('servers', servers);
    await _connect();
  }

  @override
  Widget build(BuildContext context) {
    if (url != null) return WebShell(base: url!, onSettings: () => setState(() { url = null; editing = true; }), onReconnect: _connect);
    if (busy) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Setup(servers: servers, error: error, showForm: editing || servers.isEmpty, onSave: _save, onRetry: _connect, onEdit: () => setState(() => editing = true));
  }
}

class Setup extends StatefulWidget {
  final List<String> servers;
  final String? error;
  final bool showForm;
  final Future<void> Function(List<String>) onSave;
  final VoidCallback onRetry, onEdit;
  const Setup({super.key, required this.servers, required this.error, required this.showForm, required this.onSave, required this.onRetry, required this.onEdit});
  @override
  State<Setup> createState() => _SetupState();
}

class _SetupState extends State<Setup> {
  late final home = TextEditingController(text: widget.servers.isNotEmpty ? widget.servers[0] : '');
  late final away = TextEditingController(text: widget.servers.length > 1 ? widget.servers[1] : '');

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
                Text('MediaLedger', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                if (widget.error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(widget.error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center)),
                if (widget.showForm) ...[
                  TextField(controller: home, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Home address', hintText: 'https://medialedger.home', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: away, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Away address (optional, Tailscale)', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => widget.onSave([home.text, away.text]), child: const Text('Connect')),
                ] else ...[
                  FilledButton(onPressed: widget.onRetry, child: const Text('Retry')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: widget.onEdit, child: const Text('Change addresses')),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class WebShell extends StatefulWidget {
  final String base;
  final VoidCallback onSettings, onReconnect;
  const WebShell({super.key, required this.base, required this.onSettings, required this.onReconnect});
  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  late final WebViewController ctl;
  double progress = 0;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    checkForUpdate().then((u) {
      if (u != null && mounted) promptUpdate(context, u);
    });
    ctl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F1115))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => progress = p / 100),
        onPageStarted: (_) => setState(() => failed = false),
        // Servers older than 2.6.1 let a later `.sidebar { position: relative }` beat the phone drawer's `position: fixed`.
        onPageFinished: (_) => ctl.runJavaScript("if(!document.getElementById('ml-app-fix')){var s=document.createElement('style');s.id='ml-app-fix';s.textContent='@media (max-width:820px){.sidebar{position:fixed!important}}';document.head.appendChild(s);}"),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? false) setState(() => failed = true);
        },
        // Caddy "tls internal" certificates are not in Android's trust store; the user typed this address.
        onSslAuthError: (req) => req.proceed(),
        onNavigationRequest: (nav) => nav.url.startsWith(widget.base) ? NavigationDecision.navigate : NavigationDecision.prevent,
      ))
      ..loadRequest(Uri.parse(widget.base));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await ctl.canGoBack()) {
          await ctl.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1115),
        body: SafeArea(
          child: Stack(children: [
            WebViewWidget(controller: ctl),
            if (progress < 1 && !failed) LinearProgressIndicator(value: progress, minHeight: 2),
            if (failed)
              Container(
                color: const Color(0xFF0F1115),
                alignment: Alignment.center,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('The page did not load.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: widget.onReconnect, child: const Text('Retry')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: widget.onSettings, child: const Text('Change addresses')),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
