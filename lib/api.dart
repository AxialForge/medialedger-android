import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiError implements Exception {
  final String message;
  final String? reason; // login | totp | totp_bad | password | locked | forbidden | reauth ...
  final int status;
  ApiError(this.message, {this.reason, this.status = 0});
  @override
  String toString() => message;
}

/// Client for the MediaLedger web shell: POST /api/<channel> with a JSON argument array and a cookie session
/// (ml_session). The server stays the only source of data; only the session cookie and the addresses are stored.
class Api {
  static const _store = FlutterSecureStorage();
  List<String> servers = []; // tried in order: home first, then the away address
  String? active;
  String? _cookie;
  String? username;
  String? role;
  late http.Client _client;

  Api() {
    _client = _make();
  }

  /// Caddy "tls internal" certificates are not in Android's trust store, so certificates are accepted for the
  /// hosts the user typed in (and only those).
  bool trusts(String host) => servers.any((s) => Uri.tryParse(s)?.host == host);

  http.Client _make() {
    final c = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..badCertificateCallback = (cert, host, port) => trusts(host);
    return IOClient(c);
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    servers = p.getStringList('servers') ?? [];
    _cookie = await _store.read(key: 'cookie');
    username = p.getString('user');
    role = p.getString('role');
    _client = _make();
  }

  Future<void> saveServers(List<String> s) async {
    servers = s.map(_clean).where((e) => e.isNotEmpty).toList();
    active = null;
    final p = await SharedPreferences.getInstance();
    await p.setStringList('servers', servers);
    _client = _make();
  }

  static String _clean(String s) {
    s = s.trim().replaceAll(RegExp(r'/+$'), '');
    if (s.isNotEmpty && !s.contains('://')) s = 'https://$s';
    return s;
  }

  bool get hasSession => _cookie != null;
  String? get sessionValue => _cookie == null ? null : _cookie!.substring('ml_session='.length);
  String get base => active ?? (servers.isNotEmpty ? servers.first : '');

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (_cookie != null) 'cookie': _cookie!,
      };

  Map<String, String> get imageHeaders => {if (_cookie != null) 'cookie': _cookie!};

  void _grab(http.Response r) {
    final sc = r.headers['set-cookie'];
    if (sc == null) return;
    final m = RegExp(r'ml_session=([^;]*)').firstMatch(sc);
    if (m == null) return;
    if (m.group(1)!.isEmpty) {
      _cookie = null;
      _store.delete(key: 'cookie');
    } else {
      _cookie = 'ml_session=${m.group(1)}';
      _store.write(key: 'cookie', value: _cookie);
    }
  }

  /// First reachable server wins; it is remembered until the next failure.
  Future<http.Response> _post(String path, Object body) async {
    final order = [if (active != null) active!, ...servers.where((s) => s != active)];
    if (order.isEmpty) throw ApiError('No server address set');
    Object? last;
    for (final b in order) {
      try {
        final r = await _client.post(Uri.parse('$b$path'), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 20));
        active = b;
        _grab(r);
        return r;
      } catch (e) {
        last = e;
      }
    }
    active = null;
    throw ApiError('Cannot reach the server (${last is SocketException ? last.message : last})');
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiError('Unexpected reply from the server (HTTP ${r.statusCode})', status: r.statusCode);
    }
  }

  Future<void> login(String user, String password, {String? code}) async {
    final r = await _post('/api/login', {'username': user, 'password': password, if (code != null && code.isNotEmpty) 'code': code});
    final j = _decode(r);
    if (j['ok'] != true) throw ApiError((j['error'] ?? 'Sign-in failed').toString(), reason: j['reason']?.toString(), status: r.statusCode);
    username = j['username']?.toString();
    role = j['role']?.toString();
    final p = await SharedPreferences.getInstance();
    await p.setString('user', username ?? '');
    await p.setString('role', role ?? '');
  }

  Future<void> logout() async {
    try {
      await _post('/api/logout', {});
    } catch (_) {}
    _cookie = null;
    await _store.delete(key: 'cookie');
  }

  /// Is the stored session still valid? Network errors count as "yes" so a flaky connection does not sign you out.
  Future<bool> sessionValid() async {
    if (_cookie == null) return false;
    try {
      await call('security:me');
      return true;
    } on ApiError catch (e) {
      return e.reason != 'login';
    }
  }

  /// Call a core channel. [args] is the positional argument list.
  Future<dynamic> call(String channel, [List<Object?> args = const []]) async {
    final r = await _post('/api/$channel', args);
    final j = _decode(r);
    if (j['ok'] != true) {
      if (r.statusCode == 401 && j['reason'] == 'login') {
        _cookie = null;
        await _store.delete(key: 'cookie');
      }
      throw ApiError((j['error'] ?? 'Request failed').toString(), reason: j['reason']?.toString(), status: r.statusCode);
    }
    return j['result'];
  }

  String posterUrl(String type, String key) => '$base/poster/$type/${Uri.encodeComponent(key)}';
}

/// Lets Image.network (dart:io) accept the server's own certificate for the saved hosts.
class TrustSavedHosts extends HttpOverrides {
  final Api api;
  TrustSavedHosts(this.api);
  @override
  HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context)..badCertificateCallback = (cert, host, port) => api.trusts(host);
}
