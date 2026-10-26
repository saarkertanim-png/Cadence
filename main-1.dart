import 'dart:async';
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
import 'library.dart';

final eq = AndroidEqualizer(), loud = AndroidLoudnessEnhancer();
final player = AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [eq, loud]));
final lib = Lib();
final themeIx = ValueNotifier<int>(0);
final showSig = ValueNotifier<bool>(true);
final msgKey = GlobalKey<ScaffoldMessengerState>();

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
];
Th get th => themes[themeIx.value];
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
  player.playbackEventStream.listen((_) {}, onError: (e, st) => snack('This file cannot be played (missing or unsupported).'));
  player.currentIndexStream.listen((_) { saveState(); _countTimer(); });
  player.playingStream.listen((_) => saveState());
  Timer.periodic(const Duration(seconds: 5), (_) { if (player.playing) saveState(); });
  runApp(const CadenceApp());
  if (Platform.isAndroid) { Future.delayed(const Duration(seconds: 2), () => Permission.notification.request()); }
}

Route<T> slideUp<T>(Widget w) => PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 450), reverseTransitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, __, ___) => w,
    transitionsBuilder: (_, a, __, c) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)), child: c));

AudioSource _src(Track t) => AudioSource.uri(Uri.file(t.path),
    tag: MediaItem(id: t.path, title: t.title, artist: t.artist, album: t.album,
        artUri: t.art == null ? null : Uri.file(t.art!), duration: t.dur > 0 ? Duration(milliseconds: t.dur) : null));

Future<void> playList(List<Track> l, int i) async {
  final src = ConcatenatingAudioSource(children: [for (final t in l) _src(t)]);
  try {
    await player.setAudioSource(src, initialIndex: i);
    player.play();
    restoreEq();
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
    await player.setAudioSource(ConcatenatingAudioSource(children: [for (final t in ts) _src(t)]),
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
    if (player.playing && player.currentIndex == i) lib.countPlay(tag.id);
  });
}

Future<void> addToQueue(Track t, {bool next = false}) async {
  final s = player.audioSource;
  if (s is! ConcatenatingAudioSource || s.length == 0) { await playList([t], 0); return; }
  try {
    if (next) { await s.insert((player.currentIndex ?? -1) + 1, _src(t)); } else { await s.add(_src(t)); }
    snack(next ? 'Will play next' : 'Added to queue');
  } catch (_) { snack('Could not add to queue.'); }
}

Future<void> playNext(Track t) => addToQueue(t, next: true);

Timer? _sl;
void sleepIn(int min) {
  _sl?.cancel();
  if (min == 0) { snack('Sleep timer off'); return; }
  snack('Music will fade out in $min min');
  _sl = Timer(Duration(minutes: min), () async {
    for (int i = 20; i >= 0; i--) { await player.setVolume(i / 20); await Future.delayed(const Duration(milliseconds: 150)); }
    await player.pause(); await player.setVolume(1);
  });
}

class CadenceApp extends StatelessWidget {
  const CadenceApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: themeIx,
      builder: (_, i, __) {
        final t = themes[i];
        final cs = ColorScheme.fromSeed(seedColor: t.ac, brightness: t.dark ? Brightness.dark : Brightness.light)
            .copyWith(primary: t.ac, onSurface: t.tx, surface: t.bg);
        final base = ThemeData(useMaterial3: true, colorScheme: cs);
        return MaterialApp(
          title: 'Cadence', debugShowCheckedModeBanner: false, scaffoldMessengerKey: msgKey,
          theme: base.copyWith(scaffoldBackgroundColor: Colors.transparent,
              textTheme: base.textTheme.apply(bodyColor: t.tx, displayColor: t.tx)),
          builder: (c, child) => Stack(children: [
            Positioned.fill(child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color.lerp(t.bg, t.bg2, .6)!, t.bg, Color.lerp(t.bg, t.bg2, .35)!])))),
            Positioned(top: -90, left: -80, child: _blob(t.ac, 300)),
            Positioned(bottom: 120, right: -120, child: _blob(t.bg2, 340)),
            child!,
          ]),
          home: const Splash(),
        );
      });
  Widget _blob(Color c, double s) => IgnorePointer(child: Container(width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withOpacity(.25), Colors.transparent]))));
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
      lib.scan();
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
          const SizedBox(height: 36),
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
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) saveState();
    if (s == AppLifecycleState.resumed) lib.scan();
  }
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (w, a) => FadeTransition(opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(.04, 0), end: Offset.zero).animate(a), child: w)),
          child: KeyedSubtree(key: ValueKey(i), child: [const LibraryPage(), const GardenPage(), const EqPage(), const SettingsPage()][i])),
      bottomNavigationBar: ClipRect(child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const MiniPlayer(),
            NavigationBar(backgroundColor: th.bg.withOpacity(.55), elevation: 0, selectedIndex: i,
                onDestinationSelected: (v) { HapticFeedback.selectionClick(); setState(() => i = v); },
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'Library'),
                  NavigationDestination(icon: Icon(Icons.local_florist_outlined), selectedIcon: Icon(Icons.local_florist), label: 'Garden'),
                  NavigationDestination(icon: Icon(Icons.equalizer_rounded), label: 'Equalizer'),
                  NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
                ]),
          ]))),
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

