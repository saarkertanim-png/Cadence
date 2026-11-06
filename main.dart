import 'dart:async';
import 'dart:typed_data';
import 'dart:convert' show base64Url, jsonDecode, jsonEncode, utf8;
import 'dart:io';
import 'dart:math' as m;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'library.dart';

final eq = AndroidEqualizer(), loud = AndroidLoudnessEnhancer();
final player = AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [eq, loud]));
final lib = Lib();
final themeIx = ValueNotifier<int>(0);
final showSig = ValueNotifier<bool>(true);
final msgKey = GlobalKey<ScaffoldMessengerState>();
final navKey = GlobalKey<NavigatorState>();

class Th {
  final String n; final Color bg, bg2, ac, tx; final bool dark;
  const Th(this.n, this.bg, this.bg2, this.ac, this.tx, this.dark);
}
const themes = [
  Th('Botanical Mist', Color(0xFFEEF3EE), Color(0xFFBFD9CB), Color(0xFF2F7F7A), Color(0xFF133A3D), false),
  Th('Deep Blue', Color(0xFF0B1830), Color(0xFF1C3F78), Color(0xFF6FB5FF), Color(0xFFE3F0FF), true),
  Th('Ocean Glass', Color(0xFFD8ECEE), Color(0xFF7FC4CC), Color(0xFF1F7A8C), Color(0xFF0F3B4A), false),
  Th('Midnight AMOLED', Color(0xFF000000), Color(0xFF102622), Color(0xFF5FD1C0), Color(0xFFEAEAEA), true),
  Th('Ivory Minimal', Color(0xFFFAF6EE), Color(0xFFE6D9BD), Color(0xFF8A6D3B), Color(0xFF2D2A24), false),
  Th('Rose Mist', Color(0xFFF8EEEE), Color(0xFFE8B4C2), Color(0xFFC0577A), Color(0xFF4A2A33), false),
  Th('Forest Shadow', Color(0xFF0F1F17), Color(0xFF24523A), Color(0xFF7FBF8E), Color(0xFFDCEBE0), true),
  // Anime
  Th('Sakura Anime', Color(0xFFFFF0F5), Color(0xFFF7B8D0), Color(0xFFE0508A), Color(0xFF3A1F2E), false),
  Th('Neon Tokyo', Color(0xFF0A0614), Color(0xFF3B1170), Color(0xFFFF4FD8), Color(0xFFF4E8FF), true),
  Th('Shonen Sunrise', Color(0xFFFFF4E0), Color(0xFFFFB347), Color(0xFFE8451E), Color(0xFF2B1A10), false),
  Th('Magical Girl', Color(0xFFFDF0FF), Color(0xFFC9A7FF), Color(0xFFB04DFF), Color(0xFF33204A), false),
  Th('Moonlit Anime', Color(0xFF0E1230), Color(0xFF3A3F8F), Color(0xFF9FB4FF), Color(0xFFE8ECFF), true),
  Th('Cyber Mecha', Color(0xFF05101A), Color(0xFF0F3D4F), Color(0xFF00E5FF), Color(0xFFD8F8FF), true),
  // Cartoon
  Th('Cat and Mouse', Color(0xFFF1EEE6), Color(0xFFBFD3E6), Color(0xFF2F6EA5), Color(0xFF22303C), false),
  Th('Cheese Pop', Color(0xFFFFF6D6), Color(0xFFFFD54A), Color(0xFFE08A00), Color(0xFF3B2A00), false),
  Th('Cartoon Pop', Color(0xFFFFFBEA), Color(0xFF7EC8FF), Color(0xFFFF3D5A), Color(0xFF1B1B2F), false),
  Th('Retro Toon', Color(0xFFF3E9D2), Color(0xFFE4A672), Color(0xFFC2452D), Color(0xFF33261A), false),
  Th('Candy Land', Color(0xFFFFF0F8), Color(0xFF9AE6FF), Color(0xFFFF5CA8), Color(0xFF3A2040), false),
  // Movie
  Th('Noir Cinema', Color(0xFF0B0B0D), Color(0xFF2A2A2E), Color(0xFFE5E5E5), Color(0xFFF0F0F0), true),
  Th('Golden Screen', Color(0xFF14100A), Color(0xFF4A3510), Color(0xFFF2C14E), Color(0xFFF6EBD0), true),
  Th('Space Odyssey', Color(0xFF02030A), Color(0xFF1B1F4D), Color(0xFF8AA2FF), Color(0xFFE6EAFF), true),
  Th('Horror Crimson', Color(0xFF0D0506), Color(0xFF4A0F14), Color(0xFFFF3B3B), Color(0xFFF7E3E3), true),
  Th('Western Dust', Color(0xFFF2E4CC), Color(0xFFD9A25F), Color(0xFF9C4A1A), Color(0xFF3A2412), false),
  Th('Cyberpunk Rain', Color(0xFF080A12), Color(0xFF3B0F4F), Color(0xFFFF7A1A), Color(0xFFF2E9FF), true),
];
final adaptiveColors = ValueNotifier<bool>(false);
final artAccent = ValueNotifier<Color?>(null);
final vizOn = ValueNotifier<bool>(true);
String folderName(String path) {
  final parts = path.replaceAll('\\', '/').split('/');
  if (parts.length >= 3) return '${parts[parts.length - 3]}/${parts[parts.length - 2]}';
  if (parts.length == 2) return parts[0].isEmpty ? '/' : parts[0];
  return 'Unknown';
}

Future<void> backupToClipboard() async {
  try {
    final data = {
      'app': 'cadence', 'v': 1,
      'playlists': lib.playlists,
      'favs': lib.favs.toList(),
      'plays': lib.plays,
      'sig': {'text': sigText.value, 'font': sigFont.value, 'size': sigSize.value},
    };
    await Clipboard.setData(ClipboardData(text: jsonEncode(data)));
    snack('Backup copied. Paste it into a note or message to keep it safe.');
  } catch (_) { snack('Could not create the backup.'); }
}

Future<void> restoreFromClipboard() async {
  try {
    final d = await Clipboard.getData('text/plain');
    final j = jsonDecode(d?.text ?? '');
    if (j is! Map || j['app'] != 'cadence') { snack('The clipboard does not hold a Cadence backup. Copy it first.'); return; }
    var pl = 0, fv = 0;
    final pls = j['playlists'];
    if (pls is Map) {
      for (final e in pls.entries) {
        final name = e.key as String;
        await lib.newPlaylist(name);
        for (final p in (e.value as List)) { await lib.addTo(name, p as String); }
        pl++;
      }
    }
    final favs = j['favs'];
    if (favs is List) {
      for (final p in favs) {
        final t = lib.byPath[p as String];
        if (t != null && !lib.favs.contains(p)) { await lib.toggleFav(t); fv++; }
      }
    }
    final pp = j['plays'];
    if (pp is Map) {
      for (final e in pp.entries) {
        final path = e.key as String, n = (e.value as num).toInt();
        if (n > (lib.plays[path] ?? 0)) { lib.plays[path] = n - 1; await lib.countPlay(path); }
      }
    }
    final sg = j['sig'];
    if (sg is Map) {
      final sp = await SharedPreferences.getInstance();
      if (sg['text'] is String && (sg['text'] as String).trim().isNotEmpty) { sigText.value = sg['text'] as String; await sp.setString('sigText', sigText.value); }
      if (sg['font'] is int) { sigFont.value = sg['font'] as int; await sp.setInt('sigFont', sigFont.value); }
      if (sg['size'] is num) { sigSize.value = (sg['size'] as num).toDouble(); await sp.setDouble('sigSize', sigSize.value); }
    }
    snack('Restored $pl playlists, $fv favorites and your play counts.');
  } catch (_) { snack('Could not read that backup.'); }
}
Th themeAt(int i) {
  final b = themes[i];
  final a = (matchWall.value && wallAccent.value != null) ? wallAccent.value : (adaptiveColors.value ? artAccent.value : null);
  if (a == null) return b;
  return Th(b.n, b.bg, Color.lerp(b.bg2, a, .5)!, a, b.tx, b.dark);
}
Th get th => themeAt(themeIx.value);

Future<Color?> dominantColor(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await instantiateImageCodec(bytes, targetWidth: 32, targetHeight: 32);
    final fr = await codec.getNextFrame();
    final bd = await fr.image.toByteData(format: ImageByteFormat.rawRgba);
    if (bd == null) return null;
    double wr = 0, wg = 0, wb = 0, ws = 0;
    for (int i = 0; i + 3 < bd.lengthInBytes; i += 4) {
      final r = bd.getUint8(i), g = bd.getUint8(i + 1), b = bd.getUint8(i + 2);
      final mx = m.max(r, m.max(g, b)), mn = m.min(r, m.min(g, b));
      final sat = (mx - mn) / 255.0;
      final w = sat * sat + .02;
      wr += r * w; wg += g * w; wb += b * w; ws += w;
    }
    if (ws == 0) return null;
    final raw = Color.fromARGB(255, (wr / ws).round(), (wg / ws).round(), (wb / ws).round());
    final h = HSLColor.fromColor(raw);
    final dark = themes[themeIx.value].dark;
    final satc = m.min(.85, m.max(.35, h.saturation));
    final lit = dark ? m.min(.75, m.max(.6, h.lightness)) : m.min(.42, m.max(.28, h.lightness));
    return h.withSaturation(satc).withLightness(lit).toColor();
  } catch (_) { return null; }
}

Future<void> updateArtAccent() async {
  if (!adaptiveColors.value) { artAccent.value = null; return; }
  final seq = player.sequence, i = player.currentIndex;
  Track? t;
  if (seq != null && i != null && i >= 0 && i < seq.length) {
    final tag = seq[i].tag;
    if (tag is MediaItem) t = lib.byPath[tag.id];
  }
  final art = t?.art;
  if (art == null) { artAccent.value = null; return; }
  artAccent.value = await dominantColor(art);
}

Widget _sw(ValueNotifier<bool> n, String key, IconData ic, String title, String sub, [VoidCallback? after]) =>
    ValueListenableBuilder<bool>(valueListenable: n, builder: (_, on, __) => SwitchListTile(
        secondary: Icon(ic), title: Text(title), subtitle: Text(sub), value: on,
        onChanged: (v) async { n.value = v; HapticFeedback.selectionClick(); (await SharedPreferences.getInstance()).setBool(key, v); after?.call(); }));

final sigText = ValueNotifier<String>('TanimSarker');
final sigFont = ValueNotifier<int>(0);
final sigSize = ValueNotifier<double>(22);
const sigFontNames = ['Great Vibes', 'Dancing Script', 'Pacifico', 'Caveat', 'Satisfy'];
TextStyle sigStyle(int i, double sz, Color c) {
  switch (i) {
    case 1: return GoogleFonts.dancingScript(fontSize: sz, color: c);
    case 2: return GoogleFonts.pacifico(fontSize: sz, color: c);
    case 3: return GoogleFonts.caveat(fontSize: sz, color: c);
    case 4: return GoogleFonts.satisfy(fontSize: sz, color: c);
    default: return GoogleFonts.greatVibes(fontSize: sz, color: c);
  }
}
final recents = ValueNotifier<List<String>>([]);
Future<void> recentAdd(String path) async {
  final l = [path, ...recents.value.where((x) => x != path)].take(40).toList();
  recents.value = l;
  (await SharedPreferences.getInstance()).setStringList('recent', l);
}
Future<String?> askText(BuildContext c, String title, String init, {bool number = false, int maxLen = 30}) {
  final tc = TextEditingController(text: init);
  return showDialog<String>(context: c, builder: (d) => AlertDialog(title: Text(title),
      content: TextField(controller: tc, autofocus: true, maxLength: maxLen, keyboardType: number ? TextInputType.number : TextInputType.text),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, tc.text), child: const Text('Save'))]));
}
final glassSkin = ValueNotifier<bool>(true);
final skin = ValueNotifier<int>(0);
// ---- streaming from the user's own GitHub repo ----
final repoLink = ValueNotifier<String?>(null);
// Every connected repo (yours or anyone else's public repo). Each can hold songs and/or a providers.json.
final repoList = ValueNotifier<List<String>>([]);
final _repoTracks = <String, List<Track>>{};
final _repoProvs = <String, List<MusicProvider>>{};
void _mergeRepos() {
  final keys = repoList.value;
  onlineTracks.value = [for (final k in keys) ...(_repoTracks[k] ?? const <Track>[])];
  hub.json.value = [for (final k in keys) ...(_repoProvs[k] ?? const <MusicProvider>[])];
  repoLink.value = keys.isEmpty ? null : (keys.length == 1 ? keys.first : '${keys.length} repos');
}
Future<void> removeRepo(String key) async {
  for (final t in _repoTracks[key] ?? const <Track>[]) { onlineByUrl.remove(t.path); onlineCover.remove(t.path); }
  _repoTracks.remove(key);
  _repoProvs.remove(key);
  repoList.value = [for (final k in repoList.value) if (k != key) k];
  _mergeRepos();
  (await SharedPreferences.getInstance()).setStringList('repos', repoList.value);
}
final onlineTracks = ValueNotifier<List<Track>>([]);
final onlineByUrl = <String, Track>{};
final onlineCover = <String, String>{};
final onlineBusy = ValueNotifier<bool>(false);
Future<List<dynamic>> _apiGet(Uri u) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final rq = await c.getUrl(u);
    rq.headers.set('User-Agent', 'Cadence/1.0');
    final rs = await rq.close().timeout(const Duration(seconds: 25));
    final body = await rs.transform(utf8.decoder).join();
    dynamic j;
    try { j = jsonDecode(body); } catch (_) {}
    return [rs.statusCode, j];
  } finally { c.close(force: true); }
}


// ---------------- Music providers ----------------
// Every source of online music is a MusicProvider. The player never changes: it only
// plays the https stream URLs that providers hand back.
abstract class MusicProvider {
  String get id;
  String get name;
  String get blurb;
  IconData get icon;
  List<String> get caps;
  bool get ready => true;
  String get setup => '';
  Future<List<Track>> search(String q);
  Future<List<Track>> trending();
  Future<List<Track>> expand(Track collection) async => [collection];
}

String provOf(Track t) => (t.j['prov'] ?? '').toString();
bool isCollection(Track t) => t.j['coll'] == true;

Track mkTrack({required MusicProvider p, required String url, required String title, required String artist,
    String album = '', String? cover, int ms = 0, String? license, bool collection = false}) {
  final t = Track({'p': url, 't': title, 'a': artist, 'al': album.isEmpty ? p.name : album,
    'f': collection ? '${p.name} · Collection' : p.name, 'd': ms, 's': 0, 'ad': 0,
    'prov': p.id, 'lic': license ?? '', 'coll': collection});
  onlineByUrl[url] = t;
  if (cover != null && cover.isNotEmpty) { onlineCover[url] = cover; }
  return t;
}

dynamic jget(dynamic o, String? path) {
  if (path == null || path.isEmpty) return o;
  dynamic cur = o;
  for (final k in path.split('.')) {
    if (cur is Map) {
      cur = cur[k];
    } else if (cur is List) {
      final i = int.tryParse(k);
      cur = (i != null && i >= 0 && i < cur.length) ? cur[i] : null;
    } else {
      return null;
    }
  }
  return cur;
}

String ccLabel(String? url) {
  if (url == null || url.isEmpty) return '';
  final m = RegExp(r'creativecommons\.org/(licenses|publicdomain)/([\w-]+)/?([\d.]*)').firstMatch(url);
  if (m == null) return url.contains('publicdomain') ? 'Public domain' : 'See source';
  if (m.group(1) == 'publicdomain') return m.group(2) == 'zero' ? 'CC0' : 'Public domain';
  final v = m.group(3) ?? '';
  return 'CC ${m.group(2)!.toUpperCase()}${v.isEmpty ? '' : ' $v'}';
}

// 1) Audius: free music uploaded by independent artists. No account or key.
class AudiusProvider extends MusicProvider {
  @override
  String get id => 'audius';
  @override
  String get name => 'Audius';
  @override
  String get blurb => 'Free music uploaded by independent artists';
  @override
  IconData get icon => Icons.graphic_eq_rounded;
  @override
  List<String> get caps => const ['Search', 'Trending', 'Streaming', 'Artwork'];
  Future<List<Track>> _go(String path, Map<String, String> qp) async {
    final r = await _apiGet(Uri.https('api.audius.co', path, {'app_name': 'Cadence', 'limit': '30', ...qp}));
    final data = (r[1] is Map) ? (r[1] as Map)['data'] : null;
    if (r[0] != 200 || data is! List) throw 'could not be reached (error ${r[0]})';
    final out = <Track>[];
    for (final e in data) {
      if (e is! Map || e['is_streamable'] == false || e['id'] == null) continue;
      final user = e['user'] is Map ? (e['user'] as Map)['name']?.toString() : null;
      final art = e['artwork'] is Map ? ((e['artwork'] as Map)['480x480'] ?? (e['artwork'] as Map)['150x150'])?.toString() : null;
      final secs = (e['duration'] is num) ? (e['duration'] as num).toInt() : 0;
      out.add(mkTrack(p: this, url: 'https://api.audius.co/v1/tracks/${e['id']}/stream?app_name=Cadence',
          title: (e['title'] ?? 'Untitled').toString(), artist: user ?? 'Unknown artist',
          album: (e['genre'] ?? '').toString(), cover: art, ms: secs * 1000));
    }
    return out;
  }
  @override
  Future<List<Track>> search(String q) => _go('/v1/tracks/search', {'query': q});
  @override
  Future<List<Track>> trending() => _go('/v1/tracks/trending', {'time': 'week'});
}

// 2) Jamendo: Creative Commons music. Needs a free client ID from developer.jamendo.com.
final jamendoKey = ValueNotifier<String>('');
class JamendoProvider extends MusicProvider {
  @override
  String get id => 'jamendo';
  @override
  String get name => 'Jamendo';
  @override
  String get blurb => 'Creative Commons music from independent artists';
  @override
  IconData get icon => Icons.music_note_rounded;
  @override
  List<String> get caps => const ['Search', 'Popular now', 'Streaming', 'Artwork', 'License info'];
  @override
  bool get ready => jamendoKey.value.trim().isNotEmpty;
  @override
  String get setup => 'Add your free client ID from developer.jamendo.com';
  Future<List<Track>> _go(Map<String, String> qp) async {
    final r = await _apiGet(Uri.https('api.jamendo.com', '/v3.0/tracks/', {
      'client_id': jamendoKey.value.trim(), 'format': 'json', 'limit': '30', 'audioformat': 'mp32', 'imagesize': '300', ...qp}));
    final j = r[1];
    if (j is! Map) throw 'could not be reached (error ${r[0]})';
    final h = j['headers'];
    if (h is Map && h['status'] != 'success') throw (h['error_message'] ?? 'refused the request').toString();
    final res = j['results'];
    if (res is! List) throw 'returned no results';
    final out = <Track>[];
    for (final e in res) {
      if (e is! Map) continue;
      final audio = e['audio'];
      if (audio is! String || audio.isEmpty) continue;
      final secs = int.tryParse((e['duration'] ?? '0').toString()) ?? 0;
      out.add(mkTrack(p: this, url: audio, title: (e['name'] ?? 'Untitled').toString(),
          artist: (e['artist_name'] ?? 'Unknown artist').toString(), album: (e['album_name'] ?? '').toString(),
          cover: (e['image'] ?? e['album_image'])?.toString(), ms: secs * 1000, license: ccLabel(e['license_ccurl']?.toString())));
    }
    return out;
  }
  @override
  Future<List<Track>> search(String q) => _go({'search': q});
  @override
  Future<List<Track>> trending() => _go({'order': 'popularity_week'});
}

// 3) Internet Archive: only items that carry a Creative Commons / public-domain license are shown.
//    Each result is a recording (album or concert); tapping it opens its audio files.
class ArchiveProvider extends MusicProvider {
  @override
  String get id => 'archive';
  @override
  String get name => 'Internet Archive';
  @override
  String get blurb => 'Creative Commons and public-domain recordings';
  @override
  IconData get icon => Icons.account_balance_rounded;
  @override
  List<String> get caps => const ['Search', 'Popular now', 'Opens albums and concerts', 'Streaming', 'Artwork', 'License check'];
  static bool _licensed(dynamic l) => (l is List ? l.join(' ') : (l ?? '')).toString().toLowerCase().contains('creativecommons.org');
  static String _s(dynamic v) => v is List ? (v.isEmpty ? '' : v.first.toString()) : (v ?? '').toString();
  Future<List<Track>> _query(String lucene, {bool requireLicenseInQuery = true}) async {
    final q = requireLicenseInQuery ? '$lucene AND licenseurl:*creativecommons*' : lucene;
    final r = await _apiGet(Uri.https('archive.org', '/advancedsearch.php', {
      'q': q, 'fl[]': ['identifier', 'title', 'creator', 'licenseurl'], 'rows': '60', 'output': 'json', 'sort[]': 'downloads desc'}));
    final resp = (r[1] is Map) ? (r[1] as Map)['response'] : null;
    final docs = resp is Map ? resp['docs'] : null;
    if (r[0] != 200 || docs is! List) throw 'could not be reached (error ${r[0]})';
    final out = <Track>[];
    for (final d in docs) {
      if (d is! Map || d['identifier'] == null || !_licensed(d['licenseurl'])) continue;
      final id = d['identifier'].toString();
      final creator = _s(d['creator']);
      out.add(mkTrack(p: this, url: 'ia://$id', title: _s(d['title']).isEmpty ? id : _s(d['title']),
          artist: creator.isEmpty ? 'Various artists' : creator, cover: 'https://archive.org/services/img/$id',
          license: ccLabel(_s(d['licenseurl'])), collection: true));
    }
    return out;
  }
  Future<List<Track>> _licensedQuery(String lucene) async {
    final a = await _query(lucene);
    if (a.isNotEmpty) return a;
    return _query(lucene, requireLicenseInQuery: false);
  }
  @override
  Future<List<Track>> search(String q) {
    final clean = q.replaceAll(RegExp(r'[+\-&|!(){}\[\]^"~*?:\\/]'), ' ').trim();
    if (clean.isEmpty) return trending();
    return _licensedQuery('($clean) AND mediatype:audio');
  }
  @override
  Future<List<Track>> trending() => _licensedQuery('mediatype:audio AND collection:netlabels');
  @override
  Future<List<Track>> expand(Track item) async {
    final id = item.path.replaceFirst('ia://', '');
    final r = await _apiGet(Uri.https('archive.org', '/metadata/$id'));
    final j = r[1];
    if (r[0] != 200 || j is! Map) throw 'could not open this item (error ${r[0]})';
    final meta = j['metadata'] is Map ? j['metadata'] as Map : <dynamic, dynamic>{};
    if (!_licensed(meta['licenseurl'])) throw 'This recording has no open license, so Cadence will not play it.';
    final lic = ccLabel(_s(meta['licenseurl']));
    final albumTitle = _s(meta['title']);
    final albumArtist = _s(meta['creator']);
    final files = j['files'] is List ? j['files'] as List : const [];
    final byBase = <String, Map>{};
    for (final f in files) {
      if (f is! Map || f['name'] == null) continue;
      final fmt = (f['format'] ?? '').toString().toLowerCase();
      final isMp3 = fmt.contains('mp3'), isOgg = fmt.contains('ogg vorbis');
      if (!isMp3 && !isOgg) continue;
      final name = f['name'].toString();
      final dot = name.lastIndexOf('.');
      final base = dot > 0 ? name.substring(0, dot) : name;
      final old = byBase[base];
      if (old == null || (isMp3 && !(old['format'] ?? '').toString().toLowerCase().contains('mp3'))) { byBase[base] = f; }
    }
    final list = byBase.values.toList();
    int trackNo(Map f) => int.tryParse(_s(f['track']).split('/').first) ?? 9999;
    list.sort((a, b) {
      final c = trackNo(a).compareTo(trackNo(b));
      return c != 0 ? c : a['name'].toString().compareTo(b['name'].toString());
    });
    final out = <Track>[];
    for (final f in list.take(200)) {
      final name = f['name'].toString();
      final slash = name.lastIndexOf('/');
      final file = name.substring(slash + 1);
      final dot = file.lastIndexOf('.');
      final fallback = (dot > 0 ? file.substring(0, dot) : file).replaceAll('_', ' ');
      final len = _s(f['length']);
      double secs = 0;
      if (len.contains(':')) {
        for (final part in len.split(':')) { secs = secs * 60 + (double.tryParse(part) ?? 0); }
      } else {
        secs = double.tryParse(len) ?? 0;
      }
      final artist = _s(f['creator']).isNotEmpty ? _s(f['creator']) : (_s(f['artist']).isNotEmpty ? _s(f['artist']) : (albumArtist.isEmpty ? item.artist : albumArtist));
      out.add(mkTrack(p: this, url: Uri(scheme: 'https', host: 'archive.org', pathSegments: ['download', id, ...name.split('/')]).toString(),
          title: _s(f['title']).isNotEmpty ? _s(f['title']) : fallback, artist: artist,
          album: _s(f['album']).isNotEmpty ? _s(f['album']) : albumTitle, cover: 'https://archive.org/services/img/$id',
          ms: (secs * 1000).round(), license: lic));
    }
    return out;
  }
}

// 4) Your own GitHub repo with songs in it (connected in Providers).
class RepoProvider extends MusicProvider {
  @override
  String get id => 'repo';
  @override
  String get name => 'My GitHub repo';
  @override
  String get blurb => 'Songs you host in your own public repo';
  @override
  IconData get icon => Icons.cloud_outlined;
  @override
  List<String> get caps => const ['Search', 'Streaming', 'Artwork'];
  @override
  bool get ready => repoLink.value != null;
  @override
  String get setup => 'Connect your repo in Providers';
  @override
  Future<List<Track>> search(String q) async {
    final k = q.toLowerCase();
    return [for (final t in onlineTracks.value) if ('${t.title} ${t.artist} ${t.album}'.toLowerCase().contains(k)) t];
  }
  @override
  Future<List<Track>> trending() async => onlineTracks.value.take(60).toList();
}

// 5) Providers you describe yourself in `providers.json` inside your connected repo.
//    Data only: Cadence calls the https JSON API you describe and plays the https stream URLs it returns.
//    No code from the repo is ever run.
class JsonProvider extends MusicProvider {
  final Map cfg;
  final String repo;
  JsonProvider(this.cfg, this.repo);
  @override
  String get id => 'json:$repo:${cfg['id']}';
  @override
  String get name => (cfg['name'] ?? cfg['id']).toString();
  @override
  String get blurb => '${(cfg['description'] ?? 'Data-only provider').toString()} (from $repo)';
  String get hosts {
    final h = <String>{};
    for (final k in ['search', 'trending']) {
      final sp = cfg[k];
      if (sp is Map) {
        final u = Uri.tryParse((sp['url'] ?? '').toString());
        if (u != null && u.host.isNotEmpty) { h.add(u.host); }
      }
    }
    final t = Uri.tryParse((cfg['streamTemplate'] ?? '').toString());
    if (t != null && t.host.isNotEmpty) { h.add(t.host); }
    return h.isEmpty ? 'unknown host' : h.join(', ');
  }
  @override
  IconData get icon => Icons.extension_rounded;
  @override
  List<String> get caps => [if (cfg['search'] is Map) 'Search', if (cfg['trending'] is Map) 'Browse', 'Streaming', 'From your repo'];
  Future<List<Track>> _run(Map spec, Map<String, String> vars) async {
    var url = (spec['url'] ?? '').toString();
    vars.forEach((k, v) { url = url.replaceAll('{$k}', Uri.encodeQueryComponent(v)); });
    final u = Uri.tryParse(url);
    if (u == null || u.scheme != 'https') throw 'provider URLs must start with https://';
    final r = await _apiGet(u);
    if (r[0] != 200) throw 'answered with error ${r[0]}';
    final items = jget(r[1], spec['results']?.toString());
    if (items is! List) throw 'did not return a list of tracks';
    final f = cfg['fields'] is Map ? cfg['fields'] as Map : <dynamic, dynamic>{};
    final unit = (cfg['durationUnit'] ?? 's').toString();
    final tmpl = cfg['streamTemplate']?.toString();
    final out = <Track>[];
    for (final e in items.take(60)) {
      String? g(String k) { final v = jget(e, f[k]?.toString()); return v?.toString(); }
      var stream = g('stream');
      if ((stream == null || stream.isEmpty) && tmpl != null) { stream = tmpl.replaceAll('{id}', g('id') ?? ''); }
      if (stream == null || !stream.startsWith('https://')) continue;
      final dur = double.tryParse(g('duration') ?? '') ?? 0;
      out.add(mkTrack(p: this, url: stream, title: g('title') ?? 'Untitled', artist: g('artist') ?? 'Unknown artist',
          album: g('album') ?? '', cover: g('cover'), ms: unit == 'ms' ? dur.round() : (dur * 1000).round(), license: cfg['license']?.toString()));
    }
    return out;
  }
  @override
  Future<List<Track>> search(String q) async {
    final s = cfg['search'];
    if (s is! Map) return [];
    return _run(s, {'query': q, 'limit': '30'});
  }
  @override
  Future<List<Track>> trending() async {
    final s = cfg['trending'];
    if (s is! Map) return [];
    return _run(s, {'limit': '30'});
  }
}

class ProviderHub {
  final builtIn = <MusicProvider>[AudiusProvider(), JamendoProvider(), ArchiveProvider(), RepoProvider()];
  final json = ValueNotifier<List<MusicProvider>>([]);
  final enabled = <String, bool>{};
  final results = ValueNotifier<List<Track>>([]);
  final busy = ValueNotifier<bool>(false);
  final errors = ValueNotifier<Map<String, String>>({});
  String query = '';
  List<MusicProvider> get all => [...builtIn, ...json.value];
  MusicProvider? byId(String id) { for (final p in all) { if (p.id == id) return p; } return null; }
  bool on(MusicProvider p) => enabled[p.id] ?? (p is! JsonProvider);
  Future<void> setOn(MusicProvider p, bool v) async {
    enabled[p.id] = v;
    (await SharedPreferences.getInstance()).setBool('prov_${p.id}', v);
  }
  Future<void> loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    for (final p in all) { enabled[p.id] = sp.getBool('prov_${p.id}') ?? (p is! JsonProvider); }
  }
  // One search across every enabled provider. Results are mixed so no single source takes over.
  Future<void> search(String q) async {
    query = q.trim();
    busy.value = true;
    final errs = <String, String>{};
    try {
      final active = all.where((p) => on(p) && p.ready).toList();
      final lists = await Future.wait(active.map((p) async {
        try {
          return query.isEmpty ? await p.trending() : await p.search(query);
        } catch (e) {
          errs[p.id] = e.toString();
          return <Track>[];
        }
      }));
      final merged = <Track>[];
      for (int i = 0; ; i++) {
        var any = false;
        for (final l in lists) { if (i < l.length) { merged.add(l[i]); any = true; } }
        if (!any) break;
      }
      results.value = merged;
    } finally {
      errors.value = errs;
      busy.value = false;
    }
  }
}
final hub = ProviderHub();

// Plays one online result. Collections (like an Internet Archive recording) open into their tracks first.
Future<void> onlinePlay(List<Track> list, int i) async {
  final t = list[i];
  if (isCollection(t)) {
    final p = hub.byId(provOf(t));
    if (p == null) return;
    snack('Opening "${t.title}"…');
    try {
      final files = await p.expand(t);
      if (files.isEmpty) { snack('No playable audio was found in this item.'); return; }
      await playList(files, 0);
    } catch (e) {
      snack('${p.name}: ${e.toString().replaceFirst('Exception: ', '')}');
    }
    return;
  }
  final playable = [for (final x in list) if (!isCollection(x)) x];
  final idx = playable.indexWhere((x) => x.path == t.path);
  await playList(playable, idx < 0 ? 0 : idx);
}

