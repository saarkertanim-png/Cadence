import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const exts = {'mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'aif', 'aiff'};

class Track {
  final Map j;
  Track(this.j);
  String get path => j['p'];
  String get title => j['t'];
  String get artist => j['a'];
  String get album => j['al'];
  String get fmt => j['f'];
  int get dur => j['d'];
  int get size => j['s'];
  int get added => j['ad'];
  String? get art => j['ar'];
  int get sr => j['sr'] ?? 0;
  int get bd => j['bd'] ?? 0;
  int get ch => j['ch'] ?? 0;
  String? get codec => j['c'];
  bool? get lossless => j['ll'];
  String get badge => [
        fmt,
        sr > 0 ? (sr % 1000 == 0 ? '${sr ~/ 1000} kHz' : '${sr / 1000} kHz') : null,
        bd > 0 ? '$bd-bit' : null,
        lossless == true ? 'Lossless' : lossless == false ? 'Lossy' : null
      ].whereType<String>().join(' · ');
}

int seedOf(String s) {
  int x = 2166136261;
  for (final c in s.codeUnits) {
    x = ((x ^ c) * 16777619) & 0xFFFFFFFF;
  }
  return x;
}

String _h(String s) {
  int x = 2166136261;
  for (final c in s.codeUnits) {
    x = ((x ^ c) * 16777619) & 0xFFFFFFFF;
  }
  return x.toRadixString(16);
}

// Runs in a background isolate so scanning never janks the UI.
Map<String, dynamic> readOne(List a) {
  final path = a[0] as String, artDir = a[1] as String;
  final f = File(path);
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  final ext = dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  final j = <String, dynamic>{
    'p': path, 't': dot > 0 ? name.substring(0, dot) : name, 'a': 'Unknown artist',
    'al': 'Unknown album', 'f': ext.toUpperCase(), 'd': 0, 's': f.lengthSync(),
    'ad': DateTime.now().millisecondsSinceEpoch,
  };
  try {
    final md = readMetadata(f, getImage: true);
    if ((md.title ?? '').isNotEmpty) j['t'] = md.title;
    if ((md.artist ?? '').isNotEmpty) j['a'] = md.artist;
    if ((md.album ?? '').isNotEmpty) j['al'] = md.album;
    if (md.duration != null) j['d'] = md.duration!.inMilliseconds;
    if (md.pictures.isNotEmpty) {
      final o = File('$artDir/${_h(path)}.jpg');
      o.writeAsBytesSync(md.pictures.first.bytes);
      j['ar'] = o.path;
    }
  } catch (_) {}
  try {
    final r = f.openSync();
    final u = r.readSync(65536);
    r.closeSync();
    if (u.length > 40 && String.fromCharCodes(u.sublist(0, 4)) == 'fLaC') {
      const x = 8; // STREAMINFO is always the first block
      final sr = (u[x + 10] << 12) | (u[x + 11] << 4) | (u[x + 12] >> 4);
      j['c'] = 'FLAC'; j['ll'] = true; j['sr'] = sr;
      j['ch'] = ((u[x + 12] >> 1) & 7) + 1;
      j['bd'] = (((u[x + 12] & 1) << 4) | (u[x + 13] >> 4)) + 1;
      final n = (u[x + 13] & 15) * 4294967296 + ((u[x + 14] << 24) | (u[x + 15] << 16) | (u[x + 16] << 8) | u[x + 17]);
      if (j['d'] == 0 && sr > 0) j['d'] = (n * 1000 / sr).round();
    } else if (u.length > 40 && String.fromCharCodes(u.sublist(0, 4)) == 'RIFF') {
      int p = 12;
      while (p + 24 < u.length) {
        final id = String.fromCharCodes(u.sublist(p, p + 4));
        final l = u[p + 4] | (u[p + 5] << 8) | (u[p + 6] << 16) | (u[p + 7] << 24);
        if (id == 'fmt ') {
          j['ch'] = u[p + 10] | (u[p + 11] << 8);
          j['sr'] = u[p + 12] | (u[p + 13] << 8) | (u[p + 14] << 16) | (u[p + 15] << 24);
          j['bd'] = u[p + 22] | (u[p + 23] << 8);
          j['c'] = 'PCM (WAV)'; j['ll'] = true;
          break;
        }
        p += 8 + l + (l & 1);
      }
    } else if (ext == 'mp3') {
      j['c'] = 'MP3'; j['ll'] = false;
    }
  } catch (_) {}
  return j;
}

class Lib extends ChangeNotifier {
  List<Track> tracks = [];
  final byPath = <String, Track>{};
  Set<String> favs = {};
  Map<String, List<String>> playlists = {};
  Map<String, int> plays = {};
  bool scanning = false;
  int found = 0;
  String? msg;
  late Directory docs;
  late String artDir;

  Future<void> load() async {
    docs = await getApplicationDocumentsDirectory();
    artDir = '${docs.path}/art';
    Directory(artDir).createSync(recursive: true);
    final f = File('${docs.path}/lib.json');
    if (f.existsSync()) {
      try { tracks = (jsonDecode(f.readAsStringSync()) as List).map((e) => Track(e as Map)).toList(); } catch (_) {}
    }
    final p = await SharedPreferences.getInstance();
    favs = (p.getStringList('fav') ?? []).toSet();
    try {
      playlists = (jsonDecode(p.getString('pl') ?? '{}') as Map).map((k, v) => MapEntry(k as String, (v as List).cast<String>().toList()));
      plays = (jsonDecode(p.getString('plays') ?? '{}') as Map).map((k, v) => MapEntry(k as String, v as int));
    } catch (_) {}
    _idx();
    notifyListeners();
  }

  void _idx() => byPath..clear()..addEntries(tracks.map((t) => MapEntry(t.path, t)));

  Future<void> toggleFav(Track t) async {
    favs.contains(t.path) ? favs.remove(t.path) : favs.add(t.path);
    (await SharedPreferences.getInstance()).setStringList('fav', favs.toList());
    notifyListeners();
  }

  Future<List<String>> _roots() async {
    final imp = '${docs.path}/imported';
    Directory(imp).createSync(recursive: true);
    if (!Platform.isAndroid) return [docs.path];
    var s = await Permission.audio.request();
    if (!s.isGranted) s = await Permission.storage.request();
    if (!s.isGranted) {
      msg = 'Allow music access to find songs on this device (Settings > Apps > Cadence > Permissions).';
      return [imp];
    }
    return ['/storage/emulated/0', imp];
  }

  Future<void> scan() async {
    if (scanning) return;
    scanning = true; found = 0; msg = null;
    notifyListeners();
    final paths = <String>[];
    for (final r in await _roots()) {
      final d = Directory(r);
      if (!d.existsSync()) continue;
      await for (final e in d.list(recursive: true, followLinks: false).handleError((_) {})) {
        if (e is! File) continue;
        final p = e.path, i = p.lastIndexOf('.');
        if (p.contains('/Android/') || p.contains('/.') || i < 0) continue;
        if (exts.contains(p.substring(i + 1).toLowerCase())) paths.add(p);
      }
    }
    final old = {for (final t in tracks) t.path: t};
    final out = <Track>[];
    final ad = artDir;
    for (final p in paths) {
      Track? t = old[p];
      if (t == null || t.size != File(p).lengthSync()) {
        try { t = Track(await Isolate.run(() => readOne([p, ad]))); } catch (_) { continue; }
      }
      out.add(t);
      if (out.length % 8 == 0) { found = out.length; tracks = [...out]; _idx(); notifyListeners(); }
    }
    out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    tracks = out; found = out.length; scanning = false; _idx();
    if (out.isEmpty && msg == null) msg = 'No music files found yet.';
    File('${docs.path}/lib.json').writeAsStringSync(jsonEncode(out.map((t) => t.j).toList()));
    notifyListeners();
  }

  Future<void> _savePl() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('pl', jsonEncode(playlists));
    await p.setString('plays', jsonEncode(plays));
    notifyListeners();
  }
  Future<void> newPlaylist(String n) async { n = n.trim(); if (n.isEmpty || playlists.containsKey(n)) return; playlists[n] = []; await _savePl(); }
  Future<void> delPlaylist(String n) async { playlists.remove(n); await _savePl(); }
  Future<void> renamePlaylist(String o, String n) async {
    n = n.trim();
    if (n.isEmpty || playlists.containsKey(n)) return;
    playlists = {for (final e in playlists.entries) (e.key == o ? n : e.key): e.value};
    await _savePl();
  }
  Future<void> addTo(String n, String path) async { final l = playlists[n]; if (l == null || l.contains(path)) return; l.add(path); await _savePl(); }
  Future<void> removeFrom(String n, String path) async { playlists[n]?.remove(path); await _savePl(); }
  Future<void> move(String n, int a, int b) async { final l = playlists[n]!; if (b > a) b--; l.insert(b, l.removeAt(a)); await _savePl(); }
  Future<void> countPlay(String path) async { plays[path] = (plays[path] ?? 0) + 1; await _savePl(); }
  List<Track> plTracks(String n) => [for (final p in playlists[n] ?? <String>[]) if (byPath[p] != null) byPath[p]!];

  Future<void> importFiles() async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.audio);
    if (r == null) return;
    final d = Directory('${docs.path}/imported')..createSync(recursive: true);
    for (final f in r.files) {
      if (f.path == null) continue;
      try { await File(f.path!).copy('${d.path}/${f.name}'); } catch (_) {}
    }
    await scan();
  }
}
