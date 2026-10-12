import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../main.dart';
import '../theme.dart';
import '../updater.dart';
import 'common.dart';
import 'web_page.dart';

class PageEntry {
  final String title, route;
  final IconData icon;
  const PageEntry(this.title, this.route, this.icon);
}

class PageGroup {
  final String title;
  final List<PageEntry> pages;
  const PageGroup(this.title, this.pages);
}

/// The server's pages. Each opens as a web page until it gets a native screen.
const libraryGroups = [
  PageGroup('Library', [
    PageEntry('TV shows', 'tv', Icons.tv),
    PageEntry('Anime', 'anime', Icons.animation),
    PageEntry('Movies', 'movies', Icons.movie_outlined),
    PageEntry('Collections', 'collections', Icons.collections_bookmark_outlined),
    PageEntry('Web videos', 'web', Icons.play_circle_outline),
  ]),
  PageGroup('Watching', [
    PageEntry('Watch tonight', 'tonight', Icons.nights_stay_outlined),
    PageEntry('Watched', 'watched', Icons.visibility_outlined),
    PageEntry('Ratings', 'ratings', Icons.star_outline),
    PageEntry('Requests', 'requests', Icons.add_circle_outline),
  ]),
];

const moreGroups = [
  PageGroup('Review', [
    PageEntry('Dashboard', 'dashboard', Icons.dashboard_outlined),
    PageEntry('Missing', 'missing', Icons.help_outline),
    PageEntry('Issues', 'issues', Icons.warning_amber),
    PageEntry('Quality', 'quality', Icons.hd_outlined),
    PageEntry('Upgrades', 'upgrades', Icons.upgrade),
    PageEntry('Reclaim space', 'reclaim', Icons.cleaning_services_outlined),
  ]),
  PageGroup('Maintenance', [
    PageEntry('Change log', 'changes', Icons.history),
    PageEntry('Movie names', 'movienames', Icons.drive_file_rename_outline),
    PageEntry('Rename TV/anime', 'rename', Icons.edit_outlined),
    PageEntry('CSV export', 'export', Icons.file_download_outlined),
  ]),
  PageGroup('App', [
    PageEntry('System', 'system', Icons.monitor_heart_outlined),
    PageEntry('Family portal', 'family', Icons.home_outlined),
    PageEntry('Log', 'log', Icons.notes),
    PageEntry('Security', 'security', Icons.shield_outlined),
    PageEntry('Settings', 'settings', Icons.settings_outlined),
    PageEntry('About', 'about', Icons.info_outline),
  ]),
];

class PageList extends StatelessWidget {
  final List<PageGroup> groups;
  final List<Widget> footer;
  const PageList({super.key, required this.groups, this.footer = const []});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
      for (final g in groups) ...[
        SectionTitle(g.title),
        Card(
          child: Column(children: [
            for (final p in g.pages)
              ListTile(
                leading: Icon(p.icon),
                title: Text(p.title),
                trailing: const Icon(Icons.chevron_right, color: Ml.muted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WebPage(route: p.route, title: p.title))),
              ),
          ]),
        ),
      ],
      ...footer,
    ]);
  }
}

class More extends StatelessWidget {
  final VoidCallback onSignedOut;
  const More({super.key, required this.onSignedOut});

  Future<void> _checkUpdate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Checking for updates…')));
    final u = await checkForUpdate();
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    if (u != null) {
      promptUpdate(context, u);
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('You have the latest version.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageList(groups: moreGroups, footer: [
      const SectionTitle('This app'),
      Card(
        child: Column(children: [
          FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (c, s) => ListTile(leading: const Icon(Icons.person_outline), title: Text(api.username ?? 'Signed in'), subtitle: Text('${api.role ?? ''} · ${api.base}\nMediaLedger Android ${s.data?.version ?? ''}'), isThreeLine: true),
          ),
          ListTile(leading: const Icon(Icons.system_update), title: const Text('Check for updates'), onTap: () => _checkUpdate(context)),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            subtitle: const Text('Also the way to change server addresses'),
            onTap: () async {
              await api.logout();
              onSignedOut();
            },
          ),
        ]),
      ),
    ]);
  }
}