void providerSheet(BuildContext c) => _sheet(c, StatefulBuilder(builder: (ctx, setS) => SizedBox(
    height: MediaQuery.sizeOf(ctx).height * .72,
    child: ListView(children: [
      const Padding(padding: EdgeInsets.fromLTRB(20, 6, 20, 2), child: Text('Music providers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(
          'Turn sources on or off. One search covers every source that is on. Only legal, licensed or self-hosted music is supported.',
          style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.65)))),
      for (final p in hub.all) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(secondary: Icon(p.icon), title: Text(p.name), isThreeLine: true, value: hub.on(p),
            subtitle: Text('${p.blurb}\nCan: ${p.caps.join(' · ')}${p is JsonProvider ? '\nConnects to ${p.hosts}' : ''}${p.ready ? '' : '\n! ${p.setup}'}'),
            onChanged: (v) async { await hub.setOn(p, v); setS(() {}); }),
        if (p.id == 'jamendo') Padding(padding: const EdgeInsets.only(left: 72), child: TextButton(
            onPressed: () async {
              final v = await askText(ctx, 'Jamendo client ID', jamendoKey.value);
              if (v == null) return;
              jamendoKey.value = v.trim();
              (await SharedPreferences.getInstance()).setString('jamendoKey', v.trim());
              setS(() {});
            }, child: Text(jamendoKey.value.isEmpty ? 'Add client ID' : 'Change client ID'))),
        if (p.id == 'repo') Padding(padding: const EdgeInsets.only(left: 72), child: TextButton(
            onPressed: () async { await repoDialog(ctx); setS(() {}); },
            child: Text(repoLink.value == null ? 'Add repos' : 'Manage repos'))),
      ]),
      const SizedBox(height: 16),
    ]))));


class RepoRef { final String o, r; final String? b; const RepoRef(this.o, this.r, this.b); }
RepoRef? parseRepo(String raw) {
  final first = raw.trim().split(RegExp(r'\s+')).first;
  var x = first.replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'^www\.'), '');
  x = x.split('?').first.split('#').first;
  final p = x.split('/').where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return null;
  if (p.first == 'github.com') {
    p.removeAt(0);
  } else if (p.first == 'raw.githubusercontent.com') {
    p.removeAt(0);
    if (p.length >= 3) return RepoRef(p[0], p[1], p[2]);
    return null;
  } else if (p.first == 'api.github.com') {
    if (p.length >= 4 && p[1] == 'repos') return RepoRef(p[2], p[3], null);
    return null;
  } else if (p.first.contains('.')) {
    return null;
  }
  if (p.length < 2) return null;
  var repo = p[1];
  if (repo.endsWith('.git')) { repo = repo.substring(0, repo.length - 4); }
  final br = (p.length >= 4 && (p[2] == 'tree' || p[2] == 'blob')) ? p[3] : null;
  return RepoRef(p[0], repo, br);
}

// Follows short links (like share.google) to find the real github.com address.
Future<String> resolveLink(String raw) async {
  var u = raw.trim().split(RegExp(r'\s+')).first;
  for (int i = 0; i < 6; i++) {
    final uri = Uri.tryParse(u.startsWith('http') ? u : 'https://$u');
    if (uri == null || uri.host.isEmpty) return u;
    if (uri.host.endsWith('github.com') || uri.host == 'raw.githubusercontent.com') return u;
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final rq = await c.getUrl(uri);
      rq.followRedirects = false;
      rq.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 14) Cadence/1.0');
      final rs = await rq.close().timeout(const Duration(seconds: 10));
      final loc = rs.headers.value('location');
      await rs.drain();
      if (loc == null) return u;
      u = uri.resolve(loc).toString();
    } catch (_) {
      return u;
    } finally { c.close(force: true); }
  }
  return u;
}

Future<List<dynamic>> _gh(Uri u) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final rq = await c.getUrl(u);
    rq.headers.set('User-Agent', 'Cadence/1.0');
    rq.headers.set('Accept', 'application/vnd.github+json');
    final rs = await rq.close().timeout(const Duration(seconds: 25));
    final body = await rs.transform(utf8.decoder).join();
    dynamic j;
    try { j = jsonDecode(body); } catch (_) {}
    return [rs.statusCode, j];
  } finally { c.close(force: true); }
}

Future<bool> connectRepo(String raw, {bool quiet = false, int depth = 0}) async {
  onlineBusy.value = true;
  try {
    var link = raw.trim();
    var ref = parseRepo(link);
    if (ref == null) { link = await resolveLink(link); ref = parseRepo(link); }
    if (ref == null) {
      if (!quiet) snack('That is not a GitHub repo address. Open your repo on github.com, copy the address from the browser bar, and paste it here.');
      return false;
    }
    final rf = ref;
    var branch = rf.b;
    if (branch == null) {
      final r = await _gh(Uri.https('api.github.com', '/repos/${rf.o}/${rf.r}'));
      if (r[0] == 404) { if (!quiet) snack('Repo "${rf.o}/${rf.r}" not found. Check the name, and make sure it is public.'); return false; }
      if (r[0] == 403 || r[0] == 429) { if (!quiet) snack('GitHub is limiting requests right now. Try again in a few minutes.'); return false; }
      if (r[0] != 200 || r[1] is! Map) { if (!quiet) snack('GitHub answered with error ${r[0]}.'); return false; }
      branch = ((r[1] as Map)['default_branch'] ?? 'main').toString();
    }
    final tr = await _gh(Uri.https('api.github.com', '/repos/${rf.o}/${rf.r}/git/trees/$branch', {'recursive': '1'}));
    if (tr[0] == 404) { if (!quiet) snack('Branch "$branch" was not found, or the repo is empty.'); return false; }
    if (tr[0] == 403 || tr[0] == 429) { if (!quiet) snack('GitHub is limiting requests right now. Try again in a few minutes.'); return false; }
    final tj = tr[1];
    if (tr[0] != 200 || tj is! Map || tj['tree'] is! List) { if (!quiet) snack('Could not read that repo (error ${tr[0]}).'); return false; }
    const audio = {'mp3', 'flac', 'm4a', 'aac', 'ogg', 'opus', 'wav'};
    const imgs = {'jpg', 'jpeg', 'png'};
    final files = <Map>[];
    final images = <String>{};
    String? provPath;
    for (final e in (tj['tree'] as List)) {
      if (e is! Map || e['type'] != 'blob') continue;
      final path = e['path'].toString();
      if (path == 'providers.json' || path == 'cadence-providers.json' || path == 'registry.json') { provPath = path; continue; }
      final dot = path.lastIndexOf('.');
      if (dot < 0) continue;
      final ext = path.substring(dot + 1).toLowerCase();
      if (audio.contains(ext)) { files.add(e); }
      else if (imgs.contains(ext)) { images.add(path); }
    }
    final br = branch;
    String url(String path) => Uri(scheme: 'https', host: 'raw.githubusercontent.com', pathSegments: [rf.o, rf.r, br, ...path.split('/')]).toString();
    final out = <Track>[];
    final byUrl = <String, Track>{};
    for (final e in files) {
      final path = e['path'].toString();
      final slash = path.lastIndexOf('/');
      final dir = slash < 0 ? '' : path.substring(0, slash);
      final file = path.substring(slash + 1);
      final dot = file.lastIndexOf('.');
      final base = file.substring(0, dot).replaceAll('_', ' ').trim();
      final ext = file.substring(dot + 1).toUpperCase();
      final folder = dir.isEmpty ? rf.r : dir.split('/').last;
      var title = base, artist = dir.isEmpty ? rf.o : folder;
      final sep = base.indexOf(' - ');
      if (sep > 0) { artist = base.substring(0, sep).trim(); title = base.substring(sep + 3).trim(); }
      final u = url(path);
      final stem = path.substring(0, path.lastIndexOf('.'));
      final pre = dir.isEmpty ? '' : '$dir/';
      String? cover;
      for (final c in ['$stem.jpg', '$stem.jpeg', '$stem.png', '${pre}cover.jpg', '${pre}cover.png', '${pre}folder.jpg']) {
        if (images.contains(c)) { cover = url(c); break; }
      }
      if (cover != null) { onlineCover[u] = cover; }
      final t = Track({'p': u, 't': title, 'a': artist, 'al': folder, 'f': '$ext · Online', 'd': 0, 's': (e['size'] is int) ? e['size'] : 0, 'ad': 0, 'prov': 'repo'});
      out.add(t);
      byUrl[u] = t;
    }
    out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    onlineByUrl.addAll(byUrl);
    onlineTracks.value = out;
    final key = 'https://github.com/${rf.o}/${rf.r}';
    final tag = '${rf.o}/${rf.r}';
    final extra = <MusicProvider>[];
    final subRepos = <String>[];
    var skippedExec = false;
    if (provPath != null) {
      try {
        final pr = await _apiGet(Uri.parse(url(provPath)));
        final pj = pr[1];
        if (pr[0] == 200 && pj != null) {
          if (pj is Map && pj['extensions'] is List) {
            skippedExec = true;
          } else {
            final plist = pj is Map ? pj['providers'] : pj;
            if (plist is List) {
              for (final e in plist) { if (e is Map && e['id'] != null) { extra.add(JsonProvider(e, tag)); } }
            }
            final rl = pj is Map ? pj['repos'] : null;
            if (rl is List) { for (final x in rl.take(10)) { if (x is String) { subRepos.add(x); } } }
          }
        }
      } catch (_) {}
    }
    if (skippedExec && out.isEmpty && subRepos.isEmpty) {
      if (!quiet) snack('That registry lists downloadable extensions. Cadence only supports data-only provider lists and never runs extension code, so nothing was added.');
      return false;
    }
    _repoTracks[key] = out;
    _repoProvs[key] = extra;
    if (!repoList.value.contains(key)) { repoList.value = [...repoList.value, key]; }
    _mergeRepos();
    await hub.loadPrefs();
    await (await SharedPreferences.getInstance()).setStringList('repos', repoList.value);
    if (depth == 0) { for (final r in subRepos) { await connectRepo(r, quiet: true, depth: 1); } }
    if (!quiet) {
      snack(out.isEmpty && extra.isEmpty && subRepos.isEmpty
          ? 'Added $tag, but no songs or providers were found in it.'
          : 'Added $tag: ${out.length} songs${extra.isEmpty ? '' : ', ${extra.length} provider${extra.length == 1 ? '' : 's'} (switch them on in Providers)'}${subRepos.isEmpty ? '' : ', ${subRepos.length} linked repo${subRepos.length == 1 ? '' : 's'}'}.');
    }
    return true;
  } catch (_) {
    if (!quiet) snack('Could not connect. Check your internet connection and try again.');
    return false;
  } finally { onlineBusy.value = false; }
}

Future<void> repoDialog(BuildContext c) async {
  final tc = TextEditingController();
  await showDialog<void>(context: c, builder: (d) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('Repositories'),
      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: tc, keyboardType: TextInputType.url,
            decoration: InputDecoration(hintText: 'https://github.com/user/repo',
                suffixIcon: IconButton(icon: const Icon(Icons.add_circle_rounded), onPressed: () async {
                  final v = tc.text.trim();
                  if (v.isEmpty) return;
                  tc.clear();
                  await connectRepo(v);
                  setS(() {});
                }))),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<String>>(valueListenable: repoList, builder: (_, l, __) => l.isEmpty
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No repositories yet.'))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                for (final k in l) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.cloud_outlined),
                    title: Text(k.replaceFirst('https://github.com/', ''), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${_repoTracks[k]?.length ?? 0} songs · ${_repoProvs[k]?.length ?? 0} providers'),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () async { await removeRepo(k); setS(() {}); })),
              ])),
        const SizedBox(height: 8),
        const Text('Add your own repo or any other public repo. Songs: mp3, flac, m4a, ogg, opus or wav, named "Artist - Title.mp3". Providers: a providers.json or registry.json file (data only, and switched off until you turn them on). A registry can also list more repos with "repos". Only add repos with music you are allowed to use.',
            style: TextStyle(fontSize: 12)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Done'))])));
}
final fx = ValueNotifier<int>(0);
const fxNames = ['Off', 'Sakura petals', 'Neon rain', 'Snow', 'Sparkles', 'Fireflies', 'Film grain'];
// name, theme index, card style, effect
const looks = [
  ['Sakura dream', 7, 2, 1], ['Moonlit anime', 11, 2, 4], ['Magical girl', 10, 2, 4],
  ['Neon city', 23, 1, 2], ['Mecha grid', 12, 1, 4], ['Cartoon morning', 15, 3, 4],
  ['Cheese chase', 14, 3, 4], ['Movie night', 19, 4, 6], ['Noir', 18, 4, 6],
  ['Winter glass', 1, 0, 3], ['Forest night', 6, 0, 5],
];
Future<void> applyLook(int t, int sk, int f) async {
  autoTheme.value = false;
  themeIx.value = t; skin.value = sk; fx.value = f;
  final sp = await SharedPreferences.getInstance();
  await sp.setBool('auto', false);
  await sp.setInt('theme', t);
  await sp.setInt('skin', sk);
  await sp.setInt('fx', f);
}
const skinNames = ['Liquid glass', 'Cyberpunk', 'Anime', 'Cartoon', 'Cinema'];
final matchWall = ValueNotifier<bool>(false);
final wallAccent = ValueNotifier<Color?>(null);
Future<void> updateWallAccent() async {
  final p = wallpaperPath.value;
  wallAccent.value = (matchWall.value && p != null) ? await dominantColor(p) : null;
}
final wallpaperPath = ValueNotifier<String?>(null);
final wallDim = ValueNotifier<double>(.45);
Future<void> pickWallpaper() async {
  try {
    final r = await FilePicker.platform.pickFiles(type: FileType.image);
    final src = r?.files.single.path;
    if (src == null) return;
    final dst = '${lib.docs.path}/wall_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(src).copy(dst);
    final old = wallpaperPath.value;
    wallpaperPath.value = dst;
    (await SharedPreferences.getInstance()).setString('wall', dst);
    await updateWallAccent();
    if (old != null) { try { await File(old).delete(); } catch (_) {} }
  } catch (_) { snack('Could not use that picture.'); }
}
Future<void> clearWallpaper() async {
  final old = wallpaperPath.value;
  wallpaperPath.value = null;
  wallAccent.value = null;
  (await SharedPreferences.getInstance()).remove('wall');
  if (old != null) { try { await File(old).delete(); } catch (_) {} }
}
final autoTheme = ValueNotifier<bool>(false);
void applyAutoTheme() {
  if (!autoTheme.value) return;
  final h = DateTime.now().hour;
  final ix = (h >= 5 && h < 11) ? 0 : (h >= 11 && h < 17) ? 2 : (h >= 17 && h < 20) ? 5 : (h >= 20 && h < 23) ? 1 : 3;
  if (themeIx.value != ix) themeIx.value = ix;
}
void snack(String s) => msgKey.currentState?..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(s)));
String fmt(Duration d) { final s = d.inSeconds; return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'; }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
      androidNotificationChannelId: 'com.tanimsarker.cadence.audio',
      androidNotificationChannelName: 'Cadence playback',
      androidNotificationOngoing: false, androidStopForegroundOnPause: false);
  final sp = await SharedPreferences.getInstance();
  themeIx.value = sp.getInt('theme') ?? 0;
  showSig.value = sp.getBool('sig') ?? true;
  autoTheme.value = sp.getBool('auto') ?? false;
  sigText.value = sp.getString('sigText') ?? 'TanimSarker';
  sigFont.value = sp.getInt('sigFont') ?? 0;
  sigSize.value = sp.getDouble('sigSize') ?? 22;
  recents.value = sp.getStringList('recent') ?? [];
  glassSkin.value = sp.getBool('glass') ?? true;
  wallpaperPath.value = sp.getString('wall');
  wallDim.value = sp.getDouble('wallDim') ?? .45;
  skin.value = sp.getInt('skin') ?? 0;
  fx.value = sp.getInt('fx') ?? 0;
  jamendoKey.value = sp.getString('jamendoKey') ?? '';
  await ytLoadPrefs(sp);
  await dnaLoadPresets(sp);
  await hub.loadPrefs();
  final savedRepos = sp.getStringList('repos') ?? [if (sp.getString('repo') != null) sp.getString('repo')!];
  if (savedRepos.isNotEmpty) {
    repoList.value = savedRepos;
    repoLink.value = savedRepos.length == 1 ? savedRepos.first : '${savedRepos.length} repos';
    Future(() async { for (final r in savedRepos) { await connectRepo(r, quiet: true); } });
  }
  matchWall.value = sp.getBool('matchWall') ?? false;
  updateWallAccent();
  adaptiveColors.value = sp.getBool('adaptive') ?? false;
  vizOn.value = sp.getBool('viz') ?? true;
  try {
    final dj = jsonDecode(sp.getString('diary') ?? '{}') as Map;
    for (final e in dj.entries) { diary[e.key as String] = Map<String, dynamic>.from(e.value as Map); }
    for (final x in sp.getStringList('capsules') ?? <String>[]) { capsules.add(Map<String, dynamic>.from(jsonDecode(x) as Map)); }
  } catch (_) {}
  player.sequenceStateStream.listen((_) => updateArtAccent());
  applyAutoTheme();
  Timer.periodic(const Duration(minutes: 10), (_) => applyAutoTheme());
  player.playbackEventStream.listen((_) {}, onError: (e, st) => snack('This file cannot be played (missing or unsupported).'));
  player.currentIndexStream.listen((_) { saveState(); _countTimer(); });
  player.playingStream.listen((_) => saveState());
  Timer.periodic(const Duration(seconds: 5), (_) { if (player.playing) saveState(); });
  runApp(const CadenceApp());
}

bool permsBusy = false;
// Asks one at a time, in order: music -> notifications -> battery -> appear on top. Then scans.
Future<void> startupPerms() async {
  if (!Platform.isAndroid) { lib.scan(); return; }
  permsBusy = true;
  try {
    var a = await Permission.audio.status;
    if (!a.isGranted) a = await Permission.audio.request();
    if (!a.isGranted) await Permission.storage.request();
    await Future.delayed(const Duration(milliseconds: 400));

    var n = await Permission.notification.status;
    if (!n.isGranted) n = await Permission.notification.request();
    if (!n.isGranted) {
      msgKey.currentState?..hideCurrentSnackBar()..showSnackBar(SnackBar(
          duration: const Duration(seconds: 12),
          content: const Text('Allow notifications to control music from the lock screen and notification panel.'),
          action: SnackBarAction(label: 'Settings', onPressed: () { openAppSettings(); })));
    }
    await Future.delayed(const Duration(milliseconds: 400));

    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
    await Future.delayed(const Duration(milliseconds: 400));

    if (!await Permission.systemAlertWindow.isGranted) {
      await Permission.systemAlertWindow.request();
    }
  } catch (_) {}
  permsBusy = false;
  lib.scan();
  Future.delayed(const Duration(seconds: 10), ytAutoSyncRun);
}

Route<T> slideUp<T>(Widget w) => PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 450), reverseTransitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, __, ___) => w,
    transitionsBuilder: (_, a, __, c) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)), child: c));

AudioSource _src(Track t) {
  final online = t.path.startsWith('http');
  final cv = onlineCover[t.path];
  return AudioSource.uri(online ? Uri.parse(t.path) : Uri.file(t.path),
      tag: MediaItem(id: t.path, title: t.title, artist: t.artist, album: t.album,
          artUri: t.art != null ? Uri.file(t.art!) : (cv != null ? Uri.parse(cv) : null),
          duration: t.dur > 0 ? Duration(milliseconds: t.dur) : null));
}

Future<void> ensureNotif() async {
  if (!Platform.isAndroid || permsBusy) return;
  try {
    var n = await Permission.notification.status;
    if (n.isGranted) return;
    n = await Permission.notification.request();
    if (!n.isGranted) {
      msgKey.currentState?..hideCurrentSnackBar()..showSnackBar(SnackBar(
          duration: const Duration(seconds: 15),
          content: const Text('Notifications are off, so lock screen and notification panel controls cannot show.'),
          action: SnackBarAction(label: 'Turn on', onPressed: () { openAppSettings(); })));
    }
  } catch (_) {}
}

bool _diagShown = false;
void _diagOnce() {
  if (_diagShown || !Platform.isAndroid) return;
  _diagShown = true;
  Future.delayed(const Duration(seconds: 3), () async {
    try {
      final n = await Permission.notification.status;
      final b = await Permission.ignoreBatteryOptimizations.isGranted;
      snack('Check: notifications ${n.isGranted ? "ON" : "OFF"} - battery ${b ? "OK" : "restricted"} - build 29');
    } catch (_) {}
  });
}

Future<void> playList(List<Track> l, int i) async {
  await ensureNotif();
  final src = ConcatenatingAudioSource(children: [for (final t in l) _src(t)], shuffleOrder: NextShuffleOrder());
  try {
    await player.setAudioSource(src, initialIndex: i);
    player.play();
    restoreEq();
    _diagOnce();
  } catch (e) { snack('Cannot play this file. It may be missing or unsupported.'); }
}

Future<void> restoreEq() async {
  if (!Platform.isAndroid) return;
  try {
    final p = await SharedPreferences.getInstance();
    await eq.setEnabled(p.getBool('eqon') ?? false);
    final g = p.getStringList('eqg'); final ps = await eq.parameters;
    if (g != null && g.length == ps.bands.length) { for (int i = 0; i < g.length; i++) { await ps.bands[i].setGain(double.parse(g[i])); } }
    final lg = p.getDouble('loud') ?? 0; await loud.setTargetGain(lg); await loud.setEnabled(lg > 0);
  } catch (_) {}
}

// ---- queue + state persistence ----
Future<void> saveState() async {
  try {
    final seq = player.sequence;
    if (seq == null || seq.isEmpty) return;
    final paths = [for (final x in seq) if (x.tag is MediaItem) (x.tag as MediaItem).id];
    if (paths.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setStringList('q', paths);
    await p.setInt('qi', player.currentIndex ?? 0);
    await p.setInt('qpos', player.position.inMilliseconds);
  } catch (_) {}
}

Future<void> restoreState() async {
  try {
    final p = await SharedPreferences.getInstance();
    final q = p.getStringList('q');
    if (q == null || q.isEmpty) return;
    final ts = [for (final x in q) if (lib.byPath[x] != null) lib.byPath[x]!];
    if (ts.isEmpty) return;
    final qi = p.getInt('qi') ?? 0;
    final cur = qi >= 0 && qi < q.length ? q[qi] : null;
    var ix = ts.indexWhere((t) => t.path == cur);
    if (ix < 0) ix = 0;
    await player.setAudioSource(ConcatenatingAudioSource(children: [for (final t in ts) _src(t)], shuffleOrder: NextShuffleOrder()),
        initialIndex: ix, initialPosition: Duration(milliseconds: p.getInt('qpos') ?? 0));
    restoreEq();
  } catch (_) {}
}

Timer? _ct;
void _countTimer() {
  _ct?.cancel();
  final seq = player.sequence, i = player.currentIndex;
  if (seq == null || i == null || i < 0 || i >= seq.length) return;
  final tag = seq[i].tag;
  if (tag is! MediaItem) return;
  _ct = Timer(const Duration(seconds: 20), () {
    if (player.playing && player.currentIndex == i) { lib.countPlay(tag.id); recentAdd(tag.id); final tr = lib.byPath[tag.id]; if (tr != null) { diaryAdd(tr); lbSubmit(tr); } }
  });
}

bool wantNextFirst = false;
// Keeps "Play next" songs right after the current one even when shuffle is on.
class NextShuffleOrder extends DefaultShuffleOrder {
  @override
  void insert(int index, int count) {
    super.insert(index, count);
    if (!wantNextFirst) return;
    final cur = player.currentIndex;
    if (cur == null) return;
    final fresh = [for (int i = index; i < index + count; i++) i];
    indices.removeWhere(fresh.contains);
    final pos = indices.indexOf(cur);
    indices.insertAll(pos < 0 ? 0 : pos + 1, fresh);
  }
}

Future<void> addMany(List<Track> l, {bool next = false}) async {
  if (l.isEmpty) return;
  final s = player.audioSource;
  if (s is! ConcatenatingAudioSource || s.length == 0) { await playList(l, 0); return; }
  try {
    final kids = [for (final t in l) _src(t)];
    if (next) {
      wantNextFirst = true;
      await s.insertAll((player.currentIndex ?? -1) + 1, kids);
    } else {
      await s.addAll(kids);
    }
    snack(next ? (l.length == 1 ? 'Will play next' : '${l.length} songs will play next') : (l.length == 1 ? 'Added to queue' : '${l.length} songs added to queue'));
  } catch (_) { snack('Could not add to queue.'); }
  finally { wantNextFirst = false; }
}

Future<void> addToQueue(Track t, {bool next = false}) => addMany([t], next: next);

Future<void> playNext(Track t) => addToQueue(t, next: true);

Timer? _sl;
StreamSubscription<int?>? _slSub;
void sleepIn(int min) {
  _sl?.cancel();
  _slSub?.cancel(); _slSub = null;
  if (min == 0) { snack('Sleep timer off'); return; }
  if (min == -1) {
    final i0 = player.currentIndex;
    snack('Music will stop after this song');
    _slSub = player.currentIndexStream.listen((x) {
      if (x != i0) { player.pause(); _slSub?.cancel(); _slSub = null; }
    });
    return;
  }
  snack('Music will fade out and stop in $min min');
  _sl = Timer(Duration(minutes: min), () async {
    for (int i = 20; i >= 0; i--) { await player.setVolume(i / 20); await Future.delayed(const Duration(milliseconds: 750)); }
    await player.pause(); await player.setVolume(1);
  });
}

class CadenceApp extends StatelessWidget {
  const CadenceApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([themeIx, artAccent, adaptiveColors, wallAccent, matchWall]),
      builder: (_, __) {
        final t = th;
        final cs = ColorScheme.fromSeed(seedColor: t.ac, brightness: t.dark ? Brightness.dark : Brightness.light)
            .copyWith(primary: t.ac, onSurface: t.tx, surface: t.bg);
        final base = ThemeData(useMaterial3: true, colorScheme: cs);
        return MaterialApp(
          title: 'Cadence', debugShowCheckedModeBanner: false, scaffoldMessengerKey: msgKey, navigatorKey: navKey,
          theme: base.copyWith(scaffoldBackgroundColor: Colors.transparent,
              textTheme: base.textTheme.apply(bodyColor: t.tx, displayColor: t.tx)),
          builder: (c, child) => Stack(children: [
            Positioned.fill(child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color.lerp(t.bg, t.bg2, .6)!, t.bg, Color.lerp(t.bg, t.bg2, .35)!])))),
            const Positioned.fill(child: WallLayer()),
            Positioned(top: -90, left: -80, child: _blob(t.ac, 300)),
            Positioned(bottom: 120, right: -120, child: _blob(t.bg2, 340)),
            const Positioned.fill(child: FxLayer()),
            child!,
          ]),
          home: const Splash(),
        );
      });
  Widget _blob(Color c, double s) => IgnorePointer(child: Container(width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withOpacity(.25), Colors.transparent]))));
}

double _h(int i, int k) {
  final x = m.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

class FxLayer extends StatefulWidget { const FxLayer({super.key}); @override State<FxLayer> createState() => _FxS(); }
class _FxS extends State<FxLayer> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 120))..repeat();
  @override
  void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => ValueListenableBuilder<int>(valueListenable: fx, builder: (_, k, __) => k == 0
      ? const SizedBox.shrink()
      : IgnorePointer(child: AnimatedBuilder(animation: c, builder: (_, __) =>
          CustomPaint(size: Size.infinite, painter: _FxP(k, c.value * 120, th.ac)))));
}

class _FxP extends CustomPainter {
  final int k; final double t; final Color ac;
  _FxP(this.k, this.t, this.ac);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    if (w <= 0 || h <= 0) return;
    if (k == 1) {
      final p = Paint()..color = const Color(0xFFF8B4D0).withOpacity(.8);
      for (int i = 0; i < 28; i++) {
        final sp = 30 + _h(i, 2) * 40;
        final y = ((t * sp + _h(i, 3) * h) % (h + 40)) - 20;
        final x = _h(i, 1) * w + 25 * m.sin(t * .8 + i);
        c.save();
        c.translate(x, y);
        c.rotate(t * (.5 + _h(i, 4)) + i);
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: 11, height: 6), p);
        c.restore();
      }
    } else if (k == 2) {
      final p = Paint()..color = ac.withOpacity(.4)..strokeWidth = 1.2..strokeCap = StrokeCap.round;
      for (int i = 0; i < 60; i++) {
        final sp = 500 + _h(i, 2) * 400;
        final y = ((t * sp + _h(i, 3) * h) % (h + 60)) - 30;
        final x = _h(i, 1) * w;
        c.drawLine(Offset(x, y), Offset(x - 4, y + 22), p);
      }
    } else if (k == 3) {
      final p = Paint()..color = Colors.white.withOpacity(.75);
      for (int i = 0; i < 50; i++) {
        final sp = 25 + _h(i, 2) * 40;
        final y = ((t * sp + _h(i, 3) * h) % (h + 20)) - 10;
        final x = _h(i, 1) * w + 18 * m.sin(t * .6 + i);
        c.drawCircle(Offset(x, y), 1.2 + _h(i, 4) * 2.2, p);
      }
    } else if (k == 4) {
      for (int i = 0; i < 30; i++) {
        final tw = (m.sin(t * 1.5 + i * 3) + 1) / 2;
        final sz = 3 + _h(i, 3) * 6;
        final o = Offset(_h(i, 1) * w, _h(i, 2) * h);
        final p = Paint()..color = (i % 3 == 0 ? ac : Colors.white).withOpacity(.85 * tw)..strokeWidth = 1.2..strokeCap = StrokeCap.round;
        c.drawLine(o + Offset(-sz, 0), o + Offset(sz, 0), p);
        c.drawLine(o + Offset(0, -sz), o + Offset(0, sz), p);
        c.drawCircle(o, 1.3, p);
      }
    } else if (k == 5) {
      for (int i = 0; i < 22; i++) {
        final o = Offset(_h(i, 1) * w + 40 * m.sin(t * .3 + i * 2), _h(i, 2) * h + 40 * m.cos(t * .25 + i));
        final pulse = .5 + .5 * m.sin(t * 1.2 + i);
        c.drawCircle(o, 11, Paint()..color = const Color(0xFFFFE08A).withOpacity(.16 * pulse));
        c.drawCircle(o, 2, Paint()..color = const Color(0xFFFFF3C4).withOpacity(.4 + .5 * pulse));
      }
    } else if (k == 6) {
      final frame = (t * 8).floor();
      final p = Paint()..color = Colors.white.withOpacity(.14);
      final q = Paint()..color = Colors.black.withOpacity(.2);
      for (int i = 0; i < 140; i++) {
        final o = Offset(_h(i, frame) * w, _h(i, frame + 500) * h);
        c.drawRect(Rect.fromLTWH(o.dx, o.dy, 1.6, 1.6), i.isEven ? p : q);
      }
      if (_h(frame, 9) > .85) {
        final x = _h(frame, 10) * w;
        c.drawLine(Offset(x, 0), Offset(x, h), Paint()..color = Colors.white.withOpacity(.16)..strokeWidth = 1);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _FxP o) => true;
}

class WallLayer extends StatelessWidget {
  const WallLayer({super.key});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: Listenable.merge([wallpaperPath, wallDim, themeIx]),
      builder: (_, __) {
        final p = wallpaperPath.value;
        if (p == null || !File(p).existsSync()) return const SizedBox.shrink();
        return Stack(fit: StackFit.expand, children: [
          Image.file(File(p), fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ColoredBox(color: th.bg.withOpacity(wallDim.value)),
        ]);
      });
}

class _RimPainter extends CustomPainter {
  final double r; final bool dark;
  _RimPainter(this.r, this.dark);
  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(r)).deflate(.7);
    c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4
      ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, stops: const [0, .3, .7, 1], colors: [
        Colors.white.withOpacity(dark ? .6 : .95), Colors.white.withOpacity(.06), Colors.white.withOpacity(.06), Colors.white.withOpacity(dark ? .4 : .75)]).createShader(rect));
    final hl = Rect.fromLTWH(r * .6, 1.2, s.width - r * 1.2, 1.4);
    c.drawRect(hl, Paint()..shader = LinearGradient(colors: [Colors.white.withOpacity(0), Colors.white.withOpacity(dark ? .55 : .9), Colors.white.withOpacity(0)]).createShader(hl));
  }
  @override
  bool shouldRepaint(covariant _RimPainter o) => o.dark != dark || o.r != r;
}

class _ScanP extends CustomPainter {
  final Color col;
  _ScanP(this.col);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = col.withOpacity(.08)..strokeWidth = 1;
    for (double y = 2; y < s.height; y += 4) { c.drawLine(Offset(0, y), Offset(s.width, y), p); }
  }
  @override
  bool shouldRepaint(covariant _ScanP o) => o.col != col;
}