Track? curTrack(SequenceState? s) { final it = s?.currentSource?.tag; return it is MediaItem ? lib.byPath[it.id] : null; }

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext c) => StreamBuilder<SequenceState?>(stream: player.sequenceStateStream, builder: (_, s) {
        final t = curTrack(s.data);
        return AnimatedSize(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic,
            child: t == null ? const SizedBox(width: double.infinity) : InkWell(
                onTap: () => Navigator.push(c, slideUp(const NowPlaying())),
                child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 8, 4), child: Row(children: [
                  Hero(tag: 'art', child: Art(t, 46, 12)), const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: th.tx.withOpacity(.65))),
                  ])),
                  const PlayBtn(44),
                  IconButton(icon: const Icon(Icons.skip_next_rounded), onPressed: player.seekToNext),
                ]))));
      });
}

class LibraryPage extends StatefulWidget { const LibraryPage({super.key}); @override State<LibraryPage> createState() => _LibS(); }
class _LibS extends State<LibraryPage> {
  int tab = 0; String q = '', sort = 'title';
  List<Track> get list {
    final l = lib.tracks.where((t) => (tab != 3 || lib.favs.contains(t.path)) &&
        '${t.title} ${t.artist} ${t.album} ${t.fmt}'.toLowerCase().contains(q.toLowerCase())).toList();
    String k(Track t) => (sort == 'artist' ? t.artist : sort == 'album' ? t.album : t.title).toLowerCase();
    l.sort((a, b) => sort == 'size' ? b.size.compareTo(a.size) : sort == 'added' ? b.added.compareTo(a.added) : k(a).compareTo(k(b)));
    return l;
  }
  Widget playlistsBody(BuildContext c) {
    final most = (lib.plays.entries.where((e) => lib.byPath[e.key] != null).toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(25).map((e) => lib.byPath[e.key]!).toList();
    return ListView(key: const ValueKey('pl'), children: [
      ListTile(leading: CircleAvatar(backgroundColor: th.ac, child: const Icon(Icons.add, color: Colors.white)), title: const Text('New playlist'),
          onTap: () async { final n = await askName(c, ''); if (n != null) lib.newPlaylist(n); }),
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
        trailing: IconButton(icon: Icon(lib.favs.contains(t.path) ? Icons.favorite : Icons.favorite_border, color: th.ac),
            onPressed: () { HapticFeedback.selectionClick(); lib.toggleFav(t); }),
        onTap: () => playList(src, i),
        onLongPress: () { HapticFeedback.mediumImpact(); trackSheet(context, t); });
  }
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return ListenableBuilder(listenable: lib, builder: (c, _) {
      final l = list;
      Widget body;
      if (tab == 4) {
        body = playlistsBody(c);
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
        for (final t in l) { (g[tab == 1 ? t.album : t.artist] ??= []).add(t); }
        final keys = g.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        body = ListView(key: ValueKey('g$tab'), children: [for (final k in keys) ExpansionTile(
            leading: Art(g[k]!.first, 48, tab == 2 ? 24 : 12), title: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${g[k]!.length} songs'), shape: const Border(), collapsedShape: const Border(),
            children: [for (int i = 0; i < g[k]!.length; i++) tile(g[k]!, i, null)])]);
      }
      return SafeArea(bottom: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 8, 0), child: Row(children: [
          const Expanded(child: Text('Cadence', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: 1))),
          lib.scanning
              ? Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: th.ac)))
              : IconButton(tooltip: 'Scan device', icon: const Icon(Icons.refresh_rounded), onPressed: lib.scan),
          if (!Platform.isAndroid) IconButton(tooltip: 'Add files', icon: const Icon(Icons.add_rounded), onPressed: lib.importFiles),
          PopupMenuButton<String>(icon: const Icon(Icons.sort_rounded), onSelected: (v) => setState(() => sort = v),
              itemBuilder: (_) => [for (final s in ['title', 'artist', 'album', 'size', 'added']) PopupMenuItem(value: s, child: Text('Sort by $s'))]),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 6), child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(hintText: 'Search songs, artists, albums', prefixIcon: const Icon(Icons.search), filled: true,
                fillColor: th.bg.withOpacity(.55), border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none)))),
        SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final e in ['Songs', 'Albums', 'Artists', 'Favorites', 'Playlists'].asMap().entries)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(e.value), selected: tab == e.key,
                onSelected: (_) { HapticFeedback.selectionClick(); setState(() => tab = e.key); }))])),
        if (lib.scanning) Padding(padding: const EdgeInsets.fromLTRB(20, 2, 20, 4), child: Text('Found ${lib.found} songs…', style: const TextStyle(fontSize: 12))),
        Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: body)),
      ]));
    });
  }
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
                if (t != null) _Glass(Icons.graphic_eq_rounded, () => infoSheet(c, t)),
              ]),
              if (t != null) Align(alignment: Alignment.centerLeft, child: Container(
                  margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(border: Border.all(color: th.tx.withOpacity(.4)), borderRadius: BorderRadius.circular(20)),
                  child: Text(t.badge, style: const TextStyle(fontSize: 12)))),
              const Spacer(),
              const WaveSeek(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                StreamBuilder<bool>(stream: player.shuffleModeEnabledStream, builder: (_, s) => IconButton(
                    icon: Icon(Icons.shuffle_rounded, color: (s.data ?? false) ? th.ac : null),
                    onPressed: () async { final on = !(s.data ?? false); await player.setShuffleModeEnabled(on); if (on) await player.shuffle(); })),
                IconButton(iconSize: 38, icon: const Icon(Icons.skip_previous_rounded), onPressed: player.seekToPrevious),
                const PlayBtn(72),
                IconButton(iconSize: 38, icon: const Icon(Icons.skip_next_rounded), onPressed: player.seekToNext),
                StreamBuilder<LoopMode>(stream: player.loopModeStream, builder: (_, s) {
                  final lm = s.data ?? LoopMode.off;
                  return IconButton(icon: Icon(lm == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, color: lm == LoopMode.off ? null : th.ac),
                      onPressed: () => player.setLoopMode(LoopMode.values[(lm.index + 1) % 3]));
                }),
              ]),
              ValueListenableBuilder<bool>(valueListenable: showSig, builder: (_, on, __) => on
                  ? Padding(padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text('TanimSarker', style: GoogleFonts.greatVibes(fontSize: 22, color: th.tx.withOpacity(.55))))
                  : const SizedBox(height: 10)),
            ]))),
          ])));
    });
  }
}

