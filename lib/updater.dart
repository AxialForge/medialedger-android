import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Self-update from GitHub Releases. The release tag is vX.Y.Z and carries an
/// asset named [assetName]. Android always asks the user to confirm the install.
const repo = 'AxialForge/medialedger-android';
const assetName = 'MediaLedger.apk';

class UpdateInfo {
  final String version, url, notes;
  UpdateInfo(this.version, this.url, this.notes);
}

List<int> _parts(String v) => v.replaceFirst(RegExp(r'^v'), '').split(RegExp(r'[.+-]')).take(3).map((e) => int.tryParse(e) ?? 0).toList();

bool _newer(String a, String b) {
  final x = _parts(a), y = _parts(b);
  for (var i = 0; i < 3; i++) {
    final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
    if (p != q) return p > q;
  }
  return false;
}

/// Returns the newer release, or null when up to date / unreachable / no repo yet.
Future<UpdateInfo?> checkForUpdate() async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await c.getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
    req.headers.set('accept', 'application/vnd.github+json');
    req.headers.set('user-agent', 'medialedger-android');
    final res = await req.close().timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    final tag = (j['tag_name'] ?? '').toString();
    final current = (await PackageInfo.fromPlatform()).version;
    if (!_newer(tag, current)) return null;
    for (final a in (j['assets'] as List? ?? [])) {
      if (a['name'] == assetName) return UpdateInfo(tag.replaceFirst('v', ''), a['browser_download_url'].toString(), (j['body'] ?? '').toString());
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    c.close(force: true);
  }
}

Future<void> promptUpdate(BuildContext context, UpdateInfo u) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Update to ${u.version}?'),
      content: SingleChildScrollView(child: Text(u.notes.isEmpty ? 'A new version of MediaLedger is available.' : u.notes)),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Later')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Update'))],
    ),
  );
  if (go != true || !context.mounted) return;
  final progress = ValueNotifier<String>('Starting download…');
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(title: const Text('Updating'), content: ValueListenableBuilder<String>(valueListenable: progress, builder: (_, v, __) => Text(v))),
  );
  OtaUpdate().execute(u.url, destinationFilename: assetName).listen(
    (e) {
      if (e.status == OtaStatus.DOWNLOADING) progress.value = 'Downloading… ${e.value}%';
      if (e.status == OtaStatus.INSTALLING) {
        progress.value = 'Installing…';
        if (context.mounted) Navigator.of(context, rootNavigator: true).maybePop();
      }
      if (e.status.index >= OtaStatus.ALREADY_RUNNING_ERROR.index) {
        progress.value = 'Update failed: ${e.status.name}';
      }
    },
    onError: (_) => progress.value = 'Update failed',
  );
}