class _PerfP extends CustomPainter {
  final Color col;
  _PerfP(this.col);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = col.withOpacity(.5);
    for (double x = 14; x < s.width - 14; x += 14) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 3, 6, 4), const Radius.circular(1.5)), p);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, s.height - 7, 6, 4), const Radius.circular(1.5)), p);
    }
  }
  @override
  bool shouldRepaint(covariant _PerfP o) => o.col != col;
}

// A floating "card" in the chosen skin: Liquid glass, Cyberpunk, Anime, Cartoon or Cinema.
class GlassBox extends StatelessWidget {
  final Widget child; final double radius; final Gradient? fill;
  const GlassBox({super.key, required this.child, this.radius = 30, this.fill});
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<int>(valueListenable: skin, builder: (_, k, __) {
        final d = th.dark, ac = th.ac;
        final r = BorderRadius.circular(radius);
        if (k == 1) {
          final shape = BeveledRectangleBorder(borderRadius: BorderRadius.circular(radius * .7), side: BorderSide(color: ac, width: 1.6));
          final base = d ? const Color(0xF2080A16) : const Color(0xF2F6F4FF);
          return Container(
              decoration: ShapeDecoration(shape: shape, shadows: [BoxShadow(color: ac.withOpacity(.45), blurRadius: 20)]),
              child: ClipPath(clipper: ShapeBorderClipper(shape: shape), child: Container(
                  decoration: ShapeDecoration(shape: shape, gradient: fill ?? LinearGradient(colors: [base, Color.lerp(base, ac, .16)!], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Stack(fit: StackFit.passthrough, children: [child, Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ScanP(ac))))]))));
        }
        if (k == 2) {
          return Container(
              decoration: BoxDecoration(borderRadius: r, boxShadow: [BoxShadow(color: ac.withOpacity(.35), blurRadius: 24, offset: const Offset(0, 10))]),
              child: ClipRRect(borderRadius: r, child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                      decoration: BoxDecoration(borderRadius: r,
                          gradient: fill ?? LinearGradient(colors: [Colors.white.withOpacity(d ? .2 : .75), ac.withOpacity(d ? .22 : .28)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          border: Border.all(color: Colors.white.withOpacity(.9), width: 2.4)),
                      child: Stack(fit: StackFit.passthrough, children: [
                        child,
                        Positioned(top: 5, right: 18, child: IgnorePointer(child: Text('✦', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.95))))),
                        Positioned(bottom: 6, left: 22, child: IgnorePointer(child: Text('✧', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(.85))))),
                        Positioned(top: 8, left: 14, child: IgnorePointer(child: Text('✦', style: TextStyle(fontSize: 7, color: Colors.white.withOpacity(.8))))),
                      ])))));
        }
        if (k == 3) {
          final line = d ? Colors.white : Colors.black;
          final cr = BorderRadius.circular(radius * .8);
          return Container(
              decoration: BoxDecoration(borderRadius: cr, boxShadow: [BoxShadow(color: line, offset: const Offset(4, 5))]),
              child: Container(
                  decoration: BoxDecoration(borderRadius: cr, color: fill == null ? th.bg : null, gradient: fill, border: Border.all(color: line, width: 3)),
                  child: ClipRRect(borderRadius: cr, child: child)));
        }
        if (k == 4) {
          const gold = Color(0xFFE5B84B);
          final base = d ? const Color(0xCC14100A) : const Color(0xE6FFF6E0);
          return Container(
              decoration: BoxDecoration(borderRadius: r, boxShadow: [BoxShadow(color: Colors.black.withOpacity(.4), blurRadius: 24, offset: const Offset(0, 10))]),
              child: ClipRRect(borderRadius: r, child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                      decoration: BoxDecoration(borderRadius: r, gradient: fill ?? LinearGradient(colors: [base, Color.lerp(base, Colors.black, .35)!], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                          border: Border.all(color: gold.withOpacity(.85), width: 1.4)),
                      child: Stack(fit: StackFit.passthrough, children: [child, Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _PerfP(gold))))])))));
        }
        // 0: Apple-style liquid glass
        return Container(
            decoration: BoxDecoration(borderRadius: r, boxShadow: [BoxShadow(color: Colors.black.withOpacity(d ? .3 : .12), blurRadius: 30, spreadRadius: -4, offset: const Offset(0, 14))]),
            child: ClipRRect(borderRadius: r, child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: CustomPaint(foregroundPainter: _RimPainter(radius, d),
                    child: Container(
                        decoration: BoxDecoration(borderRadius: r, gradient: fill ?? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [Colors.white.withOpacity(d ? .06 : .13), Colors.white.withOpacity(d ? .012 : .025)])),
                        child: child)))));
      });
}
class Splash extends StatefulWidget { const Splash({super.key}); @override State<Splash> createState() => _SplashS(); }
class _SplashS extends State<Splash> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  @override
  void initState() {
    super.initState();
    Future.wait([lib.load().then((_) => restoreState()), Future.delayed(const Duration(milliseconds: 1200))]).then((_) {
      if (!mounted) return;
      Navigator.pushReplacement(context, PageRouteBuilder(transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, __, ___) => const Home(),
          transitionsBuilder: (_, a, __, ch) => FadeTransition(opacity: a, child: ch)));
      Future.delayed(const Duration(milliseconds: 900), () async { await startupPerms(); checkCapsules(); });
    });
  }
  @override
  void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
    return Scaffold(body: Center(child: FadeTransition(opacity: a, child: ScaleTransition(
        scale: Tween(begin: .92, end: 1.0).animate(a),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Cadence', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w200, letterSpacing: 4)),
          const SizedBox(height: 8),
          Text('DEEP, BLUE AND MIST', style: TextStyle(fontSize: 12, letterSpacing: 5, color: th.tx.withOpacity(.6))),
          const SizedBox(height: 10),
          Text('build 29', style: TextStyle(fontSize: 11, color: th.tx.withOpacity(.4))),
          const SizedBox(height: 26),
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: th.ac)),
        ])))));
  }
}

class Art extends StatelessWidget {
  final Track? t; final double s, r;
  const Art(this.t, this.s, this.r, {super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    final ph = Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [th.bg2, th.ac])),
        child: Icon(Icons.music_note_rounded, size: s * .45, color: Colors.white.withOpacity(.9)));
    final tt = t;
    final cv = tt == null ? null : onlineCover[tt.path];
    return ClipRRect(borderRadius: BorderRadius.circular(r), child: SizedBox(width: s, height: s,
        child: t?.art != null
            ? Image.file(File(t!.art!), fit: BoxFit.cover, gaplessPlayback: true,
                cacheWidth: (s * MediaQuery.devicePixelRatioOf(c)).round(), errorBuilder: (_, __, ___) => ph)
            : cv != null ? Image.network(cv, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => ph) : ph));
  }
}

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState() => _HomeS(); }
class _HomeS extends State<Home> with WidgetsBindingObserver {
  int i = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) saveState();
    if (s == AppLifecycleState.resumed && !permsBusy) lib.scan();
  }
  Widget _nav(Color bg) => NavigationBar(backgroundColor: bg, surfaceTintColor: Colors.transparent, elevation: 0, selectedIndex: i,
      indicatorColor: th.ac.withOpacity(.22),
      onDestinationSelected: (v) { HapticFeedback.selectionClick(); setState(() => i = v); },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'Library'),
        NavigationDestination(icon: Icon(Icons.cloud_outlined), selectedIcon: Icon(Icons.cloud), label: 'Online'),
        NavigationDestination(icon: Icon(Icons.queue_music_outlined), selectedIcon: Icon(Icons.queue_music), label: 'Mixes'),
        NavigationDestination(icon: Icon(Icons.equalizer_rounded), label: 'Equalizer'),
        NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
      ]);
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (w, a) => FadeTransition(opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(.04, 0), end: Offset.zero).animate(a), child: w)),
          child: KeyedSubtree(key: ValueKey(i), child: [const LibraryPage(), const OnlinePage(), const MixesTab(), const EqPage(), const SettingsPage()][i])),
      bottomNavigationBar: ValueListenableBuilder<bool>(valueListenable: glassSkin, builder: (_, g, __) => g
          ? SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const MiniPlayer(),
              GlassBox(radius: 34, child: _nav(Colors.transparent)),
            ])))
          : ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [const MiniPlayer(), _nav(th.bg.withOpacity(.55))])))),
    );
  }
}

class PlayBtn extends StatelessWidget {
  final double s;
  const PlayBtn(this.s, {super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    return StreamBuilder<PlayerState>(stream: player.playerStateStream, builder: (_, st) {
      final ps = st.data, pl = ps?.playing ?? false;
      final busy = ps?.processingState == ProcessingState.loading || ps?.processingState == ProcessingState.buffering;
      return Material(color: th.ac, shape: const CircleBorder(), elevation: s > 50 ? 6 : 0,
          child: InkWell(customBorder: const CircleBorder(),
              onTap: () { HapticFeedback.lightImpact(); pl ? player.pause() : player.play(); },
              child: SizedBox(width: s, height: s, child: Center(child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
                  child: busy
                      ? SizedBox(key: const ValueKey('b'), width: s * .4, height: s * .4,
                          child: const CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Icon(pl ? Icons.pause_rounded : Icons.play_arrow_rounded, key: ValueKey(pl), size: s * .58, color: Colors.white))))));
    });
  }
}

Track? curTrack(SequenceState? s) { final it = s?.currentSource?.tag; return it is MediaItem ? (lib.byPath[it.id] ?? onlineByUrl[it.id]) : null; }
Future<void> skipNext() async {
  if (player.hasNext) { await player.seekToNext(); }
  else if ((player.sequence?.length ?? 0) > 0) { await player.seek(Duration.zero, index: 0); }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  Widget _body(BuildContext c, Track t) => GestureDetector(
      onHorizontalDragEnd: (d) { final v = d.primaryVelocity ?? 0; if (v < -300) { skipNext(); } else if (v > 300) { player.seekToPrevious(); } },
      child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => Navigator.push(c, slideUp(const NowPlaying())),
          child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 8, 8), child: Row(children: [
            Hero(tag: 'art', child: Art(t, 46, 12)), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.65))),
            ])),
            const PlayBtn(44),
            IconButton(icon: const Icon(Icons.skip_next_rounded), onPressed: skipNext),
          ]))));
  @override
  Widget build(BuildContext c) => StreamBuilder<SequenceState?>(stream: player.sequenceStateStream, builder: (_, s) {
        final t = curTrack(s.data);
        return ValueListenableBuilder<bool>(valueListenable: glassSkin, builder: (_, g, __) => AnimatedSize(
            duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic,
            child: t == null ? const SizedBox(width: double.infinity)
                : g ? Padding(padding: const EdgeInsets.only(bottom: 8), child: GlassBox(radius: 30, child: _body(c, t))) : _body(c, t)));
      });
}
class LibraryPage extends StatefulWidget { const LibraryPage({super.key}); @override State<LibraryPage> createState() => _LibS(); }
class _LibS extends State<LibraryPage> {
  int tab = 0; String q = '', sort = 'title';
  bool selecting = false;
  final List<String> sel = [];
  Track? _find(String p) => lib.byPath[p] ?? onlineByUrl[p];
  List<Track> _picked() { final o = <Track>[]; for (final p in sel) { final t = _find(p); if (t != null) o.add(t); } return o; }
  void _toggle(String p) => setState(() { if (!sel.remove(p)) sel.add(p); });
  void _exitSel() => setState(() { selecting = false; sel.clear(); });
  Widget _selBar(BuildContext c, List<Track> shown) {
    final picked = _picked();
    return Padding(padding: const EdgeInsets.fromLTRB(8, 4, 12, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(icon: const Icon(Icons.close_rounded), onPressed: _exitSel),
        Expanded(child: Text('${sel.length} selected', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
        TextButton(onPressed: () => setState(() { for (final t in shown) { if (!sel.contains(t.path)) sel.add(t.path); } }), child: const Text('Select all')),
        const SizedBox(width: 4),
        FilledButton.icon(onPressed: picked.isEmpty ? null : () { final l = picked; _exitSel(); playList(l, 0); },
            icon: const Icon(Icons.play_arrow_rounded), label: const Text('Play')),
      ]),
      Wrap(spacing: 8, children: [
        ActionChip(avatar: const Icon(Icons.queue_play_next_rounded, size: 18), label: const Text('Play next'),
            onPressed: picked.isEmpty ? null : () { final l = picked; _exitSel(); addMany(l, next: true); }),
        ActionChip(avatar: const Icon(Icons.queue_music_rounded, size: 18), label: const Text('Add to queue'),
            onPressed: picked.isEmpty ? null : () { final l = picked; _exitSel(); addMany(l); }),
        ActionChip(avatar: const Icon(Icons.playlist_add_rounded, size: 18), label: const Text('Playlist'),
            onPressed: picked.isEmpty ? null : () { final l = picked; _exitSel(); pickPlaylistMany(context, l); }),
      ]),
    ]));
  }
  Widget onlineBody(BuildContext c) => ValueListenableBuilder<List<Track>>(valueListenable: onlineTracks, builder: (_, all, __) {
        final link = repoLink.value;
        if (link == null) {
          return Center(key: const ValueKey('on'), child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_outlined, size: 64, color: th.ac), const SizedBox(height: 12),
            const Text('Stream from your repo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
            const Text('Connect a public GitHub repo with your songs and play them online.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => repoDialog(c), icon: const Icon(Icons.link_rounded), label: const Text('Connect repo')),
          ])));
        }
        final f = [for (final t in all) if ('${t.title} ${t.artist} ${t.album}'.toLowerCase().contains(q.toLowerCase())) t];
        return ListView.builder(key: const ValueKey('on'), itemCount: f.length + 1, itemBuilder: (_, i) {
          if (i == 0) {
            return ListTile(leading: Icon(Icons.cloud_done_outlined, color: th.ac), title: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${all.length} songs · tap to change'),
                trailing: ValueListenableBuilder<bool>(valueListenable: onlineBusy, builder: (_, busy, __) => busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => connectRepo(link))),
                onTap: () => repoDialog(c));
          }
          return tile(f, i - 1, null);
        });
      });
  List<Track> get list {
    final l = lib.tracks.where((t) => (tab != 3 || lib.favs.contains(t.path)) &&
        '${t.title} ${t.artist} ${t.album} ${t.fmt}'.toLowerCase().contains(q.toLowerCase())).toList();
    String k(Track t) => (sort == 'artist' ? t.artist : sort == 'album' ? t.album : t.title).toLowerCase();
    l.sort((a, b) => sort == 'size' ? b.size.compareTo(a.size) : sort == 'added' ? b.added.compareTo(a.added) : k(a).compareTo(k(b)));
    return l;
  }
  Widget songOfDay(BuildContext c) {
    if (lib.tracks.isEmpty) return const SizedBox.shrink();
    final n = DateTime.now();
    final t = lib.tracks[seedOf('${n.year}-${n.month}-${n.day}') % lib.tracks.length];
    return ListTile(leading: Art(t, 48, 12),
        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('Song of the day · ${t.artist}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.wb_sunny_rounded, color: th.ac), onTap: () => playList([t], 0));
  }
  Widget playlistsBody(BuildContext c) {
    final most = (lib.plays.entries.where((e) => lib.byPath[e.key] != null).toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(25).map((e) => lib.byPath[e.key]!).toList();
    return ListView(key: const ValueKey('pl'), children: [
      ListTile(leading: CircleAvatar(backgroundColor: th.ac, child: const Icon(Icons.add, color: Colors.white)), title: const Text('New playlist'),
          onTap: () async { final n = await askName(c, ''); if (n != null) lib.newPlaylist(n); }),
      songOfDay(c),
      ValueListenableBuilder<List<String>>(valueListenable: recents, builder: (_, r, __) {
        final rt = [for (final p in r) if (lib.byPath[p] != null) lib.byPath[p]!];
        if (rt.isEmpty) return const SizedBox.shrink();
        return ExpansionTile(leading: const Icon(Icons.history_rounded), title: const Text('Recently played'),
            subtitle: Text('${rt.length} songs'), shape: const Border(), collapsedShape: const Border(),
            children: [for (int i = 0; i < rt.length; i++) tile(rt, i, null)]);
      }),
      if (most.isNotEmpty) ExpansionTile(leading: const Icon(Icons.local_fire_department_rounded), title: const Text('Most played'),
          subtitle: Text('${most.length} songs'), shape: const Border(), collapsedShape: const Border(),
          children: [for (int i = 0; i < most.length; i++) tile(most, i, null)]),
      for (final n in lib.playlists.keys.toList()) _plTile(c, n),
      if (lib.playlists.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Make your first playlist. Long-press any song to add it.', textAlign: TextAlign.center)),
    ]);
  }
  Widget _plTile(BuildContext c, String n) {
    final l = lib.plTracks(n);
    return ExpansionTile(key: PageStorageKey(n), leading: const Icon(Icons.queue_music_rounded), title: Text(n), subtitle: Text('${l.length} songs'),
        shape: const Border(), collapsedShape: const Border(),
        trailing: PopupMenuButton<String>(onSelected: (v) async {
          if (v == 'play' && l.isNotEmpty) playList(l, 0);
          if (v == 'shuffle' && l.isNotEmpty) { await playList(l, 0); await player.setShuffleModeEnabled(true); await player.shuffle(); }
          if (v == 'rename') { final x = await askName(c, n); if (x != null) lib.renamePlaylist(n, x); }
          if (v == 'delete') lib.delPlaylist(n);
        }, itemBuilder: (_) => const [PopupMenuItem(value: 'play', child: Text('Play')), PopupMenuItem(value: 'shuffle', child: Text('Shuffle')),
          PopupMenuItem(value: 'rename', child: Text('Rename')), PopupMenuItem(value: 'delete', child: Text('Delete'))]),
        children: [ReorderableListView(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), onReorder: (a, b) => lib.move(n, a, b), children: [
          for (int i = 0; i < l.length; i++) ListTile(key: ValueKey('$n${l[i].path}'), leading: Art(l[i], 44, 10),
              title: Text(l[i].title, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(l[i].artist, maxLines: 1),
              trailing: IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => lib.removeFrom(n, l[i].path)),
              onTap: () => playList(l, i))])]);
  }
  Widget tile(List<Track> src, int i, String? cur) {
    final t = src[i], on = t.path == cur;
    return ListTile(key: ValueKey(t.path), leading: Art(t, 48, 12),
        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, color: on ? th.ac : null)),
        subtitle: Text('${t.artist} · ${t.badge}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        trailing: selecting
            ? Checkbox(value: sel.contains(t.path), onChanged: (_) => _toggle(t.path))
            : IconButton(icon: Icon(lib.favs.contains(t.path) ? Icons.favorite : Icons.favorite_border, color: th.ac),
                onPressed: () { HapticFeedback.selectionClick(); lib.toggleFav(t); }),
        onTap: selecting ? () => _toggle(t.path) : () => playList(src, i),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          if (selecting) { _toggle(t.path); return; }
          trackSheet(context, t, onSelect: () => setState(() { selecting = true; if (!sel.contains(t.path)) sel.add(t.path); }));
        });
  }
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return ListenableBuilder(listenable: lib, builder: (c, _) {
      final l = list;
      Widget body;
      if (tab == 4) {
        body = playlistsBody(c);
      } else if (tab == 6) {
        body = onlineBody(c);
      } else if (l.isEmpty) {
        body = Center(key: const ValueKey('e'), child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.library_music_outlined, size: 64, color: th.ac), const SizedBox(height: 12),
          Text(lib.scanning ? 'Looking for music…' : tab == 3 ? 'No favorites yet' : 'No music yet', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(lib.msg ?? 'Cadence finds your music automatically once you allow access.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(spacing: 10, children: [
            FilledButton.icon(onPressed: lib.scan, icon: const Icon(Icons.refresh), label: const Text('Scan device')),
            OutlinedButton.icon(onPressed: Platform.isAndroid ? openAppSettings : lib.importFiles, icon: const Icon(Icons.settings), label: Text(Platform.isAndroid ? 'App permissions' : 'Add files')),
          ])])));
      } else if (tab == 0 || tab == 3) {
        body = StreamBuilder<SequenceState?>(key: ValueKey('s$tab'), stream: player.sequenceStateStream, builder: (_, s) {
          final cur = curTrack(s.data)?.path;
          return ListView.builder(itemCount: l.length, itemExtent: 68, itemBuilder: (_, i) => tile(l, i, cur));
        });
      } else {
        final g = <String, List<Track>>{};
        for (final t in l) { (g[tab == 1 ? t.album : tab == 5 ? folderName(t.path) : t.artist] ??= []).add(t); }
        final keys = g.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        body = ListView(key: ValueKey('g$tab'), children: [for (final k in keys) ExpansionTile(
            leading: Art(g[k]!.first, 48, tab == 2 ? 24 : 12), title: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${g[k]!.length} songs'), shape: const Border(), collapsedShape: const Border(),
            children: [for (int i = 0; i < g[k]!.length; i++) tile(g[k]!, i, null)])]);
      }
      return SafeArea(bottom: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (selecting) _selBar(c, tab == 6 ? onlineTracks.value : l) else Padding(padding: const EdgeInsets.fromLTRB(20, 8, 8, 0), child: Row(children: [
          const Expanded(child: Text('Cadence', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: 1))),
          lib.scanning
              ? Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: th.ac)))
              : IconButton(tooltip: 'Scan device', icon: const Icon(Icons.refresh_rounded), onPressed: lib.scan),
          if (!Platform.isAndroid) IconButton(tooltip: 'Add files', icon: const Icon(Icons.add_rounded), onPressed: lib.importFiles),
          IconButton(tooltip: 'Select songs', icon: const Icon(Icons.checklist_rounded), onPressed: () => setState(() => selecting = true)),
          PopupMenuButton<String>(icon: const Icon(Icons.sort_rounded), onSelected: (v) => setState(() => sort = v),
              itemBuilder: (_) => [for (final s in ['title', 'artist', 'album', 'size', 'added']) PopupMenuItem(value: s, child: Text('Sort by $s'))]),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 6), child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(hintText: 'Search songs, artists, albums', prefixIcon: const Icon(Icons.search), filled: true,
                fillColor: th.bg.withOpacity(.55), border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none)))),
        SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final e in ['Songs', 'Albums', 'Artists', 'Favorites', 'Playlists', 'Folders'].asMap().entries)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(e.value), selected: tab == e.key,
                onSelected: (_) { HapticFeedback.selectionClick(); setState(() => tab = e.key); }))])),
        if (lib.scanning) Padding(padding: const EdgeInsets.fromLTRB(20, 2, 20, 4), child: Text('Found ${lib.found} songs…', style: const TextStyle(fontSize: 12))),
        Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: body)),
      ]));
    });
  }
}

class VizBars extends StatefulWidget { const VizBars({super.key}); @override State<VizBars> createState() => _VB(); }
class _VB extends State<VizBars> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  double amp = 0;
  @override
  void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => SizedBox(height: 40, width: double.infinity, child: AnimatedBuilder(animation: c, builder: (_, __) {
        amp += ((player.playing ? 1.0 : .08) - amp) * .08;
        return CustomPaint(painter: _VizP(c.value * 20, amp, th.ac));
      }));
}
class _VizP extends CustomPainter {
  final double t, amp; final Color col;
  _VizP(this.t, this.amp, this.col);
  @override
  void paint(Canvas cv, Size sz) {
    const n = 32;
    final w = sz.width / n;
    final p = Paint()..color = col.withOpacity(.75)..strokeCap = StrokeCap.round..strokeWidth = w * .5;
    for (int i = 0; i < n; i++) {
      final v = (m.sin(t * 3.1 + i * .55) + m.sin(t * 5.3 + i * 1.3) * .6 + m.sin(t * 1.7 + i * .21) * .4) / 2;
      final hh = m.max(3.0, (4 + v.abs() * (sz.height - 6)) * amp);
      final x = i * w + w / 2;
      cv.drawLine(Offset(x, sz.height / 2 - hh / 2), Offset(x, sz.height / 2 + hh / 2), p);
    }
  }
  @override
  bool shouldRepaint(covariant _VizP o) => true;
}

class WavePainter extends CustomPainter {
  final double p, ph, amp; final Color ac, ac2, tr; final bool drag;
  WavePainter(this.p, this.ph, this.amp, this.ac, this.ac2, this.tr, this.drag);
  @override
  void paint(Canvas c, Size s) {
    final mid = s.height - 16, x0 = 14.0, x1 = s.width - 14, x = x0 + p * (x1 - x0);
    final st = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    c.drawLine(Offset(x0, mid), Offset(x1, mid), st..strokeWidth = 6..color = tr.withOpacity(.3));
    for (final w in [[ac, .6, 9.0, 1.0, 26.0], [const Color(0xFF3F74B5), .55, 12.0, -.7, 22.0], [ac2, .5, 7.0, 1.5, 16.0]]) {
      final path = Path(); bool f = true;
      for (double i = x0; i <= x; i += 3) {
        final env = m.sin(m.pi * (i - x0) / m.max(1, x - x0)), v = .5 + .5 * m.sin(i / (w[2] as double) - ph * (w[3] as double) * 3);
        final y = mid - (w[4] as double) * amp * env * v * v;
        if (f) { path.moveTo(i, y); f = false; } else { path.lineTo(i, y); }
      }
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = (w[0] as Color).withOpacity(w[1] as double));
    }
    c.drawLine(Offset(x0, mid), Offset(x, mid), Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = 7
      ..shader = LinearGradient(colors: [ac2, ac]).createShader(Rect.fromLTRB(x0, 0, m.max(x, x0 + 1), 1)));
    c.drawCircle(Offset(x, mid), drag ? 25 : 20, Paint()..color = ac.withOpacity(.25));
    c.drawCircle(Offset(x, mid), drag ? 15 : 13, Paint()..color = ac);
    c.drawCircle(Offset(x, mid), drag ? 15 : 13, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white70);
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => true;
}

class WaveSeek extends StatefulWidget { const WaveSeek({super.key}); @override State<WaveSeek> createState() => _WS(); }
class _WS extends State<WaveSeek> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  double amp = 0, ph = 0, drag = -1;
  @override
  void dispose() { c.dispose(); super.dispose(); }
  double _f(double w, double dx) => ((dx - 14) / (w - 28)).clamp(0.0, 1.0);
  void _end() { final d = player.duration; if (d != null && drag >= 0) player.seek(d * drag); setState(() => drag = -1); }
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final calm = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(builder: (_, bc) {
      final w = bc.maxWidth;
      return GestureDetector(behavior: HitTestBehavior.opaque,
          onTapDown: (d) => setState(() => drag = _f(w, d.localPosition.dx)), onTapUp: (_) => _end(),
          onHorizontalDragStart: (d) => setState(() => drag = _f(w, d.localPosition.dx)),
          onHorizontalDragUpdate: (d) => setState(() => drag = _f(w, d.localPosition.dx)),
          onHorizontalDragEnd: (_) => _end(), onTapCancel: () => setState(() => drag = -1),
          child: AnimatedBuilder(animation: c, builder: (_, __) {
            final d = player.duration?.inMilliseconds ?? 0, pos = player.position.inMilliseconds;
            final f = drag >= 0 ? drag : (d > 0 ? (pos / d).clamp(0.0, 1.0) : 0.0);
            amp += (((player.playing && !calm) ? 1 : 0) - amp) * .08; ph += .045;
            final shown = Duration(milliseconds: (f * d).round());
            return Column(children: [
              CustomPaint(size: Size(w, 66), painter: WavePainter(f, ph, amp, th.ac, Color.lerp(th.ac, th.bg2, .5)!, th.tx, drag >= 0)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(fmt(shown), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text('\u2212${fmt(Duration(milliseconds: d) - shown)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))])),
            ]);
          }));
    });
  }
}

class _Glass extends StatelessWidget {
  final IconData i; final VoidCallback f;
  const _Glass(this.i, this.f);
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(left: 8), child: Material(
      color: th.bg.withOpacity(.5), shape: const CircleBorder(side: BorderSide(color: Colors.white54)),
      child: InkWell(customBorder: const CircleBorder(), onTap: f, child: SizedBox(width: 48, height: 48, child: Icon(i, color: th.ac)))));
}

class NowPlaying extends StatelessWidget {
  const NowPlaying({super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    return StreamBuilder<SequenceState?>(stream: player.sequenceStateStream, builder: (c, s) {
      final t = curTrack(s.data);
      return GestureDetector(
          onVerticalDragEnd: (d) { if ((d.primaryVelocity ?? 0) > 400) Navigator.pop(c); },
          child: Scaffold(body: Stack(children: [
            Positioned.fill(child: AnimatedSwitcher(duration: const Duration(milliseconds: 700),
                child: t?.art != null
                    ? Stack(key: ValueKey(t!.path), fit: StackFit.expand, children: [
                        ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                            child: Image.file(File(t.art!), fit: BoxFit.cover, cacheWidth: 120)),
                        Container(color: th.bg.withOpacity(.68))])
                    : const SizedBox.shrink())),
            SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: Column(children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32), onPressed: () => Navigator.pop(c)),
                const Expanded(child: Center(child: Text('NOW PLAYING', style: TextStyle(letterSpacing: 3, fontSize: 12)))),
                IconButton(icon: const Icon(Icons.more_horiz_rounded), onPressed: t == null ? null : () => moreSheet(c, t)),
              ]),
              const Spacer(),
              StreamBuilder<bool>(stream: player.playingStream, builder: (_, p) => AnimatedScale(
                  scale: (p.data ?? false) ? 1 : .9, duration: const Duration(milliseconds: 500), curve: Curves.easeOutBack,
                  child: Hero(tag: 'art', child: BigArt(t, m.min(MediaQuery.sizeOf(c).width - 70, 320))))),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Column(
                    key: ValueKey(t?.path), crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t?.title ?? 'Nothing playing', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                  Text(t?.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, color: th.tx.withOpacity(.65))),
                ]))),
                if (t != null) ListenableBuilder(listenable: lib, builder: (_, __) =>
                    _Glass(lib.favs.contains(t.path) ? Icons.favorite : Icons.favorite_border, () { HapticFeedback.selectionClick(); lib.toggleFav(t); })),
                if (t != null) _Glass(Icons.blur_on_rounded, () => openPortal(c)),
                if (t != null) _Glass(Icons.science_rounded, () => openDna(c)),
                if (t != null) _Glass(Icons.lyrics_rounded, () => Navigator.push(c, slideUp(const LyricsPage()))),
                if (t != null) _Glass(Icons.graphic_eq_rounded, () => infoSheet(c, t)),
              ]),
              if (t != null) Align(alignment: Alignment.centerLeft, child: Container(
                  margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(border: Border.all(color: th.tx.withOpacity(.4)), borderRadius: BorderRadius.circular(20)),
                  child: Text(t.badge, style: const TextStyle(fontSize: 12)))),
              if (t != null) LyricPeek(t, key: ValueKey(t.path)),
              const Spacer(),
              ValueListenableBuilder<bool>(valueListenable: vizOn, builder: (_, on, __) => on
                  ? const Padding(padding: EdgeInsets.only(bottom: 8), child: VizBars()) : const SizedBox.shrink()),
              const WaveSeek(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                StreamBuilder<bool>(stream: player.shuffleModeEnabledStream, builder: (_, s) => IconButton(
                    icon: Icon(Icons.shuffle_rounded, color: (s.data ?? false) ? th.ac : null),
                    onPressed: () async { final on = !(s.data ?? false); await player.setShuffleModeEnabled(on); if (on) await player.shuffle(); })),
                IconButton(iconSize: 38, icon: const Icon(Icons.skip_previous_rounded), onPressed: player.seekToPrevious),
                const PlayBtn(72),
                IconButton(iconSize: 38, icon: const Icon(Icons.skip_next_rounded), onPressed: skipNext),
                StreamBuilder<LoopMode>(stream: player.loopModeStream, builder: (_, s) {
                  final lm = s.data ?? LoopMode.off;
                  return IconButton(icon: Icon(lm == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, color: lm == LoopMode.off ? null : th.ac),
                      onPressed: () => player.setLoopMode(LoopMode.values[(lm.index + 1) % 3]));
                }),
              ]),
              ValueListenableBuilder<bool>(valueListenable: showSig, builder: (_, on, __) => on
                  ? Padding(padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: ListenableBuilder(listenable: Listenable.merge([sigText, sigFont, sigSize]), builder: (_, __) => Text(sigText.value, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: sigStyle(sigFont.value, sigSize.value, th.tx.withOpacity(.55)))))
                  : const SizedBox(height: 10)),
            ]))),
          ])));
    });
  }
}