void _sheet(BuildContext c, Widget w) => showModalBottomSheet(context: c, showDragHandle: true, isScrollControlled: true,
    backgroundColor: th.bg, builder: (_) => Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 28), child: w));

void moreSheet(BuildContext c, Track t) => _sheet(c, Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.info_outline), title: const Text('Audio information'), onTap: () { Navigator.pop(c); infoSheet(c, t); }),
      ListTile(leading: const Icon(Icons.playlist_add_rounded), title: const Text('Add to playlist'), onTap: () { Navigator.pop(c); pickPlaylist(c, t); }),
      ListTile(leading: const Icon(Icons.bedtime_outlined), title: const Text('Sleep timer'), onTap: () {
        Navigator.pop(c);
        _sheet(c, Wrap(spacing: 8, children: [for (final v in [0, 5, 15, 30, 45, 60]) ActionChip(label: Text(v == 0 ? 'Off' : '$v min'), onPressed: () { sleepIn(v); Navigator.pop(c); })]));
      }),
      ListTile(leading: const Icon(Icons.speed_rounded), title: const Text('Playback speed'), onTap: () {
        Navigator.pop(c);
        _sheet(c, Wrap(spacing: 8, children: [for (final v in [.75, 1.0, 1.25, 1.5, 2.0]) ActionChip(label: Text('${v}x'), onPressed: () { player.setSpeed(v); Navigator.pop(c); })]));
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

void trackSheet(BuildContext c, Track t) => _sheet(c, Column(mainAxisSize: MainAxisSize.min, children: [
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

class BloomPainter extends CustomPainter {
  final int seed; final double growth, ph; final Color base;
  BloomPainter(this.seed, this.growth, this.ph, this.base);
  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero), r = s.shortestSide / 2 * growth * (1 + .03 * m.sin(ph)), hsl = HSLColor.fromColor(base), n = 6 + seed % 6;
    c.drawCircle(ctr, r * 1.1, Paint()..color = base.withOpacity(.16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24));
    for (int layer = 0; layer < 3; layer++) {
      final col = hsl.withHue(((hsl.hue + (seed >> (layer * 3)) % 70 - 20) + 360) % 360).withLightness(m.min(1.0, .45 + layer * .12)).toColor();
      final len = r * (1 - layer * .22), wid = len * (.34 + ((seed >> 5) % 10) / 60);
      final rot = (seed % 100) / 100 * m.pi + layer * m.pi / n + ph * .05 * (layer.isEven ? 1 : -1);
      for (int k = 0; k < n; k++) {
        c.save(); c.translate(ctr.dx, ctr.dy); c.rotate(rot + k * 2 * m.pi / n);
        final p = Path()..moveTo(0, 0)..cubicTo(wid, -len * .3, wid * .8, -len * .9, 0, -len)..cubicTo(-wid * .8, -len * .9, -wid, -len * .3, 0, 0);
        c.drawPath(p, Paint()..color = col.withOpacity(.5));
        c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white.withOpacity(.35));
        c.restore();
      }
    }
    c.drawCircle(ctr, r * .09, Paint()..color = Colors.white.withOpacity(.85));
  }
  @override
  bool shouldRepaint(covariant BloomPainter o) => o.ph != ph || o.growth != growth || o.seed != seed || o.base != base;
}

String bloomStage(int n) => n >= 20 ? 'Full bloom' : n >= 10 ? 'Bloom' : n >= 5 ? 'Bud' : n >= 1 ? 'Sprout' : 'Seed';

// The big Now Playing card: real album art, or a unique flower generated from the song.
// Every song's flower grows the more you listen. Tap to flip between art and bloom.
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
                        return CustomPaint(size: Size(s, s), painter: BloomPainter(seedOf(t?.path ?? 'cadence'), .55 + .4 * m.min(1.0, plays / 20), ph, th.ac));
                      }),
                      Positioned(left: 0, right: 0, bottom: 14, child: Center(child: Text('${bloomStage(plays)} · $plays plays',
                          style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: th.tx.withOpacity(.7))))),
                    ])))
                  : KeyedSubtree(key: const ValueKey('a'), child: Art(t, s, 28))));
    });
  }
}

