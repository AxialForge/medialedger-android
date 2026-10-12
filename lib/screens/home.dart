import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

class Home extends StatelessWidget {
  final VoidCallback onSignedOut;
  const Home({super.key, required this.onSignedOut});

  @override
  Widget build(BuildContext context) {
    return RefreshableHome(onSignedOut: onSignedOut);
  }
}

class RefreshableHome extends StatefulWidget {
  final VoidCallback onSignedOut;
  const RefreshableHome({super.key, required this.onSignedOut});
  @override
  State<RefreshableHome> createState() => _RefreshableHomeState();
}

class _RefreshableHomeState extends State<RefreshableHome> {
  int gen = 0;

  @override
  Widget build(BuildContext context) {
    // Three independent loaders, so one slow or failing channel does not blank the whole screen.
    return RefreshIndicator(
      onRefresh: () async => setState(() => gen++),
      child: ListView(key: ValueKey(gen), padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
        _Counts(onSignedOut: widget.onSignedOut),
        const SectionTitle('Continue watching'),
        _Continue(onSignedOut: widget.onSignedOut),
        const SectionTitle('Next up'),
        _NextUp(onSignedOut: widget.onSignedOut),
      ]),
    );
  }
}

/// Small helper: load one channel inside a list section.
class _Section extends StatelessWidget {
  final String channel;
  final List<Object?> args;
  final Widget Function(dynamic) builder;
  final VoidCallback onSignedOut;
  const _Section({required this.channel, this.args = const [], required this.builder, required this.onSignedOut});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _call(),
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))));
        if (s.hasError) return Padding(padding: const EdgeInsets.all(12), child: Text('${s.error}', style: const TextStyle(color: Ml.muted)));
        return builder(s.data);
      },
    );
  }

  Future<dynamic> _call() async {
    try {
      return await apiCall(channel, args);
    } catch (e) {
      if (isLoginError(e)) WidgetsBinding.instance.addPostFrameCallback((_) => onSignedOut());
      rethrow;
    }
  }
}

class _Counts extends StatelessWidget {
  final VoidCallback onSignedOut;
  const _Counts({required this.onSignedOut});

  @override
  Widget build(BuildContext context) {
    return _Section(
      channel: 'data:dashboard',
      onSignedOut: onSignedOut,
      builder: (d) {
        final titles = (d['titles'] as Map?) ?? {};
        Widget tile(String label, String type, Color color) => Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${titles[type] ?? 0}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
        return Column(children: [
          Row(children: [tile('TV', 'tv', Ml.tv), const SizedBox(width: 8), tile('Anime', 'anime', Ml.anime), const SizedBox(width: 8), tile('Movies', 'movie', Ml.movie)]),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(dense: true, title: const Text('Missing files'), trailing: Text('${d['missingFiles'] ?? 0}')),
              ListTile(dense: true, title: const Text('Duplicate episodes'), trailing: Text('${d['duplicates'] ?? 0}')),
            ]),
          ),
        ]);
      },
    );
  }
}

class _Continue extends StatelessWidget {
  final VoidCallback onSignedOut;
  const _Continue({required this.onSignedOut});

  @override
  Widget build(BuildContext context) {
    return _Section(
      channel: 'data:continue',
      args: const [20],
      onSignedOut: onSignedOut,
      builder: (d) {
        final rows = (d as List).cast<Map>();
        if (rows.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('Nothing in progress.', style: TextStyle(color: Ml.muted)));
        return Card(
          child: Column(children: [
            for (final r in rows)
              ListTile(
                leading: Poster(type: r['library_type'].toString(), keyName: (r['library_type'] == 'movie' ? r['group_key'] : r['show_name']).toString()),
                title: Text(r['library_type'] == 'movie' ? '${r['movie_title']}' : '${r['show_name']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${r['library_type'] == 'movie' ? '' : 'S${r['season']}E${r['episode']} · '}${r['progress']}% · ${((r['left_s'] ?? 0) / 60).round()} min left'),
              ),
          ]),
        );
      },
    );
  }
}

class _NextUp extends StatelessWidget {
  final VoidCallback onSignedOut;
  const _NextUp({required this.onSignedOut});

  @override
  Widget build(BuildContext context) {
    return _Section(
      channel: 'data:nextUp',
      onSignedOut: onSignedOut,
      builder: (d) {
        final rows = (d as List).cast<Map>().where((r) => r['next'] != null).toList();
        if (rows.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('Nothing queued.', style: TextStyle(color: Ml.muted)));
        return Card(
          child: Column(children: [
            for (final r in rows)
              ListTile(
                leading: Poster(type: r['library_type'].toString(), keyName: r['show'].toString()),
                title: Text('${r['show']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('S${r['next']['season']}E${r['next']['episode']}${r['next']['title'] != null ? ' ${r['next']['title']}' : ''}\n${r['who'] ?? ''} · ${r['left']} left'),
                isThreeLine: true,
              ),
          ]),
        );
      },
    );
  }
}