void _sheet(BuildContext c, Widget w) => showModalBottomSheet(context: c, showDragHandle: true, isScrollControlled: true,
    backgroundColor: th.bg, builder: (_) => Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 28), child: w));

void moreSheet(BuildContext c, Track t) => _sheet(c, Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.celebration_rounded), title: const Text('Music Party'), subtitle: const Text('Play in sync with friends'), onTap: () { Navigator.pop(c); Navigator.push(c, MaterialPageRoute(builder: (_) => const PartyPage())); }),
      ListTile(leading: const Icon(Icons.science_rounded), title: const Text('Sound DNA Lab'), subtitle: const Text('Sculpt the sound in 3D'), onTap: () { Navigator.pop(c); openDna(c); }),
      ListTile(leading: const Icon(Icons.blur_on_rounded), title: const Text('Live Sonic Portal'), subtitle: const Text('Music in 3D, reacting to the real audio'), onTap: () { Navigator.pop(c); openPortal(c); }),
      ListTile(leading: const Icon(Icons.lyrics_rounded), title: const Text('Lyrics'), onTap: () { Navigator.pop(c); Navigator.push(c, slideUp(const LyricsPage())); }),
      ListTile(leading: const Icon(Icons.info_outline), title: const Text('Audio information'), onTap: () { Navigator.pop(c); infoSheet(c, t); }),
      ListTile(leading: const Icon(Icons.hourglass_bottom_rounded), title: const Text('Time capsule'), subtitle: const Text('Hide this song with a note for later'), onTap: () { Navigator.pop(c); capsuleSheet(c, t); }),
      ListTile(leading: const Icon(Icons.playlist_add_rounded), title: const Text('Add to playlist'), onTap: () { Navigator.pop(c); pickPlaylist(c, t); }),
      ListTile(leading: const Icon(Icons.bedtime_outlined), title: const Text('Sleep timer'), onTap: () {
        Navigator.pop(c);
        _sheet(c, Wrap(spacing: 8, children: [for (final v in [0, -1, 5, 15, 30, 45, 60]) ActionChip(label: Text(v == 0 ? 'Off' : v == -1 ? 'End of song' : '$v min'), onPressed: () { sleepIn(v); Navigator.pop(c); }),
        ActionChip(avatar: const Icon(Icons.edit_rounded, size: 16), label: const Text('Custom'), onPressed: () async {
          Navigator.pop(c);
          final r = await askText(c, 'Sleep after how many minutes?', '20', number: true);
          final n = int.tryParse((r ?? '').trim());
          if (n != null && n > 0 && n <= 1440) { sleepIn(n); } else if (r != null) { snack('Enter minutes from 1 to 1440'); }
        })]));
      }),
      ListTile(leading: const Icon(Icons.speed_rounded), title: const Text('Playback speed'), onTap: () {
        Navigator.pop(c);
        _sheet(c, Wrap(spacing: 8, children: [for (final v in [.5, .75, 1.0, 1.25, 1.5, 1.75, 2.0]) ActionChip(label: Text('${v}x'), onPressed: () { player.setSpeed(v); Navigator.pop(c); })]));
      }),
    ]));

void infoSheet(BuildContext c, Track t) {
  final rows = [
    ['Format', t.fmt], ['Codec', t.codec ?? 'Unknown'],
    ['Sample rate', t.sr > 0 ? '${t.sr} Hz' : 'Unknown'], ['Bit depth', t.bd > 0 ? '${t.bd}-bit' : 'Unknown'],
    ['Channels', t.ch > 0 ? (t.ch == 1 ? 'Mono' : t.ch == 2 ? 'Stereo' : '${t.ch}') : 'Unknown'],
    ['Bitrate', t.dur > 0 ? '${(t.size * 8 / t.dur).round()} kbps (file average)' : 'Unknown'],
    ['Encoding', t.lossless == true ? 'Lossless' : t.lossless == false ? 'Lossy' : 'Unknown'],
    ['File size', '${(t.size / 1048576).toStringAsFixed(2)} MB'],
  ];
  _sheet(c, Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Audio information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)), const SizedBox(height: 10),
    for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(r[0], style: TextStyle(color: th.tx.withOpacity(.6))), Text(r[1])])),
    const SizedBox(height: 10),
    Text('Source values come from the file header; "Unknown" means it could not be read. Output quality is not verified: your phone mixer, DAC and Bluetooth codec decide it, so Cadence never claims bit-perfect output.',
        style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.6))),
  ]));
}

void pickPlaylistMany(BuildContext c, List<Track> l) {
  final local = [for (final t in l) if (lib.byPath[t.path] != null) t];
  if (local.isEmpty) { snack('Online songs cannot be added to playlists yet.'); return; }
  _sheet(c, Column(mainAxisSize: MainAxisSize.min, children: [
    ListTile(leading: const Icon(Icons.add), title: const Text('New playlist'), onTap: () async {
      Navigator.pop(c);
      final n = await askName(c, '');
      if (n != null && n.trim().isNotEmpty) {
        await lib.newPlaylist(n);
        for (final t in local) { await lib.addTo(n.trim(), t.path); }
        snack('Added ${local.length} songs to ${n.trim()}');
      }
    }),
    for (final n in lib.playlists.keys.toList()) ListTile(leading: const Icon(Icons.queue_music), title: Text(n), onTap: () async {
      Navigator.pop(c);
      for (final t in local) { await lib.addTo(n, t.path); }
      snack('Added ${local.length} songs to $n');
    }),
  ]));
}

void trackSheet(BuildContext c, Track t, {VoidCallback? onSelect}) => _sheet(c, Column(mainAxisSize: MainAxisSize.min, children: [
      if (onSelect != null) ListTile(leading: const Icon(Icons.checklist_rounded), title: const Text('Select'), onTap: () { Navigator.pop(c); onSelect(); }),
      ListTile(leading: const Icon(Icons.queue_play_next_rounded), title: const Text('Play next'), onTap: () { Navigator.pop(c); playNext(t); }),
      ListTile(leading: const Icon(Icons.queue_music_rounded), title: const Text('Add to queue'), onTap: () { Navigator.pop(c); addToQueue(t); }),
      ListTile(leading: const Icon(Icons.playlist_add_rounded), title: const Text('Add to playlist'), onTap: () { Navigator.pop(c); pickPlaylist(c, t); }),
      ListTile(leading: const Icon(Icons.info_outline), title: const Text('Audio information'), onTap: () { Navigator.pop(c); infoSheet(c, t); }),
    ]));

void pickPlaylist(BuildContext c, Track t) => _sheet(c, Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.add), title: const Text('New playlist'), onTap: () async {
        Navigator.pop(c);
        final n = await askName(c, '');
        if (n != null && n.trim().isNotEmpty) { await lib.newPlaylist(n); await lib.addTo(n.trim(), t.path); snack('Added to ${n.trim()}'); }
      }),
      for (final n in lib.playlists.keys) ListTile(leading: const Icon(Icons.queue_music), title: Text(n), onTap: () { lib.addTo(n, t.path); Navigator.pop(c); snack('Added to $n'); }),
    ]));

Future<String?> askName(BuildContext c, String init) {
  final tc = TextEditingController(text: init);
  return showDialog<String>(context: c, builder: (d) => AlertDialog(title: const Text('Playlist name'), content: TextField(controller: tc, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, tc.text), child: const Text('Save'))]));
}

class AuroraPainter extends CustomPainter {
  final int seed; final double ph; final Color base;
  AuroraPainter(this.seed, this.ph, this.base);
  @override
  void paint(Canvas c, Size s) {
    final hsl = HSLColor.fromColor(base);
    for (int i = 0; i < 4; i++) {
      final hue = (hsl.hue + (seed >> (i * 3)) % 90 - 30 + 360) % 360;
      final col = hsl.withHue(hue).withSaturation(m.min(1.0, hsl.saturation * .9 + .1)).withLightness(.55 + i * .05).toColor();
      final a = ph * (.35 + i * .12) + seed % 13 + i * 1.7;
      final p = Offset(s.width * (.5 + .28 * m.cos(a)), s.height * (.5 + .28 * m.sin(a * .8 + i)));
      final r = s.shortestSide * (.42 - i * .04);
      c.drawCircle(p, r, Paint()..shader = RadialGradient(colors: [col.withOpacity(.55), col.withOpacity(0)]).createShader(Rect.fromCircle(center: p, radius: r)));
    }
    final ctr = s.center(Offset.zero);
    c.drawCircle(ctr, s.shortestSide * .26, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white.withOpacity(.25));
    c.drawCircle(ctr, s.shortestSide * .08 * (1 + .1 * m.sin(ph * 2)), Paint()..color = Colors.white.withOpacity(.85));
  }
  @override
  bool shouldRepaint(covariant AuroraPainter o) => o.ph != ph || o.seed != seed || o.base != base;
}

// The big Now Playing card: real album art, or a slow moving aurora made from the song. Tap to flip.
class BigArt extends StatefulWidget { final Track? t; final double s; const BigArt(this.t, this.s, {super.key}); @override State<BigArt> createState() => _BA(); }
class _BA extends State<BigArt> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  double ph = 0; bool? flip;
  @override
  void dispose() { c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final t = widget.t, s = widget.s, hasArt = t?.art != null, bloom = flip ?? !hasArt;
    return ListenableBuilder(listenable: lib, builder: (_, __) {
      final plays = t == null ? 0 : (lib.plays[t.path] ?? 0);
      return GestureDetector(
          onTap: hasArt ? () { HapticFeedback.selectionClick(); setState(() => flip = !bloom); } : null,
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 500), switchInCurve: Curves.easeOutBack,
              transitionBuilder: (w, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: w)),
              child: bloom
                  ? ClipRRect(key: const ValueKey('b'), borderRadius: BorderRadius.circular(28), child: SizedBox(width: s, height: s, child: Stack(children: [
                      Container(decoration: BoxDecoration(gradient: RadialGradient(colors: [th.bg, Color.lerp(th.bg, th.bg2, .8)!]))),
                      AnimatedBuilder(animation: c, builder: (_, __) {
                        if (player.playing) ph += .04;
                        return CustomPaint(size: Size(s, s), painter: AuroraPainter(seedOf(t?.path ?? 'cadence'), ph, th.ac));
                      }),
                      Positioned(left: 0, right: 0, bottom: 14, child: Center(child: Text('$plays plays',
                          style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: th.tx.withOpacity(.7))))),
                    ])))
                  : KeyedSubtree(key: const ValueKey('a'), child: Art(t, s, 28))));
    });
  }
}

const _freq = [31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0];
const _presets = {
  'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 'Bass Boost': [5, 4, 3, 1, 0, 0, 0, 0, 0, 0], 'Deep Bass': [7, 6, 4, 2, 0, -1, 0, 0, 0, 0],
  'Rock': [4, 3, 1, -1, -1, 1, 3, 4, 4, 4], 'Metal': [4, 3, 0, 0, -2, 0, 2, 4, 3, 2], 'Electronic': [4, 3, 0, -2, -1, 1, 0, 2, 4, 4],
  'Acoustic': [3, 3, 2, 1, 2, 2, 3, 3, 2, 1], 'Vocal': [-2, -2, -1, 2, 4, 4, 3, 1, 0, -1], 'Classical': [0, 0, 0, 0, 0, 0, -2, -2, -2, -3],
  'Jazz': [3, 2, 1, 2, -1, -1, 0, 1, 2, 3],
};

class EqPage extends StatefulWidget { const EqPage({super.key}); @override State<EqPage> createState() => _EqS(); }
class _EqS extends State<EqPage> {
  AndroidEqualizerParameters? ps; bool on = false; double boost = 0;
  @override
  void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    if (!Platform.isAndroid || player.audioSource == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      ps = await eq.parameters; on = eq.enabled; boost = p.getDouble('loud') ?? 0;
      if (mounted) setState(() {});
    } catch (_) {}
  }
  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('eqon', on); await p.setDouble('loud', boost);
    await p.setStringList('eqg', ps!.bands.map((b) => b.gain.toString()).toList());
  }
  void _preset(List<int> g) {
    for (final b in ps!.bands) {
      int k = 0; double best = 1e9;
      for (int i = 0; i < _freq.length; i++) { final d = (m.log(b.centerFrequency) - m.log(_freq[i])).abs(); if (d < best) { best = d; k = i; } }
      b.setGain(g[k].toDouble().clamp(ps!.minDecibels, ps!.maxDecibels));
    }
    _save(); setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    Widget body;
    if (!Platform.isAndroid) {
      body = const Text('The system equalizer API exists only on Android, so iOS has no equalizer in this version. Nothing here is faked.');
    } else if (ps == null) {
      body = Column(children: [
        const Text('Start playing a song first, then open this page. Android attaches the equalizer to the active audio session.'),
        TextButton(onPressed: _init, child: const Text('Reload')),
      ]);
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(title: const Text('Equalizer'), value: on, onChanged: (v) { setState(() => on = v); eq.setEnabled(v); _save(); }),
        Wrap(spacing: 8, children: [for (final e in _presets.entries) ActionChip(label: Text(e.key), onPressed: () => _preset(e.value))]),
        const SizedBox(height: 12),
        SizedBox(height: 230, child: Row(children: [for (final b in ps!.bands) Expanded(child: StreamBuilder<double>(
            stream: b.gainStream, initialData: b.gain, builder: (_, s) => Column(children: [
              Text('${(s.data ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
              Expanded(child: RotatedBox(quarterTurns: 3, child: Slider(value: (s.data ?? 0).clamp(ps!.minDecibels, ps!.maxDecibels),
                  min: ps!.minDecibels, max: ps!.maxDecibels, onChanged: on ? (v) => b.setGain(v) : null, onChangeEnd: (_) => _save()))),
              Text(b.centerFrequency >= 1000 ? '${(b.centerFrequency / 1000).toStringAsFixed(b.centerFrequency % 1000 == 0 ? 0 : 1)}k' : b.centerFrequency.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10)),
            ])))])),
        const SizedBox(height: 8),
        Text('Loudness boost: ${boost.toStringAsFixed(0)} dB'),
        Slider(value: boost, min: 0, max: 12, divisions: 12, onChanged: (v) { setState(() => boost = v); loud.setTargetGain(v); loud.setEnabled(v > 0); }, onChangeEnd: (_) => _save()),
        if (boost > 6) Text('High boost can distort. Lower it if you hear crackle.', style: TextStyle(color: Colors.orange.shade800)),
      ]);
    }
    return SafeArea(bottom: false, child: ListView(padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.paddingOf(context).bottom), children: [
      const Text('Equalizer', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300)), const SizedBox(height: 12), body]));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    return SafeArea(bottom: false, child: ListView(padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.paddingOf(c).bottom), children: [
      const Text('Settings', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300)), const SizedBox(height: 16),
      const Text('Looks', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 4),
      Text('One tap sets theme, card style and effect together', style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.6))),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in looks) ActionChip(
            avatar: CircleAvatar(radius: 7, backgroundColor: themes[l[1] as int].ac),
            label: Text(l[0] as String),
            onPressed: () { HapticFeedback.selectionClick(); applyLook(l[1] as int, l[2] as int, l[3] as int); })]),
      const SizedBox(height: 18),
      const Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [for (int i = 0; i < themes.length; i++) GestureDetector(
          onTap: () async { autoTheme.value = false; themeIx.value = i; HapticFeedback.selectionClick(); final sp = await SharedPreferences.getInstance(); await sp.setInt('theme', i); await sp.setBool('auto', false); },
          child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: themes[i].bg, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: themeIx.value == i ? themes[i].ac : Colors.black12, width: 2)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(radius: 7, backgroundColor: themes[i].ac), const SizedBox(width: 8),
                Text(themes[i].n, style: TextStyle(color: themes[i].tx))])))]),
      const SizedBox(height: 12),
      ValueListenableBuilder<bool>(valueListenable: autoTheme, builder: (_, on, __) => SwitchListTile(
          secondary: const Icon(Icons.wb_twilight_rounded), title: const Text('Theme by time of day'),
          subtitle: const Text('Mist in the morning, deep blue at night'), value: on,
          onChanged: (v) async { autoTheme.value = v; (await SharedPreferences.getInstance()).setBool('auto', v); applyAutoTheme(); })),
      ValueListenableBuilder<bool>(valueListenable: showSig, builder: (_, on, __) => SwitchListTile(
          secondary: const Icon(Icons.draw_outlined), title: const Text('Show signature'),
          subtitle: const Text('Your name in script on the player'), value: on,
          onChanged: (v) async { showSig.value = v; HapticFeedback.selectionClick(); (await SharedPreferences.getInstance()).setBool('sig', v); })),
      _sw(glassSkin, 'glass', Icons.blur_on_rounded, 'Liquid glass skin', 'Floating glass player and tab bar'),
      ValueListenableBuilder<int>(valueListenable: skin, builder: (_, v, __) => ListTile(
          leading: const Icon(Icons.style_rounded), title: const Text('Card style'),
          subtitle: Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 8, runSpacing: 6, children: [
            for (int i = 0; i < skinNames.length; i++) ChoiceChip(label: Text(skinNames[i]), selected: v == i,
                onSelected: (_) async { skin.value = i; HapticFeedback.selectionClick(); (await SharedPreferences.getInstance()).setInt('skin', i); })]))),
      ),
      ValueListenableBuilder<int>(valueListenable: fx, builder: (_, v, __) => ListTile(
          leading: const Icon(Icons.auto_awesome_rounded), title: const Text('Ambient effect'),
          subtitle: Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 8, runSpacing: 6, children: [
            for (int i = 0; i < fxNames.length; i++) ChoiceChip(label: Text(fxNames[i]), selected: v == i,
                onSelected: (_) async { fx.value = i; HapticFeedback.selectionClick(); (await SharedPreferences.getInstance()).setInt('fx', i); })]))),
      ),
      ValueListenableBuilder<String?>(valueListenable: wallpaperPath, builder: (_, p, __) => Column(children: [
        ListTile(leading: const Icon(Icons.wallpaper_rounded), title: const Text('Custom wallpaper'),
            subtitle: Text(p == null ? 'Use any picture from your gallery, like an anime or movie wallpaper' : 'Tap to change'),
            trailing: p == null ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: clearWallpaper),
            onTap: pickWallpaper),
        if (p != null) _sw(matchWall, 'matchWall', Icons.palette_rounded, 'Match colors to wallpaper', 'Theme colors follow your picture', updateWallAccent),
        if (p != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          const Text('Dim'),
          Expanded(child: ValueListenableBuilder<double>(valueListenable: wallDim, builder: (_, v, __) => Slider(min: 0, max: .9, value: v,
              onChanged: (x) => wallDim.value = x,
              onChangeEnd: (x) async { (await SharedPreferences.getInstance()).setDouble('wallDim', x); }))),
        ])),
      ])),
      _sw(adaptiveColors, 'adaptive', Icons.palette_outlined, 'Colors from album art', 'The accent color follows the cover of the song playing', updateArtAccent),
      _sw(vizOn, 'viz', Icons.equalizer_rounded, 'Visualizer', 'Moving bars on the player while music plays'),
      ListenableBuilder(listenable: Listenable.merge([sigText, sigFont, sigSize]), builder: (ctx, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Signature text'), subtitle: Text(sigText.value),
            onTap: () async {
              final n = await askText(ctx, 'Signature text', sigText.value);
              if (n != null && n.trim().isNotEmpty) { sigText.value = n.trim(); (await SharedPreferences.getInstance()).setString('sigText', n.trim()); }
            }),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(spacing: 8, runSpacing: 6, children: [
          for (int i = 0; i < sigFontNames.length; i++) ChoiceChip(
              label: Text(sigFontNames[i], style: sigStyle(i, 16, th.tx)), selected: sigFont.value == i,
              onSelected: (_) async { sigFont.value = i; (await SharedPreferences.getInstance()).setInt('sigFont', i); })])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Row(children: [
          const Text('Size'),
          Expanded(child: Slider(min: 14, max: 40, value: sigSize.value, onChanged: (v) => sigSize.value = v,
              onChangeEnd: (v) async { (await SharedPreferences.getInstance()).setDouble('sigSize', v); }))])),
        Center(child: Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Text(sigText.value, style: sigStyle(sigFont.value, sigSize.value, th.tx.withOpacity(.7))))),
      ])),
      ListTile(leading: const Icon(Icons.celebration_rounded), title: const Text('Music Party'),
          subtitle: const Text('Play the same song in sync with friends'),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const PartyPage()))),
      ListTile(leading: const Icon(Icons.sync_rounded), title: const Text('YouTube & Sync'),
          subtitle: const Text('Import your YouTube playlists and share your listening history'),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const YouTubeSyncPage()))),
      ListTile(leading: const Icon(Icons.hub_rounded), title: const Text('Music providers'),
          subtitle: const Text('Audius, Jamendo, Internet Archive and your own repo'),
          onTap: () => providerSheet(c)),
      ListTile(leading: const Icon(Icons.cloud_outlined), title: const Text('Online library (GitHub)'),
          subtitle: ValueListenableBuilder<String?>(valueListenable: repoLink, builder: (_, v, __) => Text(v ?? 'Stream songs from your own repo')),
          onTap: () => repoDialog(c)),
      ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('Back up to clipboard'),
          subtitle: const Text('Playlists, favorites, play counts and signature'), onTap: backupToClipboard),
      ListTile(leading: const Icon(Icons.restore_rounded), title: const Text('Restore from clipboard'),
          subtitle: const Text('Copy a Cadence backup first, then tap here'), onTap: restoreFromClipboard),
      ListTile(leading: const Icon(Icons.menu_book_rounded), title: const Text('Listening diary'),
          subtitle: const Text('A line for every day you listened'),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const DiaryPage()))),
      ListTile(leading: const Icon(Icons.insights_rounded), title: const Text('Listening stats'),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const StatsPage()))),
      ListTile(leading: const Icon(Icons.refresh_rounded), title: const Text('Rescan device for music'), onTap: lib.scan),
      if (!Platform.isAndroid) ListTile(leading: const Icon(Icons.add_rounded), title: const Text('Add music files'), onTap: lib.importFiles),
      const Divider(),
      const ListTile(leading: Icon(Icons.info_outline), title: Text('Cadence — Deep, Blue and Mist'), subtitle: Text('By TanimSarker. A native music player for Android and iOS.')),
      Padding(padding: const EdgeInsets.all(16), child: Text(
          'Android scans your storage automatically. iOS does not allow that, so use Add music files or put files in the Cadence folder in the Files app. The equalizer works on Android only.',
          style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.6)))),
    ]));
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    final played = lib.plays.entries.where((e) => lib.byPath[e.key] != null).toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = played.fold<int>(0, (a, e) => a + e.value);
    final ms = played.fold<int>(0, (a, e) => a + e.value * lib.byPath[e.key]!.dur);
    final byArtist = <String, int>{};
    for (final e in played) { final a = lib.byPath[e.key]!.artist; byArtist[a] = (byArtist[a] ?? 0) + e.value; }
    final artists = byArtist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final time = ms < 3600000 ? '${(ms / 60000).round()} min' : '${(ms / 3600000).toStringAsFixed(1)} h';
    Widget card(String k, String v) => Expanded(child: Container(
        margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: th.ac.withOpacity(.12), borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(k, style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.65)))])));
    return Scaffold(
      appBar: AppBar(title: const Text('Listening stats')),
      body: played.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Play some songs and your stats will show up here.', textAlign: TextAlign.center)))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [card('plays', '$total'), card('songs', '${played.length}'), card('listened', time)]),
              const SizedBox(height: 18),
              const Text('Top songs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              for (final e in played.take(10)) ListTile(
                  leading: Art(lib.byPath[e.key]!, 44, 10),
                  title: Text(lib.byPath[e.key]!.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(lib.byPath[e.key]!.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text('${e.value}x')),
              const SizedBox(height: 12),
              const Text('Top artists', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              for (final e in artists.take(8)) ListTile(
                  leading: const Icon(Icons.person_outline_rounded), title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text('${e.value}x')),
            ]),
    );
  }
}

// ---------------- Lyrics ----------------
class LrcLine { final Duration t; final String s; const LrcLine(this.t, this.s); }
class Lyrics { final List<LrcLine> lines; final bool synced; const Lyrics(this.lines, this.synced); }
final lyricMem = <String, Lyrics?>{};

Lyrics? parseLyrics(String txt) {
  final re = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  final meta = RegExp(r'^\[[a-zA-Z]+:.*\]$');
  final out = <LrcLine>[], plain = <LrcLine>[];
  for (final raw in txt.split(RegExp(r'\r?\n'))) {
    final ms = re.allMatches(raw).toList();
    final text = raw.replaceAll(re, '').trim();
    if (ms.isEmpty) {
      if (text.isNotEmpty && !meta.hasMatch(text)) plain.add(LrcLine(Duration.zero, text));
      continue;
    }
    for (final x in ms) {
      final mn = int.parse(x.group(1)!), sc = int.parse(x.group(2)!);
      final fr = x.group(3);
      final msec = fr == null ? 0 : fr.length == 1 ? int.parse(fr) * 100 : fr.length == 2 ? int.parse(fr) * 10 : int.parse(fr);
      out.add(LrcLine(Duration(minutes: mn, seconds: sc, milliseconds: msec), text));
    }
  }
  if (out.isNotEmpty) { out.sort((a, b) => a.t.compareTo(b.t)); return Lyrics(out, true); }
  if (plain.isNotEmpty) return Lyrics(plain, false);
  return null;
}

String _lyPath(Track t) => '${lib.docs.path}/lyrics/${seedOf(t.path)}.lrc';

Future<Lyrics?> localLyrics(Track t) async {
  try {
    final f = File(_lyPath(t));
    if (await f.exists()) return parseLyrics(await f.readAsString());
  } catch (_) {}
  try {
    final i = t.path.lastIndexOf('.');
    if (i > 0) {
      final f = File('${t.path.substring(0, i)}.lrc');
      if (await f.exists()) return parseLyrics(await f.readAsString());
    }
  } catch (_) {}
  return null;
}

Future<void> saveLyricsText(Track t, String txt) async {
  final f = File(_lyPath(t));
  await f.parent.create(recursive: true);
  await f.writeAsString(txt);
}

Future<dynamic> _getJson(Uri u) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final rq = await c.getUrl(u);
    rq.headers.set('User-Agent', 'Cadence/1.0');
    final rs = await rq.close().timeout(const Duration(seconds: 12));
    if (rs.statusCode != 200) return null;
    return jsonDecode(await rs.transform(utf8.decoder).join());
  } finally { c.close(force: true); }
}

// Free public lyrics database (lrclib.net). Needs internet.
Future<String?> fetchLrclib(Track t) async {
  try {
    final q = <String, String>{'track_name': t.title};
    final known = !t.artist.startsWith('Unknown');
    if (known) q['artist_name'] = t.artist;
    if (!t.album.startsWith('Unknown')) q['album_name'] = t.album;
    if (t.dur > 0) q['duration'] = '${(t.dur / 1000).round()}';
    var j = await _getJson(Uri.https('lrclib.net', '/api/get', q));
    if (j is Map) {
      final x = j['syncedLyrics'] ?? j['plainLyrics'];
      if (x is String && x.trim().isNotEmpty) return x;
    }
    final q2 = <String, String>{'track_name': t.title};
    if (known) q2['artist_name'] = t.artist;
    j = await _getJson(Uri.https('lrclib.net', '/api/search', q2));
    if (j is List) {
      for (final e in j) {
        if (e is Map && e['syncedLyrics'] is String && (e['syncedLyrics'] as String).trim().isNotEmpty) return e['syncedLyrics'] as String;
      }
      for (final e in j) {
        if (e is Map && e['plainLyrics'] is String && (e['plainLyrics'] as String).trim().isNotEmpty) return e['plainLyrics'] as String;
      }
    }
  } catch (_) {}
  return null;
}

Future<Lyrics?> getLyrics(Track t, {bool online = true, bool force = false}) async {
  if (!force && lyricMem.containsKey(t.path) && (lyricMem[t.path] != null || !online)) return lyricMem[t.path];
  Lyrics? ly;
  if (!force) ly = await localLyrics(t);
  if (ly == null && online) {
    final txt = await fetchLrclib(t);
    if (txt != null) {
      ly = parseLyrics(txt);
      if (ly != null) { try { await saveLyricsText(t, txt); } catch (_) {} }
    }
  }
  lyricMem[t.path] = ly;
  return ly;
}

Future<String?> askLong(BuildContext c, String title) {
  final tc = TextEditingController();
  return showDialog<String>(context: c, builder: (d) => AlertDialog(title: Text(title),
      content: SizedBox(height: 260, child: TextField(controller: tc, autofocus: true, maxLines: null, expands: true,
          textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(border: OutlineInputBorder()))),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, tc.text), child: const Text('Save'))]));
}

// One live line under the song name on the player.
class LyricPeek extends StatefulWidget { final Track t; const LyricPeek(this.t, {super.key}); @override State<LyricPeek> createState() => _LP(); }
class _LP extends State<LyricPeek> {
  Lyrics? ly;
  @override
  void initState() { super.initState(); _l(); }
  Future<void> _l() async {
    final r = await getLyrics(widget.t, online: false);
    if (mounted) setState(() => ly = r);
  }
  @override
  Widget build(BuildContext c) => StreamBuilder<Duration>(stream: player.positionStream, builder: (_, ps) {
        final l = ly ?? lyricMem[widget.t.path];
        if (l == null || !l.synced) return const SizedBox.shrink();
        final pos = (ps.data ?? Duration.zero) + const Duration(milliseconds: 250);
        var txt = '';
        for (final x in l.lines) { if (x.t <= pos) { txt = x.s; } else { break; } }
        return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (w, a) => FadeTransition(opacity: a, child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, .5), end: Offset.zero).animate(a), child: w)),
            child: Padding(key: ValueKey(txt), padding: const EdgeInsets.only(top: 10),
                child: Text(txt, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: th.ac, fontWeight: FontWeight.w600))));
      });
}

class LyricsPage extends StatelessWidget {
  const LyricsPage({super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    return StreamBuilder<SequenceState?>(stream: player.sequenceStateStream, builder: (c, s) {
      final t = curTrack(s.data);
      return Scaffold(
          appBar: AppBar(backgroundColor: Colors.transparent, title: Text(t?.title ?? 'Lyrics', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18))),
          body: t == null ? const Center(child: Text('Play a song to see its lyrics.')) : LyricsBody(key: ValueKey(t.path), t: t));
    });
  }
}

class LyricsBody extends StatefulWidget { final Track t; const LyricsBody({super.key, required this.t}); @override State<LyricsBody> createState() => _LB(); }
class _LB extends State<LyricsBody> {
  Lyrics? ly; bool loading = true; int last = -2;
  final sc = ScrollController();
  static const ih = 66.0;
  @override
  void initState() { super.initState(); _load(false); }
  @override
  void dispose() { sc.dispose(); super.dispose(); }
  Future<void> _load(bool force) async {
    setState(() => loading = true);
    final r = await getLyrics(widget.t, force: force);
    if (!mounted) return;
    setState(() { ly = r; loading = false; last = -2; });
  }
  Future<void> _apply(String txt) async {
    final r = parseLyrics(txt);
    if (r == null) { snack('Could not read those lyrics.'); return; }
    try { await saveLyricsText(widget.t, txt); } catch (_) {}
    lyricMem[widget.t.path] = r;
    if (mounted) setState(() { ly = r; last = -2; });
  }
  Future<void> _import() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any);
      final p = r?.files.single.path;
      if (p == null) return;
      await _apply(await File(p).readAsString());
    } catch (_) { snack('Could not open that file.'); }
  }
  Future<void> _paste() async {
    final txt = await askLong(context, 'Paste lyrics (LRC or plain text)');
    if (txt != null && txt.trim().isNotEmpty) await _apply(txt);
  }
  Widget _tools() => Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
        TextButton.icon(onPressed: () => _load(true), icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Find online')),
        TextButton.icon(onPressed: _import, icon: const Icon(Icons.file_open_rounded, size: 18), label: const Text('Import .lrc')),
        TextButton.icon(onPressed: _paste, icon: const Icon(Icons.paste_rounded, size: 18), label: const Text('Paste')),
      ]);
  Widget _synced(List<LrcLine> lines) => LayoutBuilder(builder: (_, bc) {
        final pad = m.max(0.0, (bc.maxHeight - ih) / 2);
        return StreamBuilder<Duration>(stream: player.positionStream, builder: (_, ps) {
          final pos = (ps.data ?? Duration.zero) + const Duration(milliseconds: 250);
          var idx = -1;
          for (int i = 0; i < lines.length; i++) { if (lines[i].t <= pos) { idx = i; } else { break; } }
          if (idx != last) {
            last = idx;
            final target = m.max(0, idx) * ih;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (sc.hasClients) sc.animateTo(target, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
            });
          }
          return ListView.builder(controller: sc, padding: EdgeInsets.symmetric(vertical: pad), itemExtent: ih, itemCount: lines.length, itemBuilder: (_, i) {
            final cur = i == idx, near = (i - idx).abs() == 1;
            return InkWell(onTap: () => player.seek(lines[i].t), child: Center(child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300), opacity: cur ? 1 : near ? .55 : .3,
                child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
                    style: TextStyle(fontSize: cur ? 25 : 18, fontWeight: cur ? FontWeight.w700 : FontWeight.w500, color: cur ? th.ac : th.tx),
                    textAlign: TextAlign.center,
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(lines[i].s.isEmpty ? '♪' : lines[i].s, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis))))));
          });
        });
      });
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    if (loading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: th.ac), const SizedBox(height: 14), const Text('Looking for lyrics…')]));
    }
    final l = ly;
    if (l == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lyrics_outlined, size: 60, color: th.ac), const SizedBox(height: 12),
        const Text('No lyrics found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
        const Text('Cadence checks a .lrc file saved next to the song, then the free LRCLIB database (needs internet).', textAlign: TextAlign.center),
        const SizedBox(height: 14), _tools()])));
    }
    return Column(children: [
      Expanded(child: l.synced ? _synced(l.lines) : SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Text(l.lines.map((e) => e.s).join('\n'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.7)))),
      Padding(padding: const EdgeInsets.only(bottom: 10), child: _tools()),
    ]);
  }
}

