import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../main.dart';
import '../theme.dart';

/// One page of the server's web UI inside the app, for screens that have no native version yet.
/// The sign-in cookie is handed to the WebView and the web chrome (sidebar, top bar) is hidden, because the
/// app has its own navigation.
class WebPage extends StatefulWidget {
  final String route; // the web UI's #hash route, for example "ratings"
  final String title;
  const WebPage({super.key, required this.route, required this.title});
  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController ctl;
  double progress = 0;
  bool failed = false;

  static const _css = '.sidebar,.topbar,.navshade{display:none!important}.app{grid-template-columns:1fr!important;grid-template-rows:1fr!important}';

  @override
  void initState() {
    super.initState();
    ctl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Ml.bg)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => progress = p / 100),
        onPageStarted: (_) => setState(() => failed = false),
        onPageFinished: (_) => ctl.runJavaScript("(function(){if(!document.getElementById('ml-embed')){var s=document.createElement('style');s.id='ml-embed';s.textContent='$_css';document.head.appendChild(s);}})()"),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? false) setState(() => failed = true);
        },
        // The server's own certificate is accepted for the address the user typed in.
        onSslAuthError: (req) => req.proceed(),
        onNavigationRequest: (nav) => nav.url.startsWith('http://') || nav.url.startsWith('https://') ? NavigationDecision.navigate : NavigationDecision.prevent,
      ));
    _load();
  }

  Future<void> _load() async {
    final base = api.base;
    final value = api.sessionValue;
    if (value != null) {
      await WebViewCookieManager().setCookie(WebViewCookie(name: 'ml_session', value: value, domain: Uri.parse(base).host, path: '/'));
    }
    await ctl.loadRequest(Uri.parse('$base/#${widget.route}'));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await ctl.canGoBack()) {
          await ctl.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reload', onPressed: () => ctl.reload())]),
        body: Stack(children: [
          WebViewWidget(controller: ctl),
          if (progress < 1 && !failed) LinearProgressIndicator(value: progress, minHeight: 2),
          if (failed)
            Container(
              color: Ml.bg,
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text("Couldn't load this page."),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ]),
            ),
        ]),
      ),
    );
  }
}