class GardenPage extends StatelessWidget {
  const GardenPage({super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    return SafeArea(bottom: false, child: ListenableBuilder(listenable: lib, builder: (c, _) {
      final es = lib.plays.entries.where((e) => lib.byPath[e.key] != null).toList()..sort((a, b) => b.value.compareTo(a.value));
      final total = es.fold<int>(0, (a, e) => a + e.value);
      final tracks = [for (final e in es) lib.byPath[e.key]!];
      return CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Garden', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300)),
          Text(es.isEmpty ? 'Every song you listen to grows into its own flower here.' : '${es.length} blooms · $total plays',
              style: TextStyle(color: th.tx.withOpacity(.65))),
        ]))),
        if (es.isEmpty) SliverFillRemaining(hasScrollBody: false, child: Center(child: Icon(Icons.local_florist_outlined, size: 72, color: th.ac)))
        else SliverPadding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 20), sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .86),
            itemCount: tracks.length,
            itemBuilder: (_, i) {
              final t = tracks[i], n = es[i].value;
              return InkWell(borderRadius: BorderRadius.circular(22), onTap: () => playList(tracks, i), child: Container(
                  decoration: BoxDecoration(color: th.bg.withOpacity(.5), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white54)),
                  child: Column(children: [
                    Expanded(child: RepaintBoundary(child: CustomPaint(size: Size.infinite, painter: BloomPainter(seedOf(t.path), .5 + .45 * m.min(1.0, n / 20), 0, th.ac)))),
                    Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: Column(children: [
                      Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${bloomStage(n)} · $n plays', style: const TextStyle(fontSize: 12))])),
                  ])));
            })),
      ]);
    }));
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
    return SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Equalizer', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300)), const SizedBox(height: 12), body]));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext c) {
    Theme.of(c);
    return SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Settings', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300)), const SizedBox(height: 16),
      const Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [for (int i = 0; i < themes.length; i++) GestureDetector(
          onTap: () async { themeIx.value = i; HapticFeedback.selectionClick(); (await SharedPreferences.getInstance()).setInt('theme', i); },
          child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: themes[i].bg, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: themeIx.value == i ? themes[i].ac : Colors.black12, width: 2)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(radius: 7, backgroundColor: themes[i].ac), const SizedBox(width: 8),
                Text(themes[i].n, style: TextStyle(color: themes[i].tx))])))]),
      const SizedBox(height: 12),
      ValueListenableBuilder<bool>(valueListenable: showSig, builder: (_, on, __) => SwitchListTile(
          secondary: const Icon(Icons.draw_outlined), title: const Text('Show signature'),
          subtitle: const Text('The small "TanimSarker" script on the player'), value: on,
          onChanged: (v) async { showSig.value = v; HapticFeedback.selectionClick(); (await SharedPreferences.getInstance()).setBool('sig', v); })),
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