// ---------------- Listening diary ----------------
final diary = <String, Map<String, dynamic>>{};
Future<void> diaryAdd(Track t) async {
  final n = DateTime.now();
  final k = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  final d = diary.putIfAbsent(k, () => <String, dynamic>{'n': 0, 'ms': 0, 'a': <String, dynamic>{}, 't': <String, dynamic>{}});
  d['n'] = (d['n'] as int) + 1;
  d['ms'] = (d['ms'] as int) + t.dur;
  final a = d['a'] as Map, tt = d['t'] as Map;
  a[t.artist] = ((a[t.artist] ?? 0) as int) + 1;
  tt[t.title] = ((tt[t.title] ?? 0) as int) + 1;
  (await SharedPreferences.getInstance()).setString('diary', jsonEncode(diary));
}

String diaryLine(String k, Map<String, dynamic> d) {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final dt = DateTime.parse(k);
  final n = d['n'] as int;
  final mood = n < 5 ? 'A quiet' : n < 15 ? 'A steady' : 'A busy';
  final a = (d['a'] as Map).entries.toList()..sort((x, y) => (y.value as int).compareTo(x.value as int));
  final tt = (d['t'] as Map).entries.toList()..sort((x, y) => (y.value as int).compareTo(x.value as int));
  var s = '$mood ${days[dt.weekday - 1]} with $n song${n == 1 ? '' : 's'}';
  if (a.isNotEmpty) s += ', mostly ${a.first.key}';
  if (tt.isNotEmpty && (tt.first.value as int) > 1) s += '. You replayed "${tt.first.key}" ${tt.first.value} times';
  return '$s.';
}

class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final keys = diary.keys.toList()..sort((a, b) => b.compareTo(a));
    return Scaffold(
      appBar: AppBar(title: const Text('Listening diary')),
      body: keys.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Your diary fills in as you listen. Come back tomorrow.', textAlign: TextAlign.center)))
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: keys.length, itemBuilder: (_, i) {
              final k = keys[i], d = diary[k]!, dt = DateTime.parse(k);
              final mins = ((d['ms'] as int) / 60000).round();
              return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: th.ac.withOpacity(.1), borderRadius: BorderRadius.circular(18)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${months[dt.month - 1]} ${dt.day}, ${dt.year}', style: TextStyle(fontSize: 12, letterSpacing: 1, color: th.tx.withOpacity(.6))),
                    const SizedBox(height: 6),
                    Text(diaryLine(k, d), style: const TextStyle(fontSize: 17, height: 1.4)),
                    const SizedBox(height: 6),
                    Text('about $mins min of music', style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.6))),
                  ]));
            }),
    );
  }
}

// ---------------- Time capsules ----------------
final capsules = <Map<String, dynamic>>[];
Future<void> saveCapsules() async =>
    (await SharedPreferences.getInstance()).setStringList('capsules', [for (final x in capsules) jsonEncode(x)]);

Future<void> capsuleSheet(BuildContext c, Track t) async {
  final note = await askLong(c, 'Write a note to your future self');
  if (note == null || note.trim().isEmpty) return;
  if (!c.mounted) return;
  _sheet(c, Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('Open it in…', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    const SizedBox(height: 12),
    Wrap(spacing: 8, children: [
      for (final e in [['1 week', 7], ['1 month', 30], ['6 months', 182], ['1 year', 365]])
        ActionChip(label: Text(e[0] as String), onPressed: () async {
          Navigator.pop(c);
          final now = DateTime.now();
          capsules.add({'path': t.path, 'note': note.trim(), 'made': now.millisecondsSinceEpoch,
            'open': now.add(Duration(days: e[1] as int)).millisecondsSinceEpoch});
          await saveCapsules();
          snack('Sealed. It opens in ${e[0]}.');
        })]),
  ]));
}

Future<void> checkCapsules() async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final due = capsules.where((x) => (x['open'] as int) <= now).toList();
  for (final cp in due) {
    final ctx = navKey.currentState?.overlay?.context;
    if (ctx == null) return;
    final t = lib.byPath[cp['path'] as String];
    final made = DateTime.fromMillisecondsSinceEpoch(cp['made'] as int);
    final play = await showDialog<bool>(context: ctx, barrierDismissible: false, builder: (d) => AlertDialog(
        title: const Text('A time capsule opened'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('You sealed this on ${made.day}/${made.month}/${made.year}:'),
          const SizedBox(height: 10),
          Text('"${cp['note']}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 16)),
          if (t != null) ...[const SizedBox(height: 12), Text('${t.title} · ${t.artist}', style: const TextStyle(fontWeight: FontWeight.w600))],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Close')),
          if (t != null) FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Play it')),
        ]));
    capsules.remove(cp);
    await saveCapsules();
    if (play == true && t != null) await playList([t], 0);
  }
}

// ---------------- Mixes ----------------
class Mix {
  final String name, sub; final IconData icon; final List<Track> tracks; final bool ordered;
  Mix(this.name, this.sub, this.icon, this.tracks, this.ordered);
  List<Track> toPlay() => ordered ? tracks : ([...tracks]..shuffle());
}

List<Color> mixColors(String name) {
  final h = (seedOf(name) % 360).toDouble();
  return [HSLColor.fromAHSL(1, h, .5, .42).toColor(), HSLColor.fromAHSL(1, (h + 45) % 360, .55, .26).toColor()];
}

List<Mix> buildMixes(List<String> rec) {
  final all = lib.tracks;
  if (all.isEmpty) return [];
  int pl(Track t) => lib.plays[t.path] ?? 0;
  final out = <Mix>[];
  void add(String n, String sub, IconData ic, List<Track> l, {bool ordered = false}) {
    if (l.length >= 3) out.add(Mix(n, sub, ic, l, ordered));
  }
  final played = all.where((t) => pl(t) > 0).toList()..sort((a, b) => pl(b).compareTo(pl(a)));
  add('Heavy rotation', 'What you play the most', Icons.local_fire_department_rounded, played.take(30).toList(), ordered: true);
  final recentSet = rec.take(15).toSet();
  add('Forgotten favorites', 'Loved songs you have not heard lately', Icons.history_toggle_off_rounded,
      [for (final t in all) if (lib.favs.contains(t.path) && !recentSet.contains(t.path)) t]);
  add('Fresh finds', 'Songs you have never played', Icons.explore_rounded, ([for (final t in all) if (pl(t) == 0) t]..shuffle()).take(40).toList());
  final newest = [...all]..sort((a, b) => b.added.compareTo(a.added));
  add('Recently added', 'Your newest songs', Icons.fiber_new_rounded, newest.take(30).toList(), ordered: true);
  add('Quick listens', 'Under three minutes', Icons.bolt_rounded, ([for (final t in all) if (t.dur > 0 && t.dur < 180000) t]..shuffle()).take(40).toList());
  add('Long journeys', 'Over six minutes', Icons.landscape_rounded, [for (final t in all) if (t.dur > 360000) t]);
  add('Lossless', 'Your highest quality files', Icons.diamond_outlined, ([for (final t in all) if (t.lossless == true) t]..shuffle()).take(40).toList());
  final byArtist = <String, List<Track>>{};
  for (final t in all) { if (!t.artist.startsWith('Unknown')) (byArtist[t.artist] ??= []).add(t); }
  final artists = byArtist.entries.where((e) => e.value.length >= 3).toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
  for (final e in artists.take(6)) { add('More ${e.key}', '${e.value.length} songs', Icons.person_rounded, e.value); }
  add('Everything', 'All your songs, shuffled', Icons.all_inclusive_rounded, [...all]);
  return out;
}

class MixesTab extends StatelessWidget {
  const MixesTab({super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    return ListenableBuilder(listenable: lib, builder: (_, __) => ValueListenableBuilder<List<String>>(valueListenable: recents, builder: (_, rec, __) {
      final mixes = buildMixes(rec);
      return ListView(padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.paddingOf(c).bottom), children: [
        const Text('Mixes', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w300)),
        const SizedBox(height: 4),
        Text('Made from your own library', style: TextStyle(color: th.tx.withOpacity(.6))),
        const SizedBox(height: 18),
        if (mixes.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Text('Add some songs and your mixes will appear here.', textAlign: TextAlign.center))
        else GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2,
            mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.0,
            children: [for (final x in mixes) _card(c, x)]),
      ]);
    }));
  }

  Widget _card(BuildContext c, Mix x) {
    final cols = mixColors(x.name);
    return GestureDetector(
      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => MixPage(x))),
      child: GlassBox(radius: 26, fill: LinearGradient(colors: cols, begin: Alignment.topLeft, end: Alignment.bottomRight),
          child: Padding(padding: const EdgeInsets.all(16), child: Stack(children: [
            Icon(x.icon, size: 30, color: Colors.white.withOpacity(.85)),
            Positioned(left: 0, right: 0, bottom: 0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(x.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${x.tracks.length} songs', style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 12)),
            ])),
            Positioned(right: 0, top: 0, child: GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); playList(x.toPlay(), 0); },
                child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withOpacity(.22), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white)))),
          ]))),
    );
  }
}

class MixPage extends StatelessWidget {
  final Mix x;
  const MixPage(this.x, {super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    final cols = mixColors(x.name);
    return Scaffold(
      appBar: AppBar(title: Text(x.name), backgroundColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Container(margin: const EdgeInsets.fromLTRB(16, 4, 16, 8), padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: cols, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Row(children: [
              Icon(x.icon, size: 36, color: Colors.white),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(x.sub, style: const TextStyle(color: Colors.white, fontSize: 15)),
                Text('${x.tracks.length} songs', style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 12)),
              ])),
              IconButton.filled(onPressed: () => playList(x.toPlay(), 0), icon: const Icon(Icons.play_arrow_rounded)),
            ])),
        for (int i = 0; i < x.tracks.length; i++) ListTile(
            leading: Art(x.tracks[i], 46, 10),
            title: Text(x.tracks[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(x.tracks[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => playList(x.tracks, i)),
      ]),
    );
  }
}

// ---------------- Online: one search across every provider ----------------
class OnlinePage extends StatefulWidget { const OnlinePage({super.key}); @override State<OnlinePage> createState() => _OnS(); }
class _OnS extends State<OnlinePage> {
  final tc = TextEditingController();
  String filter = 'all';
  @override
  void initState() {
    super.initState();
    if (hub.results.value.isEmpty) { hub.search(''); }
  }
  @override
  void dispose() { tc.dispose(); super.dispose(); }
  void _go() { setState(() => filter = 'all'); hub.search(tc.text.trim()); }

  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    return SafeArea(bottom: false, child: ValueListenableBuilder<List<Track>>(valueListenable: hub.results, builder: (_, all, __) {
      final counts = <String, int>{};
      for (final t in all) { counts[provOf(t)] = (counts[provOf(t)] ?? 0) + 1; }
      final shown = filter == 'all' ? all : [for (final t in all) if (provOf(t) == filter) t];
      final playable = [for (final t in shown) if (!isCollection(t)) t];
      final bottom = MediaQuery.paddingOf(c).bottom;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 8, 0), child: Row(children: [
          const Expanded(child: Text('Online', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: 1))),
          ValueListenableBuilder<bool>(valueListenable: hub.busy, builder: (_, busy, __) => busy
              ? Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: th.ac)))
              : IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded), onPressed: () => hub.search(hub.query))),
          IconButton(tooltip: 'Providers', icon: const Icon(Icons.tune_rounded), onPressed: () => providerSheet(c)),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 6), child: TextField(
            controller: tc, textInputAction: TextInputAction.search, onSubmitted: (_) => _go(),
            decoration: InputDecoration(hintText: 'Search all providers', prefixIcon: const Icon(Icons.search), filled: true,
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: _go),
                fillColor: th.bg.withOpacity(.55), border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none)))),
        if (counts.isNotEmpty) SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text('All (${all.length})'), selected: filter == 'all', onSelected: (_) => setState(() => filter = 'all'))),
          for (final e in counts.entries) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
              label: Text('${hub.byId(e.key)?.name ?? e.key} (${e.value})'), selected: filter == e.key, onSelected: (_) => setState(() => filter = e.key))),
        ])),
        ValueListenableBuilder<Map<String, String>>(valueListenable: hub.errors, builder: (_, errs, __) {
          final notes = <String>[
            for (final e in errs.entries) '${hub.byId(e.key)?.name ?? e.key}: ${e.value}',
            for (final p in hub.all) if (hub.on(p) && !p.ready) '${p.name} is on but not set up. ${p.setup}.',
          ];
          if (notes.isEmpty) return const SizedBox.shrink();
          return Padding(padding: const EdgeInsets.fromLTRB(20, 2, 20, 4), child: Text(notes.join('\n'), style: TextStyle(fontSize: 11.5, color: th.tx.withOpacity(.65))));
        }),
        if (playable.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 6), child: Row(children: [
          FilledButton.icon(onPressed: () => playList(playable, 0), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Play all')),
          const SizedBox(width: 10),
          OutlinedButton.icon(onPressed: () { final x = [...playable]..shuffle(); playList(x, 0); }, icon: const Icon(Icons.shuffle_rounded), label: const Text('Shuffle')),
        ])),
        Expanded(child: shown.isEmpty
            ? ValueListenableBuilder<bool>(valueListenable: hub.busy, builder: (_, busy, __) => Center(child: busy
                ? CircularProgressIndicator(color: th.ac)
                : const Padding(padding: EdgeInsets.all(32), child: Text('No results. Try another search, or open Providers to turn sources on.', textAlign: TextAlign.center))))
            : ListView.builder(padding: EdgeInsets.only(bottom: bottom), itemCount: shown.length, itemBuilder: (_, i) {
                final t = shown[i];
                final coll = isCollection(t);
                final lic = (t.j['lic'] ?? '').toString();
                final prov = hub.byId(provOf(t))?.name ?? provOf(t);
                return ListTile(leading: Art(t, 48, 12),
                    title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(coll ? '${t.artist} · recording' : '${t.artist}${t.album.isEmpty || t.album == prov ? '' : ' · ${t.album}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      Text('$prov${lic.isEmpty ? '' : ' · $lic'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: th.ac)),
                    ]),
                    trailing: coll
                        ? Icon(Icons.library_music_outlined, color: th.ac)
                        : ListenableBuilder(listenable: lib, builder: (_, __) => IconButton(
                            icon: Icon(lib.favs.contains(t.path) ? Icons.favorite : Icons.favorite_border, color: th.ac),
                            onPressed: () { HapticFeedback.selectionClick(); lib.toggleFav(t); })),
                    onTap: () => onlinePlay(shown, i),
                    onLongPress: coll ? null : () { HapticFeedback.mediumImpact(); trackSheet(c, t); });
              })),
      ]);
    }));
  }
}

// ---------------- YouTube & Sync (official YouTube Data API) + ListenBrainz ----------------
// Sign-in uses Google's official "device" OAuth flow, so no browser plugin or app signing key is needed.
// Cadence only READS your YouTube playlists. It never plays YouTube audio and never writes to your account.
final ytClientId = ValueNotifier<String>('');
final ytClientSecret = ValueNotifier<String>('');
final ytChannel = ValueNotifier<Map<String, dynamic>?>(null);
final ytSelected = ValueNotifier<List<String>>([]);
final ytAutoSync = ValueNotifier<bool>(false);
final ytLocalName = <String, String>{};
final lbToken = ValueNotifier<String>('');
final lbOn = ValueNotifier<bool>(false);
String _ytAccess = '', _ytRefresh = '';
int _ytExp = 0;
bool ytCancel = false;

class DeviceCode {
  final String device, user, url; final int interval, expires;
  const DeviceCode(this.device, this.user, this.url, this.interval, this.expires);
}

Future<List<dynamic>> _postForm(Uri u, Map<String, String> body) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final rq = await c.postUrl(u);
    rq.headers.set('Content-Type', 'application/x-www-form-urlencoded');
    rq.headers.set('User-Agent', 'Cadence/1.0');
    rq.write(body.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&'));
    final rs = await rq.close().timeout(const Duration(seconds: 25));
    final txt = await rs.transform(utf8.decoder).join();
    dynamic j;
    try { j = jsonDecode(txt); } catch (_) {}
    return [rs.statusCode, j];
  } finally { c.close(force: true); }
}

Future<void> ytSavePrefs() async {
  final sp = await SharedPreferences.getInstance();
  await sp.setStringList('ytSelected', ytSelected.value);
  await sp.setString('ytMap', jsonEncode(ytLocalName));
  await sp.setBool('ytAuto', ytAutoSync.value);
  await sp.setBool('lbOn', lbOn.value);
  await sp.setString('lbToken', lbToken.value);
  await sp.setString('ytClient', ytClientId.value);
  await sp.setString('ytSecret', ytClientSecret.value);
}

Future<void> ytLoadPrefs(SharedPreferences sp) async {
  ytClientId.value = sp.getString('ytClient') ?? '';
  ytClientSecret.value = sp.getString('ytSecret') ?? '';
  _ytAccess = sp.getString('ytAccess') ?? '';
  _ytRefresh = sp.getString('ytRefresh') ?? '';
  _ytExp = sp.getInt('ytExp') ?? 0;
  ytSelected.value = sp.getStringList('ytSelected') ?? [];
  ytAutoSync.value = sp.getBool('ytAuto') ?? false;
  lbOn.value = sp.getBool('lbOn') ?? false;
  lbToken.value = sp.getString('lbToken') ?? '';
  try {
    final m = jsonDecode(sp.getString('ytMap') ?? '{}') as Map;
    for (final e in m.entries) { ytLocalName[e.key.toString()] = e.value.toString(); }
    final ch = sp.getString('ytChannel');
    if (ch != null && _ytRefresh.isNotEmpty) { ytChannel.value = Map<String, dynamic>.from(jsonDecode(ch) as Map); }
  } catch (_) {}
}

Future<void> _ytStoreTokens(Map j) async {
  _ytAccess = j['access_token'].toString();
  _ytExp = DateTime.now().millisecondsSinceEpoch + (((j['expires_in'] as num?)?.toInt() ?? 3600) - 60) * 1000;
  if (j['refresh_token'] != null) { _ytRefresh = j['refresh_token'].toString(); }
  final sp = await SharedPreferences.getInstance();
  await sp.setString('ytAccess', _ytAccess);
  await sp.setInt('ytExp', _ytExp);
  await sp.setString('ytRefresh', _ytRefresh);
}

Future<void> ytSignOut() async {
  final tok = _ytRefresh.isNotEmpty ? _ytRefresh : _ytAccess;
  _ytAccess = ''; _ytRefresh = ''; _ytExp = 0;
  ytChannel.value = null;
  final sp = await SharedPreferences.getInstance();
  await sp.remove('ytAccess'); await sp.remove('ytRefresh'); await sp.remove('ytExp'); await sp.remove('ytChannel');
  if (tok.isNotEmpty) { try { await _postForm(Uri.https('oauth2.googleapis.com', '/revoke'), {'token': tok}); } catch (_) {} }
}

Future<DeviceCode> ytStartLogin() async {
  final r = await _postForm(Uri.https('oauth2.googleapis.com', '/device/code'),
      {'client_id': ytClientId.value.trim(), 'scope': 'https://www.googleapis.com/auth/youtube.readonly'});
  final j = r[1];
  if (r[0] != 200 || j is! Map) {
    throw (j is Map ? (j['error_description'] ?? j['error'] ?? 'error ${r[0]}') : 'error ${r[0]}').toString();
  }
  return DeviceCode(j['device_code'].toString(), j['user_code'].toString(),
      (j['verification_url'] ?? 'https://www.google.com/device').toString(), (j['interval'] as num?)?.toInt() ?? 5, (j['expires_in'] as num?)?.toInt() ?? 1800);
}

Future<void> ytPoll(DeviceCode d) async {
  final end = DateTime.now().add(Duration(seconds: d.expires));
  var every = d.interval;
  while (DateTime.now().isBefore(end)) {
    await Future.delayed(Duration(seconds: every));
    if (ytCancel) throw 'cancelled';
    final r = await _postForm(Uri.https('oauth2.googleapis.com', '/token'), {
      'client_id': ytClientId.value.trim(), 'client_secret': ytClientSecret.value.trim(),
      'device_code': d.device, 'grant_type': 'urn:ietf:params:oauth:grant-type:device_code'});
    final j = r[1];
    if (j is Map && j['access_token'] != null) { await _ytStoreTokens(j); return; }
    final err = j is Map ? j['error']?.toString() : null;
    if (err == 'authorization_pending') continue;
    if (err == 'slow_down') { every += 5; continue; }
    throw (err == 'access_denied' ? 'Access was denied.' : (j is Map ? (j['error_description'] ?? err ?? 'Sign-in failed') : 'Sign-in failed')).toString();
  }
  throw 'The code expired. Please try again.';
}

Future<String> _ytToken() async {
  if (_ytAccess.isNotEmpty && DateTime.now().millisecondsSinceEpoch < _ytExp) return _ytAccess;
  if (_ytRefresh.isEmpty) throw 'You are not signed in to YouTube.';
  final r = await _postForm(Uri.https('oauth2.googleapis.com', '/token'), {
    'client_id': ytClientId.value.trim(), 'client_secret': ytClientSecret.value.trim(),
    'refresh_token': _ytRefresh, 'grant_type': 'refresh_token'});
  final j = r[1];
  if (r[0] != 200 || j is! Map || j['access_token'] == null) {
    if (j is Map && j['error'] == 'invalid_grant') { await ytSignOut(); throw 'Your YouTube sign-in expired. Please sign in again.'; }
    throw 'Could not refresh the YouTube sign-in.';
  }
  await _ytStoreTokens(j);
  return _ytAccess;
}

Future<Map> _ytGet(String path, Map<String, String> qp) async {
  final tok = await _ytToken();
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final rq = await c.getUrl(Uri.https('www.googleapis.com', '/youtube/v3/$path', qp));
    rq.headers.set('Authorization', 'Bearer $tok');
    rq.headers.set('User-Agent', 'Cadence/1.0');
    final rs = await rq.close().timeout(const Duration(seconds: 25));
    final txt = await rs.transform(utf8.decoder).join();
    dynamic j;
    try { j = jsonDecode(txt); } catch (_) {}
    if (rs.statusCode != 200 || j is! Map) {
      final m = (j is Map && j['error'] is Map) ? ((j['error'] as Map)['message'] ?? 'error ${rs.statusCode}') : 'error ${rs.statusCode}';
      throw m.toString();
    }
    return j;
  } finally { c.close(force: true); }
}

String _thumb(dynamic sn) {
  if (sn is! Map || sn['thumbnails'] is! Map) return '';
  final t = sn['thumbnails'] as Map;
  for (final k in ['medium', 'default', 'high']) { if (t[k] is Map && (t[k] as Map)['url'] != null) { return (t[k] as Map)['url'].toString(); } }
  return '';
}

Future<void> ytLoadChannel() async {
  final j = await _ytGet('channels', {'part': 'snippet,statistics', 'mine': 'true'});
  final items = j['items'];
  if (items is List && items.isNotEmpty && items.first is Map) {
    final e = items.first as Map;
    final sn = e['snippet'] is Map ? e['snippet'] as Map : <dynamic, dynamic>{};
    final st = e['statistics'] is Map ? e['statistics'] as Map : <dynamic, dynamic>{};
    final ch = <String, dynamic>{'id': e['id']?.toString() ?? '', 'title': (sn['title'] ?? 'YouTube').toString(),
      'handle': (sn['customUrl'] ?? '').toString(), 'thumb': _thumb(sn), 'subs': st['subscriberCount']?.toString() ?? '', 'videos': st['videoCount']?.toString() ?? ''};
    ytChannel.value = ch;
    (await SharedPreferences.getInstance()).setString('ytChannel', jsonEncode(ch));
  } else {
    throw 'No YouTube channel was found on this Google account.';
  }
}

Future<List<Map<String, dynamic>>> ytPlaylists() async {
  final out = <Map<String, dynamic>>[];
  String? page;
  do {
    final j = await _ytGet('playlists', {'part': 'snippet,contentDetails', 'mine': 'true', 'maxResults': '50', if (page != null) 'pageToken': page});
    final items = j['items'];
    if (items is List) {
      for (final e in items) {
        if (e is! Map) continue;
        final sn = e['snippet'] is Map ? e['snippet'] as Map : <dynamic, dynamic>{};
        final cd = e['contentDetails'] is Map ? e['contentDetails'] as Map : <dynamic, dynamic>{};
        out.add({'id': e['id'].toString(), 'title': (sn['title'] ?? 'Playlist').toString(), 'count': (cd['itemCount'] as num?)?.toInt() ?? 0, 'thumb': _thumb(sn)});
      }
    }
    page = j['nextPageToken']?.toString();
  } while (page != null && out.length < 200);
  return out;
}

Future<List<Map<String, String>>> ytItems(String playlistId) async {
  final out = <Map<String, String>>[];
  String? page;
  do {
    final j = await _ytGet('playlistItems', {'part': 'snippet', 'playlistId': playlistId, 'maxResults': '50', if (page != null) 'pageToken': page});
    final items = j['items'];
    if (items is List) {
      for (final e in items) {
        if (e is! Map || e['snippet'] is! Map) continue;
        final sn = e['snippet'] as Map;
        final title = (sn['title'] ?? '').toString();
        if (title == 'Private video' || title == 'Deleted video' || title.isEmpty) continue;
        out.add({'title': title, 'owner': (sn['videoOwnerChannelTitle'] ?? '').toString()});
      }
    }
    page = j['nextPageToken']?.toString();
  } while (page != null && out.length < 500);
  return out;
}

Set<String> _words(String s) {
  var x = s.toLowerCase().replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ');
  x = x.replaceAll(RegExp(r'\b(official|video|audio|lyrics|lyric|music|hd|hq|4k|remastered|feat|ft|topic|vevo)\b'), ' ');
  x = x.replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ');
  return x.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
}

class ImportResult {
  final int total, matched; final List<String> missing; final String name;
  const ImportResult(this.total, this.matched, this.missing, this.name);
}

// Copies a YouTube playlist into Cadence by matching each video to a song you already have on your phone.
Future<ImportResult> ytImport(String playlistId, String title) async {
  final items = await ytItems(playlistId);
  final cands = <List<dynamic>>[for (final t in lib.tracks) [t, _words(t.title), _words(t.artist)]];
  final picked = <String>[];
  final missing = <String>[];
  var n = 0;
  for (final it in items) {
    final iw = _words('${it['title']} ${it['owner']}');
    Track? best;
    var bestScore = 0.0;
    for (final c in cands) {
      final tw = c[1] as Set<String>, aw = c[2] as Set<String>;
      if (tw.isEmpty || !iw.containsAll(tw)) continue;
      final artistOk = aw.isEmpty || (c[0] as Track).artist.startsWith('Unknown') || aw.any(iw.contains);
      if (!artistOk) continue;
      final score = tw.length / (iw.length + 1);
      if (score > bestScore) { bestScore = score; best = c[0] as Track; }
    }
    if (best != null && bestScore >= .2) { if (!picked.contains(best.path)) { picked.add(best.path); } } else { missing.add(it['title'] ?? ''); }
    if (++n % 25 == 0) { await Future.delayed(Duration.zero); }
  }
  final name = ytLocalName[playlistId] ?? 'YT - $title';
  ytLocalName[playlistId] = name;
  if (!lib.playlists.containsKey(name)) { await lib.newPlaylist(name); }
  for (final p in [...?lib.playlists[name]]) { if (!picked.contains(p)) { await lib.removeFrom(name, p); } }
  for (final p in picked) { await lib.addTo(name, p); }
  await ytSavePrefs();
  return ImportResult(items.length, picked.length, missing, name);
}

Future<void> ytAutoSyncRun() async {
  if (!ytAutoSync.value || _ytRefresh.isEmpty || ytSelected.value.isEmpty) return;
  final sp = await SharedPreferences.getInstance();
  final last = sp.getInt('ytLast') ?? 0;
  if (DateTime.now().millisecondsSinceEpoch - last < 6 * 3600 * 1000) return;
  try {
    final pls = await ytPlaylists();
    for (final id in ytSelected.value) {
      final p = pls.where((e) => e['id'] == id).toList();
      if (p.isNotEmpty) { await ytImport(id, p.first['title'].toString()); }
    }
    await sp.setInt('ytLast', DateTime.now().millisecondsSinceEpoch);
  } catch (_) {}
}

// ListenBrainz: an open service that keeps your listening history. Uses its official API and your own token.
Future<void> lbSubmit(Track t) async {
  if (!lbOn.value || lbToken.value.trim().isEmpty || t.artist.startsWith('Unknown')) return;
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final rq = await c.postUrl(Uri.https('api.listenbrainz.org', '/1/submit-listens'));
    rq.headers.set('Authorization', 'Token ${lbToken.value.trim()}');
    rq.headers.set('Content-Type', 'application/json');
    rq.write(jsonEncode({'listen_type': 'single', 'payload': [{
      'listened_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'track_metadata': {'artist_name': t.artist, 'track_name': t.title, if (!t.album.startsWith('Unknown')) 'release_name': t.album}}]}));
    final rs = await rq.close().timeout(const Duration(seconds: 15));
    await rs.drain();
  } catch (_) {
  } finally { c.close(force: true); }
}

Future<String?> lbValidate(String token) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final rq = await c.getUrl(Uri.https('api.listenbrainz.org', '/1/validate-token'));
    rq.headers.set('Authorization', 'Token ${token.trim()}');
    final rs = await rq.close().timeout(const Duration(seconds: 15));
    final txt = await rs.transform(utf8.decoder).join();
    final j = jsonDecode(txt);
    if (j is Map && j['valid'] == true) { return (j['user_name'] ?? 'ListenBrainz').toString(); }
  } catch (_) {
  } finally { c.close(force: true); }
  return null;
}

Widget ycard(IconData ic, String title, String sub, {Widget? trailing, Widget? leading, VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(color: th.ac.withOpacity(.09), borderRadius: BorderRadius.circular(26), clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 14, 14), child: Row(children: [
          leading ?? Container(width: 52, height: 52, decoration: BoxDecoration(color: th.ac.withOpacity(.16), borderRadius: BorderRadius.circular(18)), child: Icon(ic, color: th.ac)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            if (sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: th.tx.withOpacity(.65))),
          ])),
          if (trailing != null) trailing,
        ])))));

