import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
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
Future<String?> askText(BuildContext c, String title, String init, {bool number = false}) {
  final tc = TextEditingController(text: init);
  return showDialog<String>(context: c, builder: (d) => AlertDialog(title: Text(title),
      content: TextField(controller: tc, autofocus: true, maxLength: 30, keyboardType: number ? TextInputType.number : TextInputType.text),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, tc.text), child: const Text('Save'))]));
}
final glassSkin = ValueNotifier<bool>(true);
final skin = ValueNotifier<int>(0);
// ---- streaming from the user's own GitHub repo ----
final repoLink = ValueNotifier<String?>(null);
final onlineTracks = ValueNotifier<List<Track>>([]);
final onlineByUrl = <String, Track>{};
final onlineCover = <String, String>{};
final onlineBusy = ValueNotifier<bool>(false);

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

Future<bool> connectRepo(String raw, {bool quiet = false}) async {
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
    for (final e in (tj['tree'] as List)) {
      if (e is! Map || e['type'] != 'blob') continue;
      final path = e['path'].toString();
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
    onlineCover.clear();
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
      final t = Track({'p': u, 't': title, 'a': artist, 'al': folder, 'f': '$ext · Online', 'd': 0, 's': (e['size'] is int) ? e['size'] : 0, 'ad': 0});
      out.add(t);
      byUrl[u] = t;
    }
    out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    onlineByUrl..clear()..addAll(byUrl);
    onlineTracks.value = out;
    repoLink.value = 'https://github.com/${rf.o}/${rf.r}';
    (await SharedPreferences.getInstance()).setString('repo', repoLink.value!);
    if (!quiet) { snack(out.isEmpty ? 'Connected, but no songs were found. Upload mp3 or flac files to the repo, then tap refresh.' : 'Connected. ${out.length} songs ready to stream.'); }
    return true;
  } catch (_) {
    if (!quiet) snack('Could not connect. Check your internet connection and try again.');
    return false;
  } finally { onlineBusy.value = false; }
}

Future<void> disconnectRepo() async {
  repoLink.value = null;
  onlineTracks.value = [];
  onlineByUrl.clear();
  onlineCover.clear();
  (await SharedPreferences.getInstance()).remove('repo');
}

Future<void> repoDialog(BuildContext c) async {
  final tc = TextEditingController(text: repoLink.value ?? '');
  final r = await showDialog<String>(context: c, builder: (d) => AlertDialog(
      title: const Text('Connect your GitHub repo'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: tc, autofocus: true, keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: 'https://github.com/user/repo')),
        const SizedBox(height: 10),
        const Text('The repo must be public and hold your songs (mp3, flac, m4a, ogg, opus, wav). Name files like "Artist - Title.mp3". A picture with the same name, or cover.jpg in the folder, becomes the cover.', style: TextStyle(fontSize: 12)),
      ]),
      actions: [
        if (repoLink.value != null) TextButton(onPressed: () => Navigator.pop(d, ''), child: const Text('Disconnect')),
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, tc.text), child: const Text('Connect')),
      ]));
  if (r == null) return;
  if (r.isEmpty) { await disconnectRepo(); snack('Disconnected.'); } else { await connectRepo(r); }
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
  final savedRepo = sp.getString('repo');
  if (savedRepo != null) { repoLink.value = savedRepo; connectRepo(savedRepo, quiet: true); }
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
      snack('Check: notifications ${n.isGranted ? "ON" : "OFF"} - battery ${b ? "OK" : "restricted"} - build 22');
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
    if (player.playing && player.currentIndex == i) { lib.countPlay(tag.id); recentAdd(tag.id); final tr = lib.byPath[tag.id]; if (tr != null) diaryAdd(tr); }
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
          Text('build 22', style: TextStyle(fontSize: 11, color: th.tx.withOpacity(.4))),
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
    return ClipRRect(borderRadius: BorderRadius.circular(r), child: SizedBox(width: s, height: s,
        child: t?.art != null
            ? Image.file(File(t!.art!), fit: BoxFit.cover, gaplessPlayback: true,
                cacheWidth: (s * MediaQuery.devicePixelRatioOf(c)).round(), errorBuilder: (_, __, ___) => ph)
            : ph));
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

// ---------------- Online (your GitHub repo) ----------------
class OnlinePage extends StatefulWidget { const OnlinePage({super.key}); @override State<OnlinePage> createState() => _OnS(); }
class _OnS extends State<OnlinePage> {
  String q = '';
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    return SafeArea(bottom: false, child: ValueListenableBuilder<List<Track>>(valueListenable: onlineTracks, builder: (_, all, __) {
      final link = repoLink.value;
      final f = [for (final t in all) if ('${t.title} ${t.artist} ${t.album}'.toLowerCase().contains(q.toLowerCase())) t];
      final bottom = MediaQuery.paddingOf(c).bottom;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 8, 0), child: Row(children: [
          const Expanded(child: Text('Online', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: 1))),
          ValueListenableBuilder<bool>(valueListenable: onlineBusy, builder: (_, busy, __) => busy
              ? Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: th.ac)))
              : IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded), onPressed: link == null ? null : () => connectRepo(link))),
          IconButton(tooltip: 'Connect repo', icon: const Icon(Icons.link_rounded), onPressed: () => repoDialog(c)),
        ])),
        if (link == null)
          Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_outlined, size: 64, color: th.ac), const SizedBox(height: 12),
            const Text('Stream from your repo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
            const Text('Connect a public GitHub repo that holds your songs, and play them online. Your local music stays in the Library tab.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => repoDialog(c), icon: const Icon(Icons.link_rounded), label: const Text('Connect repo')),
          ]))))
        else ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 6), child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(hintText: 'Search online songs', prefixIcon: const Icon(Icons.search), filled: true,
                  fillColor: th.bg.withOpacity(.55), border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none)))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('${all.length} songs · ${link.replaceFirst('https://github.com/', '')}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.65)))),
          if (all.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 6), child: Row(children: [
            FilledButton.icon(onPressed: () => playList(f.isEmpty ? all : f, 0), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Play all')),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: () { final l = [...(f.isEmpty ? all : f)]..shuffle(); playList(l, 0); },
                icon: const Icon(Icons.shuffle_rounded), label: const Text('Shuffle')),
          ])),
          Expanded(child: f.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(
                  all.isEmpty ? 'No songs found in this repo yet. Upload mp3 or flac files, then tap refresh.' : 'No matches.', textAlign: TextAlign.center)))
              : ListView.builder(padding: EdgeInsets.only(bottom: bottom), itemCount: f.length, itemBuilder: (_, i) {
                  final t = f[i];
                  return ListTile(leading: Art(t, 48, 12),
                      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${t.artist} · ${t.badge}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      trailing: ListenableBuilder(listenable: lib, builder: (_, __) => IconButton(
                          icon: Icon(lib.favs.contains(t.path) ? Icons.favorite : Icons.favorite_border, color: th.ac),
                          onPressed: () { HapticFeedback.selectionClick(); lib.toggleFav(t); })),
                      onTap: () => playList(f, i),
                      onLongPress: () { HapticFeedback.mediumImpact(); trackSheet(c, t); });
                })),
        ],
      ]);
    }));
  }
}
