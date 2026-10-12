import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import '../theme.dart';

String bytes(num? n) {
  var v = (n ?? 0).toDouble();
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i > 1 ? 1 : 0)} ${u[i]}';
}

/// Calls a server channel and builds from the result; pull down to refresh. A "sign in" reply goes back to login.
class Loader extends StatefulWidget {
  final String channel;
  final List<Object?> args;
  final Widget Function(BuildContext, dynamic) builder;
  final VoidCallback onSignedOut;
  const Loader({super.key, required this.channel, this.args = const [], required this.builder, required this.onSignedOut});
  @override
  State<Loader> createState() => _LoaderState();
}

class _LoaderState extends State<Loader> {
  late Future<dynamic> f = _load();

  Future<dynamic> _load() async {
    try {
      return await api.call(widget.channel, widget.args);
    } on ApiError catch (e) {
      if (e.reason == 'login') WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSignedOut());
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() => f = _load());
    await f.catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: f,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${s.error}', textAlign: TextAlign.center, style: const TextStyle(color: Ml.muted)),
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: _refresh, child: const Text('Retry')),
              ]),
            ),
          );
        }
        return RefreshIndicator(onRefresh: _refresh, child: widget.builder(c, s.data));
      },
    );
  }
}

class Poster extends StatelessWidget {
  final String type, keyName;
  final double w;
  const Poster({super.key, required this.type, required this.keyName, this.w = 44});

  @override
  Widget build(BuildContext context) {
    final box = Container(width: w, height: w * 1.5, color: Ml.panel3, child: const Icon(Icons.movie_outlined, color: Ml.muted));
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Image.network(
        api.posterUrl(type, keyName),
        headers: api.imageHeaders,
        width: w,
        height: w * 1.5,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) => p == null ? child : box,
        errorBuilder: (_, __, ___) => box,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 0.8, color: Ml.muted, fontWeight: FontWeight.w600)),
      );
}

Future<dynamic> apiCall(String channel, List<Object?> args) => api.call(channel, args);

bool isLoginError(Object e) => e is ApiError && e.reason == 'login';