Future<bool> ytSetupDialog(BuildContext c) async {
  final id = TextEditingController(text: ytClientId.value), sec = TextEditingController(text: ytClientSecret.value);
  final ok = await showDialog<bool>(context: c, builder: (d) => AlertDialog(
      title: const Text('Google setup'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Google needs your own free API keys, one time:\n'
            '1. Go to console.cloud.google.com and create a project.\n'
            '2. APIs and services: enable "YouTube Data API v3".\n'
            '3. OAuth consent screen: choose External and add your own Google account as a test user.\n'
            '4. Credentials: create an OAuth client ID of type "TVs and Limited Input devices".\n'
            '5. Paste the Client ID and Client secret below.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        TextField(controller: id, decoration: const InputDecoration(labelText: 'Client ID')),
        TextField(controller: sec, decoration: const InputDecoration(labelText: 'Client secret')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
      ]));
  if (ok == true && id.text.trim().isNotEmpty && sec.text.trim().isNotEmpty) {
    ytClientId.value = id.text.trim();
    ytClientSecret.value = sec.text.trim();
    await ytSavePrefs();
    return true;
  }
  return false;
}

Future<void> ytConnectFlow(BuildContext c) async {
  if (ytClientId.value.trim().isEmpty || ytClientSecret.value.trim().isEmpty) {
    final ok = await ytSetupDialog(c);
    if (!ok || !c.mounted) return;
  }
  BuildContext? dlg;
  try {
    final d = await ytStartLogin();
    ytCancel = false;
    if (!c.mounted) return;
    showDialog<void>(context: c, barrierDismissible: false, builder: (dc) {
      dlg = dc;
      return AlertDialog(
          title: const Text('Sign in with Google'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('1. On any phone or computer, open\n${d.url}'),
            const SizedBox(height: 10),
            const Text('2. Enter this code:'),
            const SizedBox(height: 6),
            SelectableText(d.user, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 3)),
            const SizedBox(height: 14),
            const Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Expanded(child: Text('Waiting for you to finish…'))]),
          ]),
          actions: [TextButton(onPressed: () { ytCancel = true; Navigator.pop(dc); }, child: const Text('Cancel'))]);
    });
    await ytPoll(d);
    final dc = dlg;
    if (dc != null && dc.mounted) { Navigator.pop(dc); }
    await ytLoadChannel();
    snack('Connected as ${ytChannel.value?['title'] ?? 'your account'}.');
  } catch (e) {
    final dc = dlg;
    if (dc != null && dc.mounted) { Navigator.pop(dc); }
    if (e.toString() != 'cancelled') { snack('YouTube sign-in failed: $e'); }
  }
}

Future<void> ytPickPlaylists(BuildContext c, {required bool sync}) async {
  List<Map<String, dynamic>> pls;
  try {
    snack('Loading your playlists…');
    pls = await ytPlaylists();
  } catch (e) { snack('Could not load playlists: $e'); return; }
  if (!c.mounted) return;
  _sheet(c, StatefulBuilder(builder: (ctx, setS) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * .7,
      child: ListView(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 2), child: Text(sync ? 'Select playlists to sync' : 'Make a playlist local',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(
            'Cadence plays music files on your phone, so each video is matched to a song you already have. Songs you do not have are listed, not played.',
            style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.65)))),
        if (pls.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No playlists were found on this account.')),
        for (final p in pls)
          sync
              ? CheckboxListTile(
                  value: ytSelected.value.contains(p['id']), title: Text(p['title'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${p['count']} videos'),
                  onChanged: (v) async {
                    final id = p['id'].toString();
                    ytSelected.value = v == true ? [...ytSelected.value, id] : [for (final x in ytSelected.value) if (x != id) x];
                    await ytSavePrefs();
                    setS(() {});
                    if (v == true) {
                      try {
                        final r = await ytImport(id, p['title'].toString());
                        snack('${r.name}: matched ${r.matched} of ${r.total} songs.');
                      } catch (e) { snack('Could not import: $e'); }
                    }
                  })
              : ListTile(
                  leading: const Icon(Icons.queue_music_rounded), title: Text(p['title'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${p['count']} videos'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    snack('Matching "${p['title']}" to your library…');
                    try {
                      final r = await ytImport(p['id'].toString(), p['title'].toString());
                      if (!c.mounted) return;
                      showDialog<void>(context: c, builder: (d) => AlertDialog(
                          title: Text('Saved "${r.name}"'),
                          content: SingleChildScrollView(child: Text('Matched ${r.matched} of ${r.total} songs.'
                              '${r.missing.isEmpty ? '' : '\n\nNot in your library:\n${r.missing.take(25).join('\n')}${r.missing.length > 25 ? '\n…and ${r.missing.length - 25} more' : ''}'}')),
                          actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))]));
                    } catch (e) { snack('Could not import: $e'); }
                  }),
      ]))));
}

class YouTubeSyncPage extends StatelessWidget {
  const YouTubeSyncPage({super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube & Sync'), backgroundColor: Colors.transparent),
      body: ListenableBuilder(
          listenable: Listenable.merge([ytChannel, ytSelected, ytAutoSync, lbOn, lbToken, ytClientId]),
          builder: (_, __) {
            final ch = ytChannel.value;
            return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
              Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 10), child: Text('YouTube', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: th.ac))),
              if (ch == null)
                ycard(Icons.play_circle_rounded, 'YouTube account', 'Sign in with Google to see your playlists',
                    trailing: FilledButton(onPressed: () => ytConnectFlow(c), child: const Text('Connect')), onTap: () => ytConnectFlow(c))
              else
                ycard(Icons.person_rounded, ch['title'].toString(), (ch['handle'] ?? '').toString().isEmpty ? 'YouTube account' : ch['handle'].toString(),
                    leading: ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(width: 52, height: 52, child: (ch['thumb'] ?? '').toString().isEmpty
                        ? Icon(Icons.person_rounded, color: th.ac)
                        : Image.network(ch['thumb'].toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: th.ac)))),
                    trailing: IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout_rounded), onPressed: () async {
                      await ytSignOut();
                      snack('Signed out of YouTube.');
                    })),
              if (ch != null) ...[
                ycard(Icons.sync_rounded, 'Keep playlists up to date', 'Selected playlists are refreshed from YouTube about every 6 hours',
                    trailing: Switch(value: ytAutoSync.value, onChanged: (v) async { ytAutoSync.value = v; await ytSavePrefs(); })),
                ycard(Icons.video_library_rounded, 'YouTube channel', '${ch['title']}${(ch['subs'] ?? '').toString().isEmpty ? '' : ' · ${ch['subs']} subscribers'}',
                    trailing: const Icon(Icons.chevron_right_rounded), onTap: () => showDialog<void>(context: c, builder: (d) => AlertDialog(
                        title: Text(ch['title'].toString()),
                        content: Text('${(ch['handle'] ?? '').toString().isEmpty ? '' : '${ch['handle']}\n'}'
                            '${(ch['subs'] ?? '').toString().isEmpty ? '' : '${ch['subs']} subscribers\n'}'
                            '${(ch['videos'] ?? '').toString().isEmpty ? '' : '${ch['videos']} videos'}'),
                        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))]))),
                ycard(Icons.checklist_rounded, 'Select playlists to sync', ytSelected.value.isEmpty ? 'None selected' : '${ytSelected.value.length} playlists syncing',
                    trailing: const Icon(Icons.chevron_right_rounded), onTap: () => ytPickPlaylists(c, sync: true)),
                ycard(Icons.queue_music_rounded, 'Make YouTube playlists local', 'Match a playlist to songs you have and save a copy',
                    trailing: const Icon(Icons.chevron_right_rounded), onTap: () => ytPickPlaylists(c, sync: false)),
              ],
              ycard(Icons.vpn_key_rounded, 'Google setup', ytClientId.value.isEmpty ? 'Add your free API keys (one time)' : 'API keys saved',
                  trailing: const Icon(Icons.chevron_right_rounded), onTap: () => ytSetupDialog(c)),
              Padding(padding: const EdgeInsets.fromLTRB(8, 18, 8, 10), child: Text('Listening history', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: th.ac))),
              ycard(Icons.history_rounded, 'Send plays to ListenBrainz', lbOn.value ? 'On · each song you listen to is added to your history' : 'Off',
                  trailing: Switch(value: lbOn.value, onChanged: (v) async {
                    if (v && lbToken.value.trim().isEmpty) { snack('Add your ListenBrainz token first.'); return; }
                    lbOn.value = v;
                    await ytSavePrefs();
                  })),
              ycard(Icons.key_rounded, 'ListenBrainz token', lbToken.value.isEmpty ? 'Copy it from listenbrainz.org/settings' : 'Token saved',
                  trailing: const Icon(Icons.chevron_right_rounded), onTap: () async {
                    final v = await askText(c, 'ListenBrainz token', lbToken.value, maxLen: 60);
                    if (v == null) return;
                    final name = v.trim().isEmpty ? null : await lbValidate(v);
                    if (v.trim().isNotEmpty && name == null) { snack('That token was not accepted by ListenBrainz.'); return; }
                    lbToken.value = v.trim();
                    if (v.trim().isEmpty) { lbOn.value = false; }
                    await ytSavePrefs();
                    snack(name == null ? 'Token removed.' : 'Connected to ListenBrainz as $name.');
                  }),
              Padding(padding: const EdgeInsets.fromLTRB(8, 14, 8, 0), child: Text(
                  'Cadence only reads your YouTube playlists and never plays YouTube audio. Syncing to your YouTube watch history is not possible: YouTube does not allow apps to write it. ListenBrainz is the open alternative.',
                  style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.6)))),
            ]);
          }),
    );
  }
}

void openPortal(BuildContext c) => Navigator.push(c, PageRouteBuilder<void>(
    opaque: true, transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, __, ___) => const SonicPortalPage(),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child)));

// ---------------- LIVE SONIC PORTAL ----------------
// Real audio analysis: Android's Visualizer (native, see MainActivity.kt) sends the live FFT of what the
// player is outputting. This engine turns it into bass / mids / treble / kick / snare signals.
// The 3D worlds are drawn by a small perspective renderer written for Flutter (no web libraries).
const _vizM = MethodChannel('cadence/viz');
const _vizE = EventChannel('cadence/viz/stream');

class SonicEngine {
  StreamSubscription<dynamic>? _sub;
  bool running = false;
  double _tSub = 0, _tBass = 0, _tMid = 0, _tVocal = 0, _tTreble = 0, _tEnergy = 0;
  final List<double> _tSpec = List<double>.filled(48, 0);
  double sub = 0, bass = 0, mid = 0, vocal = 0, treble = 0, energy = 0, kick = 0, snare = 0;
  final List<double> spec = List<double>.filled(48, 0);
  double clock = 0, bassSens = 1, _lastData = -10;
  final List<double> waves = [];
  double _pBass = 0, _pSnare = 0, _fluxBass = .02, _fluxSnare = .02, _lastKick = -1, _lastSnare = -1;

  Future<String> start() async {
    if (!Platform.isAndroid) return 'Live audio analysis is only available on Android.';
    await stop();
    var st = await Permission.microphone.status;
    if (!st.isGranted) { st = await Permission.microphone.request(); }
    if (!st.isGranted) {
      return 'Android requires the microphone permission to read the live audio signal. Cadence never records anything. Allow it in Settings, then tap Retry.';
    }
    try {
      final session = player.androidAudioSessionId ?? 0;
      final r = await _vizM.invokeMethod<String>('start', {'session': session});
      if (r != 'ok') { return 'Audio analysis could not start (${r ?? 'no answer'}). Play a song and tap Retry.'; }
      _sub = _vizE.receiveBroadcastStream().listen(_onData, onError: (_) {});
      running = true;
      return 'ok';
    } catch (e) {
      return 'Audio analysis is not available on this phone ($e).';
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (running) { try { await _vizM.invokeMethod<String>('stop'); } catch (_) {} }
    running = false;
  }

  void _onData(dynamic e) {
    if (e is! Map) return;
    final raw = e['fft'], srm = e['sr'];
    if (raw is! Uint8List || srm is! int || raw.length < 8) return;
    _lastData = clock;
    final n = raw.length + 1;
    final hz = (srm / 1000.0) / (2 * n);
    double avg(double lo, double hi) {
      var a = (lo / hz).ceil(), b = (hi / hz).floor();
      if (a < 1) { a = 1; }
      if (b > raw.length) { b = raw.length; }
      if (b < a) { b = a; }
      if (a > raw.length) { return 0; }
      var s = 0.0;
      for (var k = a; k <= b; k++) { s += raw[k - 1]; }
      return (s / (b - a + 1)) / 255.0;
    }
    double sh(double x) => m.pow(m.min(1.0, m.max(0.0, x)), .6).toDouble();
    final rawBass = avg(60, 260), rawSnare = avg(1800, 5200);
    _tSub = m.min(1.0, sh(avg(20, 75)) * bassSens);
    _tBass = m.min(1.0, sh(rawBass) * bassSens);
    _tMid = sh(avg(260, 2000));
    _tVocal = sh(avg(300, 3400));
    _tTreble = sh(avg(2000, 16000));
    _tEnergy = sh(avg(30, 12000));
    for (int i = 0; i < 48; i++) {
      final lo = 40 * m.pow(400, i / 48), hi = 40 * m.pow(400, (i + 1) / 48);
      _tSpec[i] = sh(avg(lo.toDouble(), hi.toDouble()));
    }
    // transients: sudden rises (spectral flux) against a running average
    final fb = m.max(0.0, rawBass - _pBass);
    _pBass = rawBass;
    _fluxBass = _fluxBass * .93 + fb * .07;
    if (fb > _fluxBass * 2.1 + .035 / bassSens && clock - _lastKick > .17) {
      kick = 1; _lastKick = clock; waves.add(clock);
      if (waves.length > 6) { waves.removeAt(0); }
    }
    final fs = m.max(0.0, rawSnare - _pSnare);
    _pSnare = rawSnare;
    _fluxSnare = _fluxSnare * .93 + fs * .07;
    if (fs > _fluxSnare * 2.3 + .03 && clock - _lastSnare > .12) { snare = 1; _lastSnare = clock; }
  }

  // Called every frame: eases the latest analysis so motion stays smooth between updates.
  void tick(double dt) {
    clock += dt;
    if (clock - _lastData > .45) {
      _tSub *= .9; _tBass *= .9; _tMid *= .9; _tVocal *= .9; _tTreble *= .9; _tEnergy *= .9;
      for (int i = 0; i < 48; i++) { _tSpec[i] *= .9; }
    }
    double ease(double cur, double tar) => cur + (tar - cur) * (1 - m.exp(-dt * (tar > cur ? 22 : 6)));
    sub = ease(sub, _tSub); bass = ease(bass, _tBass); mid = ease(mid, _tMid);
    vocal = ease(vocal, _tVocal); treble = ease(treble, _tTreble); energy = ease(energy, _tEnergy);
    for (int i = 0; i < 48; i++) { spec[i] = ease(spec[i], _tSpec[i]); }
    kick *= m.exp(-dt * 5.5);
    snare *= m.exp(-dt * 11);
  }
}

class _Cam {
  double yaw = .5, pitch = .18, dist = 7;
  double _cy = 1, _sy = 0, _cp = 1, _sp = 0, _f = 500, _cx0 = 0, _cy0 = 0;
  void prep(Size s) {
    _cy = m.cos(yaw); _sy = m.sin(yaw); _cp = m.cos(pitch); _sp = m.sin(pitch);
    _f = s.shortestSide * .95; _cx0 = s.width / 2; _cy0 = s.height / 2;
  }
  // o = [screenX, screenY, depth, scale]
  bool p(double x, double y, double z, List<double> o) {
    final x1 = x * _cy + z * _sy;
    final z1 = -x * _sy + z * _cy;
    final y1 = y * _cp - z1 * _sp;
    final z2 = y * _sp + z1 * _cp + dist;
    if (z2 < .25) return false;
    final k = _f / z2;
    o[0] = _cx0 + x1 * k; o[1] = _cy0 - y1 * k; o[2] = z2; o[3] = k;
    return true;
  }
  // camera-space z of a direction (used for lighting)
  double facing(double nx, double ny, double nz) {
    final z1 = -nx * _sy + nz * _cy;
    return -(ny * _sp + z1 * _cp);
  }
}

Float32List _mkStars(int n) {
  final r = m.Random(5);
  final o = Float32List(n * 4);
  for (int i = 0; i < n; i++) {
    final u = r.nextDouble() * 2 - 1, th = r.nextDouble() * 6.2832, rad = 7 + r.nextDouble() * 11, s = m.sqrt(1 - u * u);
    o[i * 4] = rad * s * m.cos(th); o[i * 4 + 1] = rad * u; o[i * 4 + 2] = rad * s * m.sin(th); o[i * 4 + 3] = r.nextDouble();
  }
  return o;
}
final Float32List _stars = _mkStars(1500);
const worldNames = ['COSMOS', 'CYBER', 'LIQUID', 'DREAM'];
const worldIcons = [Icons.public_rounded, Icons.grid_on_rounded, Icons.water_drop_rounded, Icons.cloud_rounded];

class PortalPainter extends CustomPainter {
  final int world, prevWorld; final double mix, intensity, density, q; final SonicEngine e; final _Cam cam;
  PortalPainter(this.world, this.prevWorld, this.mix, this.e, this.cam, this.intensity, this.density, this.q, Listenable repaint) : super(repaint: repaint);
  final List<double> _o = List<double>.filled(4, 0);
  final List<double> _o2 = List<double>.filled(4, 0);
  final List<double> _o3 = List<double>.filled(4, 0);
  final List<double> _o4 = List<double>.filled(4, 0);

  double _op(double v) => m.min(1.0, m.max(0.0, v * intensity));

  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.drawRect(rect, Paint()..color = Colors.black);
    cam.prep(s);
    if (mix < 1) {
      c.saveLayer(rect, Paint()..color = Colors.white.withOpacity(1 - mix));
      _draw(prevWorld, c, s);
      c.restore();
      c.saveLayer(rect, Paint()..color = Colors.white.withOpacity(mix));
      _draw(world, c, s);
      c.restore();
    } else {
      _draw(world, c, s);
    }
    // cinematic vignette
    c.drawRect(rect, Paint()..shader = RadialGradient(radius: .95, colors: [Colors.transparent, Colors.black.withOpacity(.65)], stops: const [.55, 1]).createShader(rect));
    // snare flash
    if (e.snare > .05) { c.drawRect(rect, Paint()..color = Colors.white.withOpacity(.07 * e.snare * intensity)); }
  }

  void _draw(int w, Canvas c, Size s) {
    if (w == 0) { _cosmos(c, s); } else if (w == 1) { _cyber(c, s); } else if (w == 2) { _liquid(c, s); } else { _dream(c, s); }
  }

  Paint _glow(Color col, double op, double w) => Paint()
    ..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
    ..color = col.withOpacity(m.min(1.0, m.max(0.0, op)))..blendMode = BlendMode.plus;

  void _poly(Canvas c, List<List<double>> pts, Paint p, {bool close = false}) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts[0][0], pts[0][1]);
    for (int i = 1; i < pts.length; i++) { path.lineTo(pts[i][0], pts[i][1]); }
    if (close) { path.close(); }
    c.drawPath(path, p);
  }

  // ---------------- COSMOS ----------------
  void _cosmos(Canvas c, Size s) {
    final t = e.clock, rect = Offset.zero & s;
    final en = e.energy;
    c.drawRect(rect, Paint()..shader = RadialGradient(center: Alignment(-.5 + .25 * m.sin(t * .1 + cam.yaw), -.35), radius: .95,
        colors: [const Color(0xFF6A2CFF).withOpacity(_op(.2 + en * .35)), Colors.transparent]).createShader(rect));
    c.drawRect(rect, Paint()..shader = RadialGradient(center: Alignment(.6, .45 + .15 * m.cos(t * .13)), radius: .85,
        colors: [const Color(0xFF00C8FF).withOpacity(_op(.12 + e.mid * .3)), Colors.transparent]).createShader(rect));
    // stars (treble makes them flare and burst)
    final n = m.min(1500, (800 * density * q).round());
    final big = Float32List(n * 2), mid = Float32List(n * 2), small = Float32List(n * 2);
    var nb = 0, nm = 0, ns = 0;
    final rot = t * .018, cr = m.cos(rot), sr = m.sin(rot), bucket = (t * 9).floor();
    for (int i = 0; i < n; i++) {
      final x = _stars[i * 4], y = _stars[i * 4 + 1], z = _stars[i * 4 + 2], ph = _stars[i * 4 + 3];
      if (!cam.p(x * cr + z * sr, y, -x * sr + z * cr, _o)) continue;
      if (_o[0] < -10 || _o[0] > s.width + 10 || _o[1] < -10 || _o[1] > s.height + 10) continue;
      final flare = e.treble > .22 && _h(i, bucket) > 1 - e.treble * .22;
      if (flare) { big[nb++] = _o[0]; big[nb++] = _o[1]; }
      else if (ph > .75) { mid[nm++] = _o[0]; mid[nm++] = _o[1]; }
      else { small[ns++] = _o[0]; small[ns++] = _o[1]; }
    }
    c.drawRawPoints(PointMode.points, small.sublist(0, ns), Paint()..color = Colors.white.withOpacity(_op(.55))..strokeWidth = 1.4..strokeCap = StrokeCap.round);
    c.drawRawPoints(PointMode.points, mid.sublist(0, nm), Paint()..color = const Color(0xFFBFD9FF).withOpacity(_op(.8))..strokeWidth = 2.4..strokeCap = StrokeCap.round);
    c.drawRawPoints(PointMode.points, big.sublist(0, nb), Paint()..color = Colors.white.withOpacity(_op(.95))..strokeWidth = 4.2..strokeCap = StrokeCap.round..blendMode = BlendMode.plus);
    // radial bursts of particles (treble)
    if (e.treble > .12) {
      final cnt = m.min(120, (90 * density * q).round());
      final pts = Float32List(cnt * 2);
      var k = 0;
      for (int i = 0; i < cnt; i++) {
        final u = _h(i, 3) * 2 - 1, th = _h(i, 4) * 6.2832, sq = m.sqrt(1 - u * u), age = (t * (.35 + _h(i, 5) * .5) + _h(i, 6)) % 1;
        final r = 1.4 + age * (3 + 5 * e.treble);
        if (!cam.p(r * sq * m.cos(th), r * u, r * sq * m.sin(th), _o)) continue;
        pts[k++] = _o[0]; pts[k++] = _o[1];
      }
      c.drawRawPoints(PointMode.points, pts.sublist(0, k), Paint()..color = const Color(0xFF8CF3FF).withOpacity(_op(.35 + e.treble * .6))..strokeWidth = 2.6..strokeCap = StrokeCap.round..blendMode = BlendMode.plus);
    }
    // central energy structure: glow + three interlocking rings
    if (cam.p(0, 0, 0, _o)) {
      final rad = (70 + 150 * e.sub + 90 * e.kick) * _o[3] / 120;
      final gc = Rect.fromCircle(center: Offset(_o[0], _o[1]), radius: rad * 2.2);
      c.drawCircle(gc.center, gc.width / 2, Paint()..blendMode = BlendMode.plus..shader = RadialGradient(colors: [
        Color.lerp(const Color(0xFF9A5CFF), const Color(0xFF00E5FF), e.mid)!.withOpacity(_op(.55 + e.kick * .35)), Colors.transparent]).createShader(gc));
    }
    final rr = 1.15 + .55 * e.bass + .35 * e.kick;
    for (int ring = 0; ring < 3; ring++) {
      final pts = <List<double>>[];
      final tx = t * (.25 + ring * .13) + ring * 1.1, ty = t * (.19 + ring * .07) + ring * 2.0, segs = m.max(24, (72 * q).round());
      for (int i = 0; i <= segs; i++) {
        final a = i / segs * 6.2832, wob = 1 + .12 * e.spec[(i * 47 ~/ segs) % 48] * 2;
        var x = rr * wob * m.cos(a), y = 0.0, z = rr * wob * m.sin(a);
        final y1 = y * m.cos(tx) - z * m.sin(tx), z1 = y * m.sin(tx) + z * m.cos(tx);
        final x2 = x * m.cos(ty) + z1 * m.sin(ty), z2 = -x * m.sin(ty) + z1 * m.cos(ty);
        if (!cam.p(x2, y1, z2, _o)) continue;
        pts.add([_o[0], _o[1]]);
      }
      final col = ring == 0 ? const Color(0xFFB07CFF) : ring == 1 ? const Color(0xFF4DD8FF) : const Color(0xFFFFFFFF);
      _poly(c, pts, _glow(col, _op(.35 + e.energy * .5), 5 + 7 * e.bass));
      _poly(c, pts, _glow(Colors.white, _op(.5 + e.kick * .4), 1.3));
    }
    // kick shockwaves: expanding cosmic waves
    for (final w in e.waves) {
      final age = e.clock - w;
      if (age < 0 || age > 2.4) continue;
      final r = .8 + age * 5.2, fade = 1 - age / 2.4, pts = <List<double>>[];
      for (int i = 0; i <= 80; i++) {
        final a = i / 80 * 6.2832;
        if (!cam.p(r * m.cos(a), 0, r * m.sin(a), _o)) continue;
        pts.add([_o[0], _o[1]]);
      }
      _poly(c, pts, _glow(Color.lerp(const Color(0xFF00E5FF), const Color(0xFFB07CFF), age / 2.4)!, _op(.8 * fade), 3.5 * fade + .8));
    }
  }

  // ---------------- CYBER ----------------
  void _cyber(Canvas c, Size s) {
    final t = e.clock, rect = Offset.zero & s;
    c.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFF05000F), const Color(0xFF14002B).withOpacity(.9), const Color(0xFF2B0045).withOpacity(_op(.5 + e.energy * .3))]).createShader(rect));
    // beat pulse at the vanishing point
    if (cam.p(0, 0, 30, _o)) {
      final gc = Rect.fromCircle(center: Offset(_o[0], _o[1]), radius: s.shortestSide * (.55 + .5 * e.kick));
      c.drawCircle(gc.center, gc.width / 2, Paint()..blendMode = BlendMode.plus..shader = RadialGradient(colors: [
        const Color(0xFFFF2BD6).withOpacity(_op(.18 + .55 * e.kick)), Colors.transparent]).createShader(gc));
    }
    // reactive floor grid (height follows the spectrum)
    final rows = m.max(6, (14 * q).round());
    for (int j = 0; j < rows; j++) {
      final z = ((j * 2.2 - t * (2 + 5 * e.energy)) % (rows * 2.2));
      final pts = <List<double>>[];
      for (int i = 0; i <= 32; i++) {
        final x = -12 + i * .75, y = -2.0 + e.spec[(i * 47 ~/ 32) % 48] * 2.2 * intensity * (1 - z / (rows * 2.2) * .5);
        if (!cam.p(x, y, z, _o)) continue;
        pts.add([_o[0], _o[1]]);
      }
      _poly(c, pts, _glow(const Color(0xFFFF2BD6), _op(.55 * (1 - z / (rows * 2.2)) + .1), 1.3 + 1.5 * e.kick));
    }
    for (int i = 0; i <= 16; i++) {
      final x = -12 + i * 1.5, pts = <List<double>>[];
      for (int k = 0; k <= 10; k++) {
        final z = k * 2.4, y = -2.0 + e.spec[m.max(0, m.min(47, ((x + 12) / 24 * 47).round()))] * 2.2 * intensity * (1 - k / 14);
        if (!cam.p(x, y, z, _o)) continue;
        pts.add([_o[0], _o[1]]);
      }
      _poly(c, pts, _glow(const Color(0xFF00E5FF), _op(.35), 1.1));
    }
    // glowing neon tunnel
    const len = 34.0;
    final frames = m.max(8, (18 * q).round());
    for (int i = 0; i < frames; i++) {
      final zz = ((i * (len / frames) - t * (4 + 9 * e.energy)) % len + len) % len;
      final half = 2.5 + .25 * m.sin(i + t) + .4 * e.bass, tw = t * .12 + zz * .035;
      final pts = <List<double>>[];
      for (int k = 0; k < 4; k++) {
        final a = tw + k * 1.5708 + .7854, x = half * 1.41 * m.cos(a), y = half * 1.41 * m.sin(a);
        if (!cam.p(x, y, zz, _o)) continue;
        pts.add([_o[0], _o[1]]);
      }
      final near = 1 - zz / len;
      final col = i.isEven ? const Color(0xFF00E5FF) : const Color(0xFFFF2BD6);
      _poly(c, pts, _glow(col, _op(.25 + .75 * e.kick * near + .35 * near), 1.2 + 3.2 * e.kick), close: true);
    }
    // geometric core: rotating octahedron
    final r = 1.0 + .7 * e.bass + .4 * e.kick, a = t * .5, ca = m.cos(a), sa = m.sin(a);
    final v = <List<double>>[];
    for (final p in [[r, 0.0, 0.0], [-r, 0.0, 0.0], [0.0, r, 0.0], [0.0, -r, 0.0], [0.0, 0.0, r], [0.0, 0.0, -r]]) {
      if (!cam.p(p[0] * ca + p[2] * sa, p[1], -p[0] * sa + p[2] * ca, _o)) { v.add([-9999, -9999]); } else { v.add([_o[0], _o[1]]); }
    }
    for (final ed in [[0, 2], [0, 3], [0, 4], [0, 5], [1, 2], [1, 3], [1, 4], [1, 5], [2, 4], [2, 5], [3, 4], [3, 5]]) {
      if (v[ed[0]][0] < -9000 || v[ed[1]][0] < -9000) continue;
      c.drawLine(Offset(v[ed[0]][0], v[ed[0]][1]), Offset(v[ed[1]][0], v[ed[1]][1]), _glow(const Color(0xFFB8F6FF), _op(.7 + e.kick * .3), 2 + 2 * e.kick));
    }
  }

  // ---------------- LIQUID ----------------
  void _liquid(Canvas c, Size s) {
    final t = e.clock, rect = Offset.zero & s;
    c.drawRect(rect, Paint()..shader = RadialGradient(center: const Alignment(0, .2), radius: 1.0,
        colors: [const Color(0xFF1A1040).withOpacity(_op(.8 + e.energy * .2)), const Color(0xFF020208)]).createShader(rect));
    final la = m.max(8, (18 * q).round()), lo = m.max(14, (30 * q).round());
    final vx = List<double>.filled((la + 1) * (lo + 1) * 6, 0);
    final ok = List<bool>.filled((la + 1) * (lo + 1), false);
    for (int i = 0; i <= la; i++) {
      final phi = 3.14159 * i / la, sp = m.sin(phi), cp = m.cos(phi);
      for (int j = 0; j <= lo; j++) {
        final th = 6.2832 * j / lo, nx = sp * m.cos(th), nz = sp * m.sin(th), ny = cp;
        final band = e.spec[m.max(0, m.min(47, (j % lo) * 47 ~/ lo))];
        final d = .26 * e.sub + .2 * e.bass + band * .42 * intensity + .07 * m.sin(phi * 5 + t * 1.6) * (1 + e.mid)
            + .05 * m.sin(th * 3 - t * 1.1) + e.kick * .22 * m.sin(phi * 9 - t * 11) * m.exp(-phi * .5);
        final rad = 1.6 + d, idx = i * (lo + 1) + j, b = idx * 6;
        if (!cam.p(nx * rad, ny * rad, nz * rad, _o)) continue;
        ok[idx] = true;
        vx[b] = _o[0]; vx[b + 1] = _o[1]; vx[b + 2] = _o[2]; vx[b + 3] = nx; vx[b + 4] = ny; vx[b + 5] = nz;
      }
    }
    final quads = <int>[];
    for (int i = 0; i < la; i++) { for (int j = 0; j < lo; j++) { quads.add(i * lo + j); } }
    double depthOf(int qd) { final i = qd ~/ lo, j = qd % lo; return vx[(i * (lo + 1) + j) * 6 + 2]; }
    quads.sort((a, b) => depthOf(b).compareTo(depthOf(a)));
    const lx = -.4, ly = .75, lz = -.55;
    for (final qd in quads) {
      final i = qd ~/ lo, j = qd % lo;
      final i0 = i * (lo + 1) + j, i1 = i0 + 1, i2 = i0 + lo + 2, i3 = i0 + lo + 1;
      if (!(ok[i0] && ok[i1] && ok[i2] && ok[i3])) continue;
      final nx = (vx[i0 * 6 + 3] + vx[i2 * 6 + 3]) / 2, ny = (vx[i0 * 6 + 4] + vx[i2 * 6 + 4]) / 2, nz = (vx[i0 * 6 + 5] + vx[i2 * 6 + 5]) / 2;
      final f = m.max(0.0, cam.facing(nx, ny, nz));
      if (f <= 0 && vx[i0 * 6 + 2] > cam.dist + 1.1) continue;
      final env = m.min(1.0, m.max(0.0, (ny + .35) / 1.35)), rim = m.pow(1 - m.min(1.0, f), 2.2).toDouble();
      final df = m.max(0.0, nx * lx + ny * ly + nz * lz), spec = m.pow(df, 22).toDouble();
      var r = 14 + 190 * env + 70 * rim * (1 - e.mid) + 120 * spec;
      var g = 18 + 205 * env + 40 * rim + 120 * spec;
      var b = 40 + 240 * env + 160 * rim * (.5 + e.mid) + 120 * spec;
      r += 70 * e.bass * (1 - env); b += 40 * e.treble;
      final col = Color.fromARGB(255, m.max(0, m.min(255, r.round())), m.max(0, m.min(255, g.round())), m.max(0, m.min(255, b.round())));
      final path = Path()..moveTo(vx[i0 * 6], vx[i0 * 6 + 1])..lineTo(vx[i1 * 6], vx[i1 * 6 + 1])..lineTo(vx[i2 * 6], vx[i2 * 6 + 1])..lineTo(vx[i3 * 6], vx[i3 * 6 + 1])..close();
      c.drawPath(path, Paint()..color = col..style = PaintingStyle.fill);
      c.drawPath(path, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = .7);
    }
    // chrome droplets / treble sparkle
    final cnt = m.min(80, (60 * density * q).round());
    final pts = Float32List(cnt * 2);
    var k = 0;
    for (int i = 0; i < cnt; i++) {
      final a = t * (.2 + _h(i, 1) * .4) + _h(i, 2) * 6.28, rr = 2.4 + _h(i, 3) * 1.6 + e.bass * .5;
      if (!cam.p(rr * m.cos(a), (_h(i, 4) - .5) * 3, rr * m.sin(a), _o)) continue;
      pts[k++] = _o[0]; pts[k++] = _o[1];
    }
    c.drawRawPoints(PointMode.points, pts.sublist(0, k), Paint()..color = Color.lerp(const Color(0xFFBFD6FF), const Color(0xFFFFFFFF), e.treble)!.withOpacity(_op(.5 + e.treble * .5))..strokeWidth = 3..strokeCap = StrokeCap.round..blendMode = BlendMode.plus);
  }

  // ---------------- DREAM ----------------
  void _dream(Canvas c, Size s) {
    final t = e.clock, rect = Offset.zero & s, w = s.width, h = s.height;
    final hue = (252 + 38 * m.sin(t * .03) + 30 * e.energy + cam.yaw * 6) % 360;
    Color hc(double dh, double sat, double l) => HSLColor.fromAHSL(1, (hue + dh) % 360, sat, l).toColor();
    c.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [hc(0, .55, .06), hc(25, .5, .18 + e.energy * .08), hc(70, .65, .42 + e.bass * .1), hc(100, .6, .55)], stops: const [0, .45, .75, 1]).createShader(rect));
    // soft sun / moon on the horizon
    final hy = h * (.66 + cam.pitch * .15);
    final sunR = w * (.3 + .12 * e.bass);
    final sc = Rect.fromCircle(center: Offset(w * (.5 + .18 * m.sin(t * .05 - cam.yaw)), hy), radius: sunR);
    c.drawCircle(sc.center, sunR, Paint()..blendMode = BlendMode.plus..shader = RadialGradient(colors: [hc(110, .8, .8).withOpacity(_op(.55 + e.kick * .25)), Colors.transparent]).createShader(sc));
    // volumetric light shafts
    for (int i = 0; i < 6; i++) {
      final x0 = w * (.1 + .16 * i) + 30 * m.sin(t * .15 + i) - cam.yaw * 40, spread = 60 + 40 * m.sin(t * .1 + i * 2);
      final path = Path()..moveTo(x0, -10)..lineTo(x0 - spread * 2.2, hy)..lineTo(x0 + spread * 2.2, hy)..close();
      c.drawPath(path, Paint()..blendMode = BlendMode.plus..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(_op(.07 + e.energy * .12)), Colors.transparent]).createShader(Rect.fromLTWH(x0 - spread * 2.2, 0, spread * 4.4, hy)));
    }
    // layered landscape with parallax
    for (int l = 0; l < 3; l++) {
      final base = h * (.62 + .09 * l) + cam.pitch * 30 * (l + 1), amp = 26 + 20 * l + 30 * e.bass * (l + 1) / 3;
      final path = Path()..moveTo(0, h);
      final stepX = w / 42;
      for (int i = 0; i <= 42; i++) {
        final x = i * stepX;
        final y = base + m.sin(x * .007 * (l + 1) + t * .04 * (l + 1) + cam.yaw * (2 + l)) * amp + m.sin(x * .021 + l * 3 + t * .02) * amp * .4;
        path.lineTo(x, y);
      }
      path..lineTo(w, h)..close();
      c.drawPath(path, Paint()..color = hc(60 - l * 30, .5, .16 - l * .04).withOpacity(.92));
    }
    // drifting volumetric fog
    for (int i = 0; i < 7; i++) {
      final cx = (((i * .37 + t * .008 * (i + 1) - cam.yaw * .1) % 1.4) - .2) * w, cy = h * (.58 + .06 * (i % 4));
      final fr = Rect.fromCircle(center: Offset(cx, cy), radius: w * (.38 + .05 * (i % 3)));
      c.drawCircle(fr.center, fr.width / 2, Paint()..blendMode = BlendMode.plus..shader = RadialGradient(colors: [
        hc(80, .5, .8).withOpacity(_op(.07 + e.mid * .12)), Colors.transparent]).createShader(fr));
    }
    // soft glowing particles
    final cnt = m.min(160, (100 * density * q).round());
    for (int i = 0; i < cnt; i++) {
      final x = (((_h(i, 1) + .03 * m.sin(t * .25 + i) + cam.yaw * .05) % 1) + 1) % 1 * w;
      final y = (((_h(i, 2) - t * .018 * (.4 + _h(i, 3))) % 1) + 1) % 1 * h;
      final r = 1.5 + 3 * _h(i, 4) + 5 * e.treble * _h(i, 5), tw = .5 + .5 * m.sin(t * (.8 + _h(i, 6)) + i);
      final col = (i % 3 == 0 ? Colors.white : i % 3 == 1 ? hc(120, .8, .8) : hc(40, .8, .8));
      c.drawCircle(Offset(x, y), r * 3, Paint()..color = col.withOpacity(_op(.06 * tw))..blendMode = BlendMode.plus);
      c.drawCircle(Offset(x, y), r, Paint()..color = col.withOpacity(_op(.35 + .5 * tw))..blendMode = BlendMode.plus);
    }
  }

  @override
  bool shouldRepaint(covariant PortalPainter o) => true;
}

class SonicPortalPage extends StatefulWidget { const SonicPortalPage({super.key}); @override State<SonicPortalPage> createState() => _SPS(); }
class _SPS extends State<SonicPortalPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final eng = SonicEngine();
  final cam = _Cam();
  final frame = ValueNotifier<int>(0);
  late final Ticker tk;
  Duration _last = Duration.zero;
  int world = 0, prevWorld = 0;
  double mixT = 1, intensity = 1, bassSens = 1, density = 1, q = 1;
  bool autoSwitch = false, uiOn = true, hideUi = false, immersive = true, _drag = false;
  double _autoT = 0, _acc = 0, _z0 = 7;
  int _n = 0;
  Timer? _hide;
  String status = '';
  double? _seek;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadPrefs();
    tk = createTicker(_tick)..start();
    _startEngine();
    _poke();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      world = m.max(0, m.min(3, sp.getInt('sp_world') ?? 0));
      prevWorld = world;
      intensity = sp.getDouble('sp_int') ?? 1;
      bassSens = sp.getDouble('sp_bass') ?? 1;
      density = sp.getDouble('sp_dens') ?? 1;
      autoSwitch = sp.getBool('sp_auto') ?? false;
    });
  }

  Future<void> _savePrefs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('sp_world', world);
    await sp.setDouble('sp_int', intensity);
    await sp.setDouble('sp_bass', bassSens);
    await sp.setDouble('sp_dens', density);
    await sp.setBool('sp_auto', autoSwitch);
  }

  Future<void> _startEngine() async {
    final r = await eng.start();
    if (mounted) { setState(() => status = r == 'ok' ? '' : r); }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused) { eng.stop(); }
    if (st == AppLifecycleState.resumed) { _startEngine(); }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hide?.cancel();
    tk.dispose();
    eng.stop();
    frame.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _savePrefs();
    super.dispose();
  }

  void _tick(Duration d) {
    final dt = m.min(.05, (d - _last).inMicroseconds / 1e6);
    _last = d;
    if (dt <= 0) return;
    eng.bassSens = bassSens;
    eng.tick(dt);
    if (!_drag) { cam.yaw += dt * (.05 + .1 * eng.energy); }
    if (mixT < 1) { mixT = m.min(1.0, mixT + dt / .9); }
    if (autoSwitch) {
      _autoT += dt;
      if (_autoT > 40) { _autoT = 0; _setWorld((world + 1) % 4); }
    }
    _acc += dt; _n++;
    if (_n >= 45) {
      final avg = _acc / _n;
      if (avg > .024 && q > .45) { q -= .1; } else if (avg < .0175 && q < 1) { q += .05; }
      _acc = 0; _n = 0;
    }
    frame.value++;
  }

  void _setWorld(int w) {
    if (w == world) return;
    setState(() { prevWorld = world; world = w; mixT = 0; });
    _savePrefs();
  }

  void _poke() {
    _hide?.cancel();
    if (!uiOn && mounted) { setState(() => uiOn = true); }
    _hide = Timer(const Duration(seconds: 4), () { if (mounted) { setState(() => uiOn = false); } });
  }

  void _reset() { cam.yaw = .5; cam.pitch = .18; cam.dist = 7; _poke(); }

  void _settings(BuildContext c) {
    _poke();
    _sheet(c, StatefulBuilder(builder: (ctx, setS) {
      Widget row(String label, double v, double lo, double hi, void Function(double) f) => Row(children: [
            SizedBox(width: 118, child: Text(label, style: const TextStyle(fontSize: 13))),
            Expanded(child: Slider(value: v, min: lo, max: hi, onChanged: (x) { setS(() {}); setState(() => f(x)); }, onChangeEnd: (_) => _savePrefs())),
          ]);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Portal settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        row('Visual intensity', intensity, .3, 1.5, (x) => intensity = x),
        row('Bass sensitivity', bassSens, .5, 2.0, (x) => bassSens = x),
        row('Particle density', density, .3, 1.5, (x) => density = x),
        SwitchListTile(title: const Text('Switch worlds automatically'), subtitle: const Text('Every 40 seconds'), value: autoSwitch,
            onChanged: (v) { setS(() {}); setState(() => autoSwitch = v); _savePrefs(); }),
      ]);
    }));
  }

  Widget _glass(Widget child, {double radius = 28}) => ClipRRect(borderRadius: BorderRadius.circular(radius), child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(.14))), child: child)));

  Widget _top(BuildContext c) => Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 0), child: Row(children: [
        IconButton(tooltip: 'Exit', icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(c)),
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (int i = 0; i < 4; i++) Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
              onTap: () { _setWorld(i); _poke(); },
              child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                      color: world == i ? Colors.white.withOpacity(.2) : Colors.white.withOpacity(.05),
                      border: Border.all(color: Colors.white.withOpacity(world == i ? .5 : .12))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(worldIcons[i], size: 15, color: Colors.white.withOpacity(world == i ? 1 : .6)), const SizedBox(width: 6),
                    Text(worldNames[i], style: TextStyle(color: Colors.white.withOpacity(world == i ? 1 : .6), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w500)),
                  ])))),
        ]))),
        IconButton(tooltip: 'Settings', icon: const Icon(Icons.tune_rounded, color: Colors.white), onPressed: () => _settings(c)),
        IconButton(tooltip: 'Full screen', icon: Icon(immersive ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white), onPressed: () {
          setState(() => immersive = !immersive);
          SystemChrome.setEnabledSystemUIMode(immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
          _poke();
        }),
        IconButton(tooltip: 'Hide interface', icon: const Icon(Icons.visibility_off_rounded, color: Colors.white), onPressed: () => setState(() => hideUi = true)),
      ]));

  Widget _bottom(BuildContext c) => StreamBuilder<SequenceState?>(stream: player.sequenceStateStream, builder: (_, s) {
        final t = curTrack(s.data);
        return Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: _glass(Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Art(t, 54, 14), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t?.title ?? 'Nothing playing', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500)),
              Text(t?.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.65), fontSize: 13, letterSpacing: .5)),
            ])),
            IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Colors.white), onPressed: () { player.seekToPrevious(); _poke(); }),
            const PlayBtn(48),
            IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white), onPressed: () { skipNext(); _poke(); }),
          ]),
          StreamBuilder<Duration?>(stream: player.durationStream, builder: (_, ds) => StreamBuilder<Duration>(stream: player.positionStream, builder: (_, ps) {
            final dur = (ds.data ?? Duration.zero).inMilliseconds.toDouble(), pos = (ps.data ?? Duration.zero).inMilliseconds.toDouble();
            final v = _seek ?? (dur <= 0 ? 0.0 : m.min(1.0, pos / dur));
            return SliderTheme(data: SliderTheme.of(c).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5), activeTrackColor: Colors.white, inactiveTrackColor: Colors.white24, thumbColor: Colors.white),
                child: Slider(value: v, onChanged: dur <= 0 ? null : (x) => setState(() => _seek = x),
                    onChangeEnd: (x) { player.seek(Duration(milliseconds: (x * dur).round())); setState(() => _seek = null); _poke(); }));
          })),
          Row(children: [
            const Icon(Icons.volume_up_rounded, size: 18, color: Colors.white70),
            Expanded(child: StreamBuilder<double>(stream: player.volumeStream, builder: (_, vs) => SliderTheme(
                data: SliderTheme.of(c).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4), activeTrackColor: Colors.white70, inactiveTrackColor: Colors.white24, thumbColor: Colors.white),
                child: Slider(value: m.max(0.0, m.min(1.0, vs.data ?? 1.0)), onChanged: (x) { player.setVolume(x); _poke(); })))),
          ]),
        ]))));
      });

  @override
  Widget build(BuildContext c) {
    final show = uiOn && !hideUi;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () { if (hideUi) { setState(() => hideUi = false); _poke(); } else { setState(() => uiOn = !uiOn); if (uiOn) { _poke(); } } },
            onDoubleTap: _reset,
            onScaleStart: (_) { _drag = true; _z0 = cam.dist; },
            onScaleUpdate: (d) {
              cam.yaw += d.focalPointDelta.dx * .008;
              cam.pitch = m.max(-1.2, m.min(1.2, cam.pitch - d.focalPointDelta.dy * .006));
              if (d.scale != 1) { cam.dist = m.max(3.5, m.min(14.0, _z0 / d.scale)); }
            },
            onScaleEnd: (_) => _drag = false,
            child: RepaintBoundary(child: CustomPaint(size: Size.infinite, painter: PortalPainter(world, prevWorld, mixT, eng, cam, intensity, density, q, frame))))),
        if (status.isNotEmpty) Center(child: Padding(padding: const EdgeInsets.all(28), child: _glass(Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 36), const SizedBox(height: 10),
          Text(status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)), const SizedBox(height: 14),
          Wrap(spacing: 10, children: [
            FilledButton(onPressed: _startEngine, child: const Text('Retry')),
            TextButton(onPressed: () => openAppSettings(), child: const Text('Open settings')),
          ]),
        ]))))),
        SafeArea(child: Column(children: [
          AnimatedOpacity(opacity: show ? 1 : 0, duration: const Duration(milliseconds: 400), child: IgnorePointer(ignoring: !show, child: _top(c))),
          const Spacer(),
          AnimatedOpacity(opacity: show ? 1 : 0, duration: const Duration(milliseconds: 400), child: IgnorePointer(ignoring: !show, child: _bottom(c))),
        ])),
      ]),
    );
  }
}

// ---------------- SOUND DNA LAB ----------------
// A living 3D sculpture of the song. It reads the real FFT (SonicEngine) and lets you shape the sound through
// Android's real equalizer, so every change is heard immediately. It shows frequency ranges, not isolated
// instruments (that would need a source-separation model), and Android gives only a mono analysis.
const dnaNames = ['Bass', 'Vocals', 'Treble', 'Warmth', 'Clarity'];
const dnaRanges = ['60 to 250 Hz', '300 Hz to 3.4 kHz', '2 to 16 kHz', '180 to 360 Hz', '3.5 to 6.5 kHz'];
const dnaAbout = [
  'Power and weight. Kicks and bass lines live here.',
  'The range where voices and lead instruments sit. It is a frequency range, not isolated vocals.',
  'Air and sparkle. Cymbals, breath and shine.',
  'Body and fullness. Too much sounds muddy, too little sounds thin.',
  'Definition and detail. Makes words and attacks easier to hear.',
];
final dnaPresets = ValueNotifier<List<Map<String, dynamic>>>([]);

Future<void> dnaSavePresets() async => (await SharedPreferences.getInstance()).setString('dna_presets', jsonEncode(dnaPresets.value));
Future<void> dnaLoadPresets(SharedPreferences sp) async {
  try {
    final j = jsonDecode(sp.getString('dna_presets') ?? '[]');
    if (j is List) { dnaPresets.value = [for (final e in j) if (e is Map) Map<String, dynamic>.from(e)]; }
  } catch (_) {}
}

String dnaCode(String name, List<double> v) =>
    'CDNA1.${base64Url.encode(utf8.encode(jsonEncode({'n': name, 'v': [for (final x in v) (x * 100).round() / 100]})))}';

// Returns {name, v} or null when the text is not a valid Sound DNA profile.
Map<String, dynamic>? dnaParse(String raw) {
  try {
    var t = raw.trim();
    if (t.startsWith('CDNA1.')) { t = utf8.decode(base64Url.decode(base64Url.normalize(t.substring(6)))); }
    final j = jsonDecode(t);
    if (j is! Map || j['v'] is! List || (j['v'] as List).length != 5) return null;
    final v = <double>[for (final x in (j['v'] as List)) m.max(-1.0, m.min(1.0, (x as num).toDouble()))];
    var n = (j['n'] ?? 'Shared profile').toString().trim();
    if (n.isEmpty) { n = 'Shared profile'; }
    if (n.length > 24) { n = n.substring(0, 24); }
    return {'name': n, 'v': v};
  } catch (_) { return null; }
}

double _wg(double f, double c, double oct) {
  final d = m.log(f / c) / m.ln2 / oct;
  return m.exp(-d * d / 2);
}

// How much each of the five controls changes one equalizer band (in dB).
double dnaBandGain(double f, List<double> v) {
  final bass = f <= 120 ? 1.0 : (f < 400 ? 1 - (f - 120) / 280 : 0.0);
  final treble = f >= 9000 ? 1.0 : (f > 4500 ? (f - 4500) / 4500 : 0.0);
  return v[0] * 9 * bass + v[1] * 7 * _wg(f, 2500, .8) + v[2] * 8 * treble + v[3] * 6 * _wg(f, 280, .7)
      + v[4] * 6 * _wg(f, 4200, .6) - v[4] * 2.5 * _wg(f, 300, .6);
}

const _dnaAnchors = [[0.0, -1.55, 0.0], [2.3, .4, 0.0], [0.0, 2.7, 0.0], [-2.3, .4, 0.0], [-1.6, -1.0, 1.7]];

class DnaPainter extends CustomPainter {
  final SonicEngine e; final _Cam cam; final List<double> vals; final List<Offset> anchors;
  final int sel, grab, mode; final bool bypass; final double q;
  DnaPainter(this.e, this.cam, this.vals, this.anchors, this.sel, this.grab, this.mode, this.bypass, this.q, Listenable repaint) : super(repaint: repaint);
  final List<double> _o = List<double>.filled(4, 0);
  final List<double> _o2 = List<double>.filled(4, 0);

  double _lvl(int i) {
    double a(int lo, int hi) { var s = 0.0; for (int k = lo; k <= hi; k++) { s += e.spec[k]; } return s / (hi - lo + 1); }
    switch (i) {
      case 0: return e.bass;
      case 1: return e.vocal;
      case 2: return e.treble;
      case 3: return a(12, 18);
      default: return a(36, 41);
    }
  }

  Paint _g(Color col, double op, double w) => Paint()
    ..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
    ..color = col.withOpacity(m.min(1.0, m.max(0.0, op)))..blendMode = BlendMode.plus;

  void _line(Canvas c, List<Offset> pts, Paint p) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) { path.lineTo(pts[i].dx, pts[i].dy); }
    c.drawPath(path, p);
  }

  @override
  void paint(Canvas c, Size s) {
    final t = e.clock, rect = Offset.zero & s;
    c.drawRect(rect, Paint()..color = Colors.black);
    cam.prep(s);
    final dim = bypass ? .55 : 1.0;
    c.drawRect(rect, Paint()..shader = RadialGradient(center: const Alignment(0, .1), radius: .9,
        colors: [const Color(0xFF3A1A80).withOpacity((.25 + .3 * e.energy) * dim), Colors.transparent]).createShader(rect));

    // BACKGROUND INSTRUMENTS: floating wire cubes around the sculpture (mids)
    for (int i = 0; i < 12; i++) {
      final a = t * (.08 + _h(i, 1) * .1) + i * .52, rad = 4.1 + 1.1 * m.sin(i * 1.7) + .35 * e.mid;
      final sz = .2 + .45 * e.spec[(i * 4) % 48] + .12 * _h(i, 2);
      final cx = rad * m.cos(a), cz = rad * m.sin(a), cy = 1.4 * m.sin(i * 2.3 + t * .2);
      final rot = t * (.3 + _h(i, 3)), cr = m.cos(rot), sr = m.sin(rot);
      final vs = <Offset>[];
      for (int k = 0; k < 8; k++) {
        final x = (k & 1 == 0 ? -1.0 : 1.0) * sz, y = (k & 2 == 0 ? -1.0 : 1.0) * sz, z = (k & 4 == 0 ? -1.0 : 1.0) * sz;
        if (cam.p(cx + x * cr + z * sr, cy + y, cz - x * sr + z * cr, _o)) { vs.add(Offset(_o[0], _o[1])); } else { vs.add(const Offset(-9999, -9999)); }
      }
      final op = (.18 + .5 * e.mid) * dim;
      for (final ed in const [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]) {
        if (vs[ed[0]].dx < -9000 || vs[ed[1]].dx < -9000) continue;
        c.drawLine(vs[ed[0]], vs[ed[1]], _g(i.isEven ? const Color(0xFF7FE9FF) : const Color(0xFFC9A8FF), op, 1.1));
      }
    }

    // BASS: thick, pulsing stacked rings in liquid metal colours
    final rings = 5;
    for (int i = 0; i < rings; i++) {
      final y = (i - 2) * .55, rr = (1.0 + .85 * e.bass + .5 * e.sub + .25 * e.kick) * (1 - .1 * (i - 2).abs()) * (1 + vals[0] * .12);
      final pts = <Offset>[];
      final segs = m.max(28, (76 * q).round());
      for (int k = 0; k <= segs; k++) {
        final a = k / segs * 6.2832, wob = 1 + .06 * m.sin(a * 3 + t * 1.5 + i) + .1 * e.spec[(k * 47 ~/ segs) % 48];
        if (!cam.p(rr * wob * m.cos(a), y, rr * wob * m.sin(a), _o)) continue;
        pts.add(Offset(_o[0], _o[1]));
      }
      if (pts.length < 3) continue;
      cam.p(0, y, 0, _o2);
      final sw = (.05 + .1 * e.bass + .06 * e.kick) * _o2[3];
      final ctr = Offset(_o2[0], _o2[1]);
      final rad = (pts[0] - ctr).distance + sw;
      final sweep = SweepGradient(colors: const [Color(0xFF8B3DFF), Color(0xFF3FE0FF), Color(0xFFFFFFFF), Color(0xFFB44DFF), Color(0xFF8B3DFF)],
          transform: GradientRotation(t * .35 + i)).createShader(Rect.fromCircle(center: ctr, radius: rad));
      final selB = sel == 0 || grab == 0;
      _line(c, pts, Paint()..style = PaintingStyle.stroke..strokeWidth = sw * 2.4..strokeCap = StrokeCap.round..blendMode = BlendMode.plus
        ..shader = sweep..color = Colors.white.withOpacity(.14 * dim));
      _line(c, pts, Paint()..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.round..blendMode = BlendMode.plus..shader = sweep);
      _line(c, pts, _g(Colors.white, (.5 + (selB ? .35 : 0)) * dim, 1.4));
    }
    if (cam.p(0, 0, 0, _o)) {
      final r = (60 + 140 * e.sub + 90 * e.kick) * _o[3] / 120, gc = Rect.fromCircle(center: Offset(_o[0], _o[1]), radius: r * 2);
      c.drawCircle(gc.center, gc.width / 2, Paint()..blendMode = BlendMode.plus..shader = RadialGradient(colors: [
        const Color(0xFFB36BFF).withOpacity((.5 + .35 * e.kick) * dim), Colors.transparent]).createShader(gc));
    }

    // VOCALS: flowing ribbons of light
    for (int rb = 0; rb < 3; rb++) {
      final pts = <Offset>[];
      final n = m.max(36, (96 * q).round());
      for (int k = 0; k <= n; k++) {
        final u = k / n, a = u * 9.4 + t * (.42 + rb * .13) + rb * 2.1;
        final rad = 2.0 + .5 * m.sin(u * 9 + t * 1.3 + rb) + (.9 * e.vocal + vals[1] * .25) * m.sin(u * 5 - t * 2.2);
        final y = (u - .5) * 3.6 + .35 * m.sin(u * 7 + t + rb);
        if (!cam.p(rad * m.cos(a), y, rad * m.sin(a), _o)) continue;
        pts.add(Offset(_o[0], _o[1]));
      }
      final lit = (.25 + .6 * e.vocal + (sel == 1 || grab == 1 ? .2 : 0)) * dim;
      _line(c, pts, _g(const Color(0xFF3FE0FF), lit * .35, 14 + 12 * e.vocal));
      _line(c, pts, _g(const Color(0xFF9BF1FF), lit * .7, 5 + 4 * e.vocal));
      _line(c, pts, _g(Colors.white, lit, 1.5));
    }

    // TREBLE: fine sparkling particles on an outer shell
    final cnt = m.min(320, (240 * q).round());
    final small = Float32List(cnt * 2), big = Float32List(cnt * 2);
    var ns = 0, nb = 0;
    final bucket = (t * 10).floor();
    for (int i = 0; i < cnt; i++) {
      final u = _h(i, 11) * 2 - 1, th = _h(i, 12) * 6.2832 + t * .05, sq = m.sqrt(1 - u * u), rad = 3.3 + _h(i, 13) * 1.4;
      if (!cam.p(rad * sq * m.cos(th), rad * u * 1.15, rad * sq * m.sin(th), _o)) continue;
      final live = _h(i, bucket) < .08 + e.treble * 1.4 + (vals[2] > 0 ? vals[2] * .2 : 0);
      if (!live) continue;
      if (_h(i, bucket + 77) > .8) { big[nb++] = _o[0]; big[nb++] = _o[1]; } else { small[ns++] = _o[0]; small[ns++] = _o[1]; }
    }
    c.drawRawPoints(PointMode.points, small.sublist(0, ns), Paint()..color = const Color(0xFFBFF4FF).withOpacity(.8 * dim)..strokeWidth = 1.8..strokeCap = StrokeCap.round..blendMode = BlendMode.plus);
    c.drawRawPoints(PointMode.points, big.sublist(0, nb), Paint()..color = Colors.white.withOpacity(.95 * dim)..strokeWidth = 4..strokeCap = StrokeCap.round..blendMode = BlendMode.plus);

    // DRUMS: shockwaves, sharp spikes on kicks, flashing triangles on snares
    for (final w in e.waves) {
      final age = e.clock - w;
      if (age < 0 || age > 2.0) continue;
      final r = .9 + age * 5.0, fade = 1 - age / 2.0, pts = <Offset>[];
      for (int i = 0; i <= 90; i++) {
        final a = i / 90 * 6.2832;
        if (!cam.p(r * m.cos(a), 0, r * m.sin(a), _o)) continue;
        pts.add(Offset(_o[0], _o[1]));
      }
      _line(c, pts, _g(const Color(0xFF7FE9FF), .85 * fade * dim, 2.6 * fade + .6));
    }
    if (e.kick > .06) {
      for (int i = 0; i < 16; i++) {
        final u = 1 - 2 * (i + .5) / 16, th = i * 2.39996, sq = m.sqrt(1 - u * u);
        final dx = sq * m.cos(th), dy = u, dz = sq * m.sin(th), r0 = .7, r1 = r0 + .8 + 2.4 * e.kick;
        if (!cam.p(dx * r0, dy * r0, dz * r0, _o) || !cam.p(dx * r1, dy * r1, dz * r1, _o2)) continue;
        c.drawLine(Offset(_o[0], _o[1]), Offset(_o2[0], _o2[1]), _g(Colors.white, e.kick * dim, 1.8));
      }
    }
    if (e.snare > .06) {
      for (int k = 0; k < 4; k++) {
        final a0 = t * .8 + k * 1.57, pts = <Offset>[];
        for (int i = 0; i <= 3; i++) {
          final a = a0 + i * 2.0944;
          if (!cam.p(2.6 * m.cos(a), (k - 1.5) * .7, 2.6 * m.sin(a), _o)) continue;
          pts.add(Offset(_o[0], _o[1]));
        }
        _line(c, pts, _g(const Color(0xFFE6D5FF), e.snare * .9 * dim, 2));
      }
    }

    // REGIONS: glowing handles with live level rings and labels
    if (mode != 2) {
      for (int i = 0; i < 5; i++) {
        final a = _dnaAnchors[i];
        if (!cam.p(a[0], a[1], a[2], _o)) { anchors[i] = const Offset(-9999, -9999); continue; }
        final ctr = Offset(_o[0], _o[1]);
        anchors[i] = ctr;
        final on = sel == i || grab == i, lvl = _lvl(i);
        c.drawCircle(ctr, 20 + (on ? 8 : 0), Paint()..color = Colors.white.withOpacity(on ? .16 : .06)..style = PaintingStyle.fill);
        c.drawArc(Rect.fromCircle(center: ctr, radius: 22 + (on ? 8 : 0)), -1.5708, 6.2832 * m.min(1.0, lvl), false, _g(const Color(0xFF7FE9FF), on ? 1 : .7, 3));
        final v = vals[i];
        if (mode == 1 && v.abs() > .02) {
          c.drawArc(Rect.fromCircle(center: ctr, radius: 30 + (on ? 8 : 0)), -1.5708, 6.2832 * v.abs() * .5, false, _g(v > 0 ? const Color(0xFFB36BFF) : const Color(0xFFFFB86B), .9, 2.4));
        }
        final tp = TextPainter(text: TextSpan(text: dnaNames[i].toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(on ? 1 : .6), fontSize: 10, letterSpacing: 2.2, fontWeight: FontWeight.w500)),
            textDirection: TextDirection.ltr)..layout();
        tp.paint(c, Offset(ctr.dx - tp.width / 2, ctr.dy + 36 + (on ? 6 : 0)));
      }
    }
    c.drawRect(rect, Paint()..shader = RadialGradient(radius: .95, colors: [Colors.transparent, Colors.black.withOpacity(.7)], stops: const [.5, 1]).createShader(rect));
  }

  @override
  bool shouldRepaint(covariant DnaPainter o) => true;
}

class SoundDnaPage extends StatefulWidget { const SoundDnaPage({super.key}); @override State<SoundDnaPage> createState() => _DNS(); }
class _DNS extends State<SoundDnaPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final eng = SonicEngine();
  final cam = _Cam();
  final frame = ValueNotifier<int>(0);
  final anchors = List<Offset>.filled(5, const Offset(-9999, -9999));
  final vals = List<double>.filled(5, 0);
  late final Ticker tk;
  Duration _last = Duration.zero;
  int mode = 0, sel = -1, grab = -1;
  bool bypass = false, _drag = false, _warned = false;
  double _acc = 0, _z0 = 7, q = 1;
  int _n = 0;
  String status = '', presetName = '';
  Timer? _applyT;
  AndroidEqualizerParameters? _ps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    cam.dist = 7.5;
    tk = createTicker(_tick)..start();
    _start();
  }

  Future<void> _start() async {
    final r = await eng.start();
    if (mounted) { setState(() => status = r == 'ok' ? '' : r); }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused) { eng.stop(); }
    if (st == AppLifecycleState.resumed) { _start(); }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _applyT?.cancel();
    tk.dispose();
    eng.stop();
    frame.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _tick(Duration d) {
    final dt = m.min(.05, (d - _last).inMicroseconds / 1e6);
    _last = d;
    if (dt <= 0) return;
    eng.tick(dt);
    if (!_drag) { cam.yaw += dt * (.04 + .08 * eng.energy); }
    _acc += dt; _n++;
    if (_n >= 45) {
      final avg = _acc / _n;
      if (avg > .024 && q > .45) { q -= .1; } else if (avg < .0175 && q < 1) { q += .05; }
      _acc = 0; _n = 0;
    }
    frame.value++;
  }

  // Sends the five controls to the real Android equalizer.
  Future<void> _apply() async {
    if (!Platform.isAndroid) return;
    try {
      _ps ??= await eq.parameters.timeout(const Duration(seconds: 3));
      final ps = _ps!;
      final flat = vals.every((x) => x.abs() < .01);
      await eq.setEnabled(!bypass && !flat ? true : (bypass ? false : eq.enabled && !flat));
      for (final b in ps.bands) {
        final g = dnaBandGain(b.centerFrequency, vals);
        await b.setGain(m.max(ps.minDecibels, m.min(ps.maxDecibels, g)));
      }
    } catch (_) {
      if (!_warned && mounted) { _warned = true; snack('Play a song first so the equalizer can attach.'); }
    }
  }

  void _schedule() { _applyT?.cancel(); _applyT = Timer(const Duration(milliseconds: 60), _apply); }

  // Saves the result to the Equalizer tab so it stays after you leave the Lab.
  Future<void> _persist() async {
    try {
      final ps = _ps;
      if (ps == null) return;
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('eqon', vals.any((x) => x.abs() >= .01));
      await sp.setStringList('eqg', ps.bands.map((b) => b.gain.toString()).toList());
    } catch (_) {}
  }

  void _setVals(List<double> v, {String name = ''}) {
    setState(() { for (int i = 0; i < 5; i++) { vals[i] = v[i]; } presetName = name; bypass = false; });
    _apply().then((_) => _persist());
  }

  int _near(Offset p, double maxD) {
    var best = -1;
    var bd = maxD;
    for (int i = 0; i < 5; i++) {
      final d = (anchors[i] - p).distance;
      if (d < bd) { bd = d; best = i; }
    }
    return best;
  }

  Widget _glass(Widget child, {double radius = 26}) => ClipRRect(borderRadius: BorderRadius.circular(radius), child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(.14))), child: child)));

  Widget _top(BuildContext c) => Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 0), child: Row(children: [
        IconButton(tooltip: 'Exit', icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(c)),
        Expanded(child: Center(child: _glass(Row(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < 3; i++) GestureDetector(
              onTap: () => setState(() => mode = i),
              child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: mode == i ? Colors.white.withOpacity(.2) : Colors.transparent),
                  child: Text(['DISCOVER', 'MANIPULATE', 'CREATE'][i], style: TextStyle(color: Colors.white.withOpacity(mode == i ? 1 : .55), fontSize: 11, letterSpacing: 1.8, fontWeight: FontWeight.w500)))),
        ]), radius: 24))),
        GestureDetector(
            onTap: () { setState(() => bypass = !bypass); _apply(); HapticFeedback.selectionClick(); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(.4)),
                    color: bypass ? Colors.white.withOpacity(.25) : Colors.transparent),
                child: Text(bypass ? 'ORIGINAL' : 'MODIFIED', style: const TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1.6)))),
      ]));

  Widget _meter(double v, Color col) => ClipRRect(borderRadius: BorderRadius.circular(3), child: SizedBox(height: 4,
      child: LinearProgressIndicator(value: m.max(0.0, m.min(1.0, v)), backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(col))));

  Widget _discover() {
    final i = sel;
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: _glass(Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (i < 0) ...[
        const Text('Tap a glowing region to inspect it', style: TextStyle(color: Colors.white, fontSize: 15)),
        const SizedBox(height: 6),
        Text('Drag to turn the sculpture. Pinch to zoom. Nothing you do here changes the sound.', style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 12)),
      ] else ...[
        Row(children: [
          Text(dnaNames[i].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 3, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text(dnaRanges[i], style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(valueListenable: frame, builder: (_, __, ___) {
          final lv = i == 0 ? eng.bass : i == 1 ? eng.vocal : i == 2 ? eng.treble : i == 3 ? (eng.spec.sublist(12, 19).reduce((a, b) => a + b) / 7) : (eng.spec.sublist(36, 42).reduce((a, b) => a + b) / 6);
          return Row(children: [Expanded(child: _meter(lv, const Color(0xFF7FE9FF))), const SizedBox(width: 10),
            Text('${(lv * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 12))]);
        }),
        const SizedBox(height: 8),
        Text(dnaAbout[i], style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 12.5)),
      ],
      const SizedBox(height: 10),
      ValueListenableBuilder<int>(valueListenable: frame, builder: (_, __, ___) => Text(
          'Bass ${(eng.bass * 100).round()}%   Mids ${(eng.mid * 100).round()}%   Treble ${(eng.treble * 100).round()}%   Energy ${(eng.energy * 100).round()}%',
          style: TextStyle(color: Colors.white.withOpacity(.8), fontSize: 11.5, letterSpacing: .4))),
      const SizedBox(height: 4),
      Text('Stereo spread is not available: Android shares a single mixed reading. Cadence shows frequency ranges and cannot isolate single instruments.',
          style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 10.5)),
    ]))));
  }

  Widget _manipulate() {
    final i = sel < 0 ? 0 : sel;
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: _glass(Padding(padding: const EdgeInsets.all(14), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Grab a glowing region and drag it up or down. You hear it right away.', style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 12.5)),
      const SizedBox(height: 10),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        for (int k = 0; k < 5; k++) Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
            onTap: () => setState(() => sel = k),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: sel == k ? Colors.white.withOpacity(.2) : Colors.white.withOpacity(.05),
                    border: Border.all(color: Colors.white.withOpacity(sel == k ? .5 : .15))),
                child: Text('${dnaNames[k]} ${vals[k] >= 0 ? '+' : ''}${(vals[k] * 9).toStringAsFixed(1)} dB', style: const TextStyle(color: Colors.white, fontSize: 11.5))))),
      ])),
      SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 2, activeTrackColor: Colors.white, inactiveTrackColor: Colors.white24, thumbColor: Colors.white),
          child: Slider(value: vals[i], min: -1, max: 1, onChanged: (v) { setState(() { vals[i] = v; sel = i; presetName = ''; }); _schedule(); }, onChangeEnd: (_) { _apply().then((_) => _persist()); })),
      Row(children: [
        TextButton.icon(onPressed: () => _setVals([0, 0, 0, 0, 0]), icon: const Icon(Icons.restart_alt_rounded, size: 18, color: Colors.white70), label: const Text('Reset', style: TextStyle(color: Colors.white70))),
        const Spacer(),
        Text('Stereo width is not available on Android', style: TextStyle(color: Colors.white.withOpacity(.4), fontSize: 10.5)),
      ]),
    ]))));
  }

  Future<void> _savePreset(BuildContext c) async {
    final n = await askText(c, 'Name this sound profile', presetName, maxLen: 24);
    if (n == null || n.trim().isEmpty) return;
    final name = n.trim();
    final list = [for (final p in dnaPresets.value) if (p['name'] != name) p];
    list.add({'name': name, 'v': [for (final x in vals) x]});
    dnaPresets.value = list;
    await dnaSavePresets();
    setState(() => presetName = name);
    snack('Saved "$name".');
  }

  Future<void> _importPreset() async {
    final d = await Clipboard.getData('text/plain');
    final p = dnaParse(d?.text ?? '');
    if (p == null) { snack('The clipboard does not hold a Sound DNA profile. Copy a share code first.'); return; }
    var name = p['name'].toString();
    while (dnaPresets.value.any((x) => x['name'] == name)) { name = '$name (2)'; }
    dnaPresets.value = [...dnaPresets.value, {'name': name, 'v': p['v']}];
    await dnaSavePresets();
    snack('Added "$name".');
  }

  void _presetMenu(BuildContext c, Map<String, dynamic> p) {
    _sheet(c, Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.play_arrow_rounded), title: const Text('Apply'), onTap: () { Navigator.pop(c); _setVals([for (final x in p['v'] as List) (x as num).toDouble()], name: p['name'].toString()); }),
      ListTile(leading: const Icon(Icons.ios_share_rounded), title: const Text('Copy share code'), onTap: () async {
        Navigator.pop(c);
        await Clipboard.setData(ClipboardData(text: dnaCode(p['name'].toString(), [for (final x in p['v'] as List) (x as num).toDouble()])));
        snack('Share code copied. Anyone with Cadence can paste it under Import.');
      }),
      ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Delete'), onTap: () async {
        Navigator.pop(c);
        dnaPresets.value = [for (final x in dnaPresets.value) if (x['name'] != p['name']) x];
        await dnaSavePresets();
      }),
    ]));
  }

  Widget _create(BuildContext c) => Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: _glass(Padding(padding: const EdgeInsets.all(14), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(presetName.isEmpty ? 'Current sound' : presetName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
          TextButton.icon(onPressed: () => _savePreset(c), icon: const Icon(Icons.bookmark_add_rounded, size: 18, color: Colors.white), label: const Text('Save', style: TextStyle(color: Colors.white))),
          TextButton.icon(onPressed: () async {
            await Clipboard.setData(ClipboardData(text: dnaCode(presetName.isEmpty ? 'My sound' : presetName, vals)));
            snack('Share code copied.');
          }, icon: const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white), label: const Text('Share', style: TextStyle(color: Colors.white))),
          TextButton.icon(onPressed: _importPreset, icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white), label: const Text('Import', style: TextStyle(color: Colors.white))),
        ]),
        const SizedBox(height: 6),
        ValueListenableBuilder<List<Map<String, dynamic>>>(valueListenable: dnaPresets, builder: (_, l, __) => l.isEmpty
            ? Text('No profiles yet. Shape the sound in Manipulate, then save it here.', style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 12.5))
            : SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                for (final p in l) Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                    onTap: () => _setVals([for (final x in p['v'] as List) (x as num).toDouble()], name: p['name'].toString()),
                    onLongPress: () => _presetMenu(c, p),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: presetName == p['name'] ? Colors.white.withOpacity(.25) : Colors.white.withOpacity(.07),
                            border: Border.all(color: Colors.white.withOpacity(presetName == p['name'] ? .6 : .18))),
                        child: Text(p['name'].toString(), style: const TextStyle(color: Colors.white, fontSize: 12.5))))),
              ]))),
        const SizedBox(height: 6),
        Text('Tap a profile to switch instantly. Long-press for share and delete. Use ORIGINAL / MODIFIED at the top to compare.', style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 10.5)),
      ]))));

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () { cam.yaw = .5; cam.pitch = .18; cam.dist = 7.5; },
              onTapUp: (d) { final k = _near(d.localPosition, 60); setState(() => sel = k); },
              onScaleStart: (d) {
                _z0 = cam.dist;
                grab = mode == 1 ? _near(d.localFocalPoint, 70) : -1;
                if (grab >= 0) { sel = grab; HapticFeedback.selectionClick(); setState(() {}); } else { _drag = true; }
              },
              onScaleUpdate: (d) {
                if (grab >= 0) {
                  vals[grab] = m.max(-1.0, m.min(1.0, vals[grab] - d.focalPointDelta.dy * .006));
                  presetName = '';
                  _schedule();
                  setState(() {});
                } else {
                  cam.yaw += d.focalPointDelta.dx * .008;
                  cam.pitch = m.max(-1.2, m.min(1.2, cam.pitch - d.focalPointDelta.dy * .006));
                  if (d.scale != 1) { cam.dist = m.max(4.0, m.min(14.0, _z0 / d.scale)); }
                }
              },
              onScaleEnd: (_) {
                if (grab >= 0) { _apply().then((_) => _persist()); }
                grab = -1; _drag = false; setState(() {});
              },
              child: RepaintBoundary(child: CustomPaint(size: Size.infinite, painter: DnaPainter(eng, cam, vals, anchors, sel, grab, mode, bypass, q, frame))))),
          if (status.isNotEmpty) Center(child: Padding(padding: const EdgeInsets.all(28), child: _glass(Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 36), const SizedBox(height: 10),
            Text(status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)), const SizedBox(height: 14),
            Wrap(spacing: 10, children: [FilledButton(onPressed: _start, child: const Text('Retry')), TextButton(onPressed: () => openAppSettings(), child: const Text('Open settings'))]),
          ]))))),
          SafeArea(child: Column(children: [
            _top(c),
            Padding(padding: const EdgeInsets.only(top: 6), child: StreamBuilder<SequenceState?>(stream: player.sequenceStateStream, builder: (_, s) {
              final t = curTrack(s.data);
              return Text(t == null ? '' : '${t.title}  -  ${t.artist}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 11.5, letterSpacing: 1));
            })),
            const Spacer(),
            mode == 0 ? _discover() : mode == 1 ? _manipulate() : _create(c),
          ])),
        ]),
      );
}

void openDna(BuildContext c) => Navigator.push(c, PageRouteBuilder<void>(
    opaque: true, transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, __, ___) => const SoundDnaPage(),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child)));

// ---------------- MUSIC PARTY ----------------
// Phones on the same Wi-Fi (or a friend's hotspot) play the same song in sync. The host's phone is the clock:
// guests measure the time difference to the host, then follow the host's play, pause, seek and song changes.
// Nothing is uploaded and no music files are copied between phones. Each phone plays its own copy of the song
// (a matching file in its library, or the same online track).
const partyPort = 48765;

Track? currentTrackNow() {
  final seq = player.sequence, i = player.currentIndex;
  if (seq == null || i == null || i < 0 || i >= seq.length) return null;
  final tag = seq[i].tag;
  return tag is MediaItem ? (lib.byPath[tag.id] ?? onlineByUrl[tag.id]) : null;
}

String _ipEnc(String ip) {
  final p = ip.split('.').map(int.parse).toList();
  final n = (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
  return n.toRadixString(36).toUpperCase();
}

String? _ipDec(String c) {
  final n = int.tryParse(c.toLowerCase(), radix: 36);
  if (n == null || n <= 0 || n > 0xFFFFFFFF) return null;
  return '${(n >> 24) & 255}.${(n >> 16) & 255}.${(n >> 8) & 255}.${n & 255}';
}

Future<String?> _myIp() async {
  final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
  String? best;
  for (final i in ifs) {
    for (final a in i.addresses) {
      final p = a.address.split('.').map(int.parse).toList();
      final priv = p[0] == 10 || (p[0] == 192 && p[1] == 168) || (p[0] == 172 && p[1] >= 16 && p[1] <= 31);
      if (!priv) continue;
      final wl = i.name.toLowerCase().contains('wlan') || i.name.toLowerCase().contains('ap');
      if (best == null || wl) { best = a.address; }
    }
  }
  return best;
}

int _nowUs() => DateTime.now().microsecondsSinceEpoch;

class PartyHub extends ChangeNotifier {
  bool hosting = false, joined = false, allowControl = false;
  String code = '', pin = '', hostName = '', missing = '', error = '', myName = 'Friend';
  double userOffsetMs = 0;
  int offsetUs = 0, rttUs = 0;
  Map<String, dynamic>? last;
  List<String> members = [];
  String loadedKey = '';

  HttpServer? _srv;
  final List<WebSocket> _clients = [];
  final Map<WebSocket, String> _names = {};
  WebSocket? _ws;
  Timer? _tHost, _tFollow, _tPing, _tDeb, _tStart;
  final List<StreamSubscription<dynamic>> _subs = [];
  final List<List<int>> _samples = [];
  bool _following = false, _loading = false;

  // ---------------- host ----------------
  Future<String?> host() async {
    try {
      await leave();
      final ip = await _myIp();
      if (ip == null) { return 'Connect to Wi-Fi first, or turn on your hotspot and have your friends join it.'; }
      _srv = await HttpServer.bind(InternetAddress.anyIPv4, partyPort, shared: true);
      pin = (1000 + m.Random().nextInt(9000)).toString();
      code = '${_ipEnc(ip)}-$pin';
      hosting = true;
      _srv!.listen(_onRequest, onError: (_) {});
      _subs.add(player.playingStream.listen((_) => _debounce()));
      _subs.add(player.positionDiscontinuityStream.listen((_) => _debounce()));
      _subs.add(player.currentIndexStream.listen((_) => _debounce()));
      _tHost = Timer.periodic(const Duration(seconds: 2), (_) => _broadcast());
      notifyListeners();
      return null;
    } catch (e) {
      hosting = false;
      return 'Could not start the party: $e';
    }
  }

  void _debounce() { _tDeb?.cancel(); _tDeb = Timer(const Duration(milliseconds: 120), _broadcast); }

  Map<String, dynamic> _snapshot() {
    final t = currentTrackNow();
    return {
      't': 'state', 'play': player.playing, 'pos': player.position.inMilliseconds, 'at': _nowUs(),
      'k': t == null ? '' : (t.path.startsWith('http') ? t.path : '${t.title}|${t.artist}|${(t.dur / 1000).round()}'),
      'trk': t == null ? null : {'u': t.path.startsWith('http') ? t.path : '', 't': t.title, 'a': t.artist, 'al': t.album, 'd': t.dur, 'c': onlineCover[t.path] ?? ''},
      'members': _names.values.toList(), 'allow': allowControl,
    };
  }

  void _broadcast() {
    if (!hosting || _clients.isEmpty) return;
    final msg = jsonEncode(_snapshot());
    for (final w in List<WebSocket>.of(_clients)) { try { w.add(msg); } catch (_) {} }
  }

  Future<void> _onRequest(HttpRequest r) async {
    try {
      if (!WebSocketTransformer.isUpgradeRequest(r)) { r.response.statusCode = 404; await r.response.close(); return; }
      final ws = await WebSocketTransformer.upgrade(r);
      var ok = false;
      ws.listen((dynamic d) {
        try {
          final j = jsonDecode(d as String) as Map;
          final t = j['t'];
          if (t == 'hello') {
            if (j['pin'].toString() != pin) { ws.add(jsonEncode({'t': 'deny'})); ws.close(); return; }
            ok = true;
            _clients.add(ws);
            _names[ws] = (j['name'] ?? 'Friend').toString();
            ws.add(jsonEncode({'t': 'welcome', 'host': myName, 'allow': allowControl}));
            members = _names.values.toList();
            ws.add(jsonEncode(_snapshot()));
            notifyListeners();
          } else if (!ok) {
            return;
          } else if (t == 'ping') {
            ws.add(jsonEncode({'t': 'pong', 'c': j['c'], 'h': _nowUs()}));
          } else if (t == 'cmd' && allowControl) {
            final c = j['c'].toString();
            if (c == 'toggle') { if (player.playing) { player.pause(); } else { player.play(); } }
            else if (c == 'next') { skipNext(); }
            else if (c == 'prev') { player.seekToPrevious(); }
          }
        } catch (_) {}
      }, onDone: () { _clients.remove(ws); _names.remove(ws); members = _names.values.toList(); notifyListeners(); },
          onError: (_) { _clients.remove(ws); _names.remove(ws); });
    } catch (_) {}
  }

  void setAllow(bool v) { allowControl = v; _broadcast(); notifyListeners(); }

  // ---------------- guest ----------------
  Future<String?> join(String raw, String name) async {
    try {
      await leave();
      myName = name.trim().isEmpty ? 'Friend' : name.trim();
      final parts = raw.trim().split(RegExp(r'[\s\-]+')).where((s) => s.isNotEmpty).toList();
      if (parts.length < 2) { return 'Enter the party code, like 1X2Y3Z-4821.'; }
      final p = parts.last;
      final first = parts.first;
      final ip = first.contains('.') ? first : _ipDec(first);
      if (ip == null) { return 'That party code is not valid.'; }
      final ws = await WebSocket.connect('ws://$ip:$partyPort').timeout(const Duration(seconds: 6));
      _ws = ws;
      ws.add(jsonEncode({'t': 'hello', 'name': myName, 'pin': p}));
      ws.listen(_onGuestMsg, onDone: () { if (joined) { error = 'The host ended the party.'; _teardownGuest(); } }, onError: (_) { _teardownGuest(); });
      for (int i = 0; i < 40 && !joined && _ws != null; i++) { await Future.delayed(const Duration(milliseconds: 100)); }
      if (!joined) { final e = error.isEmpty ? 'The host did not answer. Check the code and that you share the same Wi-Fi.' : error; await leave(); return e; }
      return null;
    } catch (e) {
      await leave();
      return 'Could not connect. Make sure you are on the same Wi-Fi as the host. ($e)';
    }
  }

  void _onGuestMsg(dynamic d) {
    try {
      final j = jsonDecode(d as String) as Map;
      final t = j['t'];
      if (t == 'welcome') {
        joined = true; hostName = (j['host'] ?? 'Host').toString(); allowControl = j['allow'] == true; error = '';
        _samples.clear();
        _ping();
        var n = 0;
        _tPing = Timer.periodic(const Duration(milliseconds: 250), (tm) { _ping(); if (++n >= 8) { tm.cancel(); _tPing = Timer.periodic(const Duration(seconds: 4), (_) => _ping()); } });
        _tFollow = Timer.periodic(const Duration(milliseconds: 500), (_) => _follow());
        notifyListeners();
      } else if (t == 'deny') {
        error = 'Wrong code or PIN.';
      } else if (t == 'pong') {
        final t1 = _nowUs(), t0 = (j['c'] as num).toInt(), h = (j['h'] as num).toInt(), r = t1 - t0;
        _samples.add([r, h - (t0 + r ~/ 2)]);
        if (_samples.length > 10) { _samples.removeAt(0); }
        var best = _samples.first;
        for (final s in _samples) { if (s[0] < best[0]) { best = s; } }
        rttUs = best[0]; offsetUs = best[1];
        notifyListeners();
      } else if (t == 'state') {
        last = Map<String, dynamic>.from(j);
        members = [for (final x in (j['members'] as List? ?? [])) x.toString()];
        allowControl = j['allow'] == true;
        notifyListeners();
        _follow();
      }
    } catch (_) {}
  }

  void _ping() { try { _ws?.add(jsonEncode({'t': 'ping', 'c': _nowUs()})); } catch (_) {} }

  void sendCmd(String c) { try { _ws?.add(jsonEncode({'t': 'cmd', 'c': c})); } catch (_) {} }

  Track? _matchLocal(Map trk) {
    final tw = _words(trk['t'].toString()), aw = _words(trk['a'].toString());
    final d = (trk['d'] as num?)?.toInt() ?? 0;
    for (final t in lib.tracks) {
      if (d > 0 && (t.dur - d).abs() > 3000) continue;
      final w = _words(t.title);
      if (w.length != tw.length || !w.containsAll(tw)) continue;
      final a = _words(t.artist);
      if (aw.isNotEmpty && a.isNotEmpty && a.intersection(aw).isEmpty) continue;
      return t;
    }
    return null;
  }

  Future<void> _ensureTrack(Map<String, dynamic> st) async {
    final key = (st['k'] ?? '').toString();
    final trk = st['trk'];
    if (key.isEmpty || trk is! Map || key == loadedKey || _loading) return;
    _loading = true;
    try {
      Track? t;
      final u = (trk['u'] ?? '').toString();
      if (u.isNotEmpty) {
        t = Track({'p': u, 't': (trk['t'] ?? 'Untitled').toString(), 'a': (trk['a'] ?? '').toString(), 'al': (trk['al'] ?? '').toString(),
          'f': 'Party', 'd': (trk['d'] as num?)?.toInt() ?? 0, 's': 0, 'ad': 0, 'prov': 'party'});
        onlineByUrl[u] = t;
        final cv = (trk['c'] ?? '').toString();
        if (cv.isNotEmpty) { onlineCover[u] = cv; }
      } else {
        t = _matchLocal(trk);
      }
      loadedKey = key;
      if (t == null) {
        missing = '"${trk['t']}" is not on this phone, so you will hear nothing until the next song.';
        await player.pause();
      } else {
        missing = '';
        await player.setAudioSource(ConcatenatingAudioSource(children: [_src(t)], shuffleOrder: NextShuffleOrder()));
      }
      notifyListeners();
    } catch (_) {
      missing = 'This song could not be loaded.';
    } finally { _loading = false; }
  }

  // Keeps this phone locked to the host: starts, pauses, seeks, and nudges the speed to remove small drift.
  Future<void> _follow() async {
    final st = last;
    if (st == null || !joined || _following) return;
    _following = true;
    try {
      await _ensureTrack(st);
      if (missing.isNotEmpty || _loading || (st['k'] ?? '').toString() != loadedKey) return;
      final hostNow = _nowUs() + offsetUs;
      final playing = st['play'] == true;
      final basePos = (st['pos'] as num).toDouble();
      final exp = playing ? basePos + (hostNow - (st['at'] as num).toInt()) / 1000.0 + userOffsetMs : basePos;
      if (!playing) {
        if (player.playing) { await player.pause(); }
        if ((player.position.inMilliseconds - exp).abs() > 120) { await player.seek(Duration(milliseconds: m.max(0, exp.round()))); }
        await player.setSpeed(1);
        return;
      }
      if (!player.playing) {
        await player.seek(Duration(milliseconds: m.max(0, exp.round())));
        await player.play();
        return;
      }
      final diff = player.position.inMilliseconds - exp;
      if (diff.abs() > 250) {
        await player.seek(Duration(milliseconds: m.max(0, exp.round())));
        await player.setSpeed(1);
      } else if (diff.abs() > 35) {
        await player.setSpeed(diff > 0 ? 1 - m.min(.04, diff.abs() / 3000) : 1 + m.min(.04, diff.abs() / 3000));
      } else {
        await player.setSpeed(1);
      }
    } catch (_) {
    } finally { _following = false; }
  }

  void setOffset(double v) { userOffsetMs = v; notifyListeners(); }

  void _teardownGuest() {
    _tPing?.cancel(); _tFollow?.cancel(); _tStart?.cancel();
    try { _ws?.close(); } catch (_) {}
    _ws = null; joined = false; last = null; loadedKey = ''; missing = '';
    try { player.setSpeed(1); } catch (_) {}
    notifyListeners();
  }

  Future<void> leave() async {
    _tHost?.cancel(); _tDeb?.cancel();
    for (final s in _subs) { await s.cancel(); }
    _subs.clear();
    for (final w in List<WebSocket>.of(_clients)) { try { await w.close(); } catch (_) {} }
    _clients.clear(); _names.clear(); members = [];
    try { await _srv?.close(force: true); } catch (_) {}
    _srv = null;
    final wasGuest = joined;
    hosting = false; code = '';
    if (_ws != null || wasGuest) { _teardownGuest(); if (wasGuest) { try { await player.pause(); } catch (_) {} } }
    notifyListeners();
  }
}
final party = PartyHub();

class PartyPage extends StatefulWidget { const PartyPage({super.key}); @override State<PartyPage> createState() => _PPS(); }
class _PPS extends State<PartyPage> {
  final codeC = TextEditingController(), nameC = TextEditingController();
  String msg = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((sp) { if (mounted) { nameC.text = sp.getString('partyName') ?? ''; } });
  }
  @override
  void dispose() { codeC.dispose(); nameC.dispose(); super.dispose(); }

  Future<void> _saveName() async => (await SharedPreferences.getInstance()).setString('partyName', nameC.text.trim());

  Widget _card(List<Widget> kids) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: th.ac.withOpacity(.09), borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids));

  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    return Scaffold(
      appBar: AppBar(title: const Text('Music Party'), backgroundColor: Colors.transparent),
      body: ListenableBuilder(listenable: party, builder: (_, __) {
        final children = <Widget>[];
        if (party.hosting) {
          children.add(_card([
            Text('YOUR PARTY', style: TextStyle(fontSize: 12, letterSpacing: 2, color: th.ac, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SelectableText(party.code, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 3)),
            const SizedBox(height: 6),
            const Text('Tell your friends this code. They open Music Party, tap Join and type it. Everyone must be on the same Wi-Fi, or on your hotspot.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: party.code)); snack('Code copied.'); }, icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('Copy code')),
              FilledButton.icon(onPressed: () async { await party.leave(); setState(() => msg = 'Party ended.'); }, icon: const Icon(Icons.stop_rounded, size: 18), label: const Text('End party')),
            ]),
          ]));
          children.add(_card([
            Text('${party.members.length} friend${party.members.length == 1 ? '' : 's'} connected', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(party.members.isEmpty ? 'Waiting for friends to join…' : party.members.join(', '), style: TextStyle(color: th.tx.withOpacity(.7))),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Friends can control playback'), subtitle: const Text('Play, pause, next and previous'),
                value: party.allowControl, onChanged: party.setAllow),
            const Text('Just play music as usual. Whatever you play is shared with everyone, in sync.', style: TextStyle(fontSize: 12.5)),
          ]));
        } else if (party.joined) {
          final trk = party.last?['trk'];
          children.add(_card([
            Text('CONNECTED TO ${party.hostName.toUpperCase()}', style: TextStyle(fontSize: 12, letterSpacing: 2, color: th.ac, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(trk is Map ? (trk['t'] ?? '').toString() : 'Waiting for the host to play something…', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            if (trk is Map) Text((trk['a'] ?? '').toString(), style: TextStyle(color: th.tx.withOpacity(.7))),
            if (party.missing.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(party.missing, style: TextStyle(color: th.ac, fontSize: 12.5))),
            const SizedBox(height: 10),
            Text('Timing: clock gap ${(party.offsetUs / 1000).round()} ms, network trip ${(party.rttUs / 1000).toStringAsFixed(0)} ms', style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.65))),
            if (party.members.isNotEmpty) Text('In the party: ${party.members.join(', ')}', style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.65))),
          ]));
          children.add(_card([
            const Text('Sync nudge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Text('If you hear an echo with a friend nearby, slide until it sounds like one voice. Bluetooth speakers usually need a nudge.', style: TextStyle(fontSize: 12.5)),
            Row(children: [
              Text('${party.userOffsetMs.round()} ms', style: const TextStyle(fontSize: 13)),
              Expanded(child: Slider(value: party.userOffsetMs, min: -400, max: 400, divisions: 160, onChanged: party.setOffset)),
            ]),
            if (party.allowControl) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(onPressed: () => party.sendCmd('prev'), icon: const Icon(Icons.skip_previous_rounded)),
              const SizedBox(width: 12),
              IconButton.filled(onPressed: () => party.sendCmd('toggle'), icon: const Icon(Icons.play_arrow_rounded), iconSize: 32),
              const SizedBox(width: 12),
              IconButton.filledTonal(onPressed: () => party.sendCmd('next'), icon: const Icon(Icons.skip_next_rounded)),
            ]),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () async { await party.leave(); }, icon: const Icon(Icons.logout_rounded, size: 18), label: const Text('Leave party'))),
          ]));
        } else {
          children.add(_card([
            const Text('Host a party', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('You choose the music. Your friends hear the same song at the same time on their own phones.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: busy ? null : () async {
              setState(() { busy = true; msg = ''; });
              final e = await party.host();
              if (mounted) { setState(() { busy = false; msg = e ?? ''; }); }
            }, icon: const Icon(Icons.celebration_rounded), label: const Text('Start a party')),
          ]));
          children.add(_card([
            const Text('Join a party', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(controller: nameC, onChanged: (_) => _saveName(), decoration: const InputDecoration(labelText: 'Your name')),
            TextField(controller: codeC, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Party code', hintText: '1X2Y3Z-4821')),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: busy ? null : () async {
              setState(() { busy = true; msg = ''; });
              final e = await party.join(codeC.text, nameC.text);
              if (mounted) { setState(() { busy = false; msg = e ?? ''; }); }
            }, icon: const Icon(Icons.login_rounded), label: Text(busy ? 'Connecting…' : 'Join')),
          ]));
        }
        if (msg.isNotEmpty) { children.add(Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 12), child: Text(msg, style: TextStyle(color: th.ac)))); }
        children.add(Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 24), child: Text(
            'How it works: your phones stay in step with the host using a shared clock, usually within a few hundredths of a second. '
            'Perfectly zero delay is not possible over Wi-Fi, so use Sync nudge for speakers. It works on one Wi-Fi or hotspot, not over the internet. '
            'Each phone needs the song: a matching file in its own library, or an online song from the Online tab. Cadence never copies music files between phones.',
            style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.6)))));
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: children);
      }),
    );
  }
}

