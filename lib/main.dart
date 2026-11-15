import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:wash_live/wash_live.dart';

import 'ha.dart';
import 'l10n.dart';
import 'models.dart';
import 'notifications.dart';
import 'screens/home_screen.dart';
import 'screens/machine_flow.dart';
import 'store.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  t = S.fromSystem();
  C.dark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  await Notifier.instance.init();
  await HomeAssistant.load();
  final store = await WashStore.load();

  // Tipp auf eine Erinnerung, die „läuft“-Anzeige oder einen ihrer Buttons.
  Future<void> open(Machine m, String? action) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    if (action == Notifier.actionOverview || store.run(m) == null) return;
    if (action == Notifier.actionFinish) await store.finishNow(m);
    nav.push(MaterialPageRoute(builder: (_) => MachineFlow(machine: m)));
  }

  Notifier.instance.onOpen = open;
  WashLive.init();
  WashLive.onOpen = (machine, action) {
    for (final m in Machine.values) {
      if (m.name == machine) open(m, action);
    }
  };

  final shortcuts = _Shortcuts(store);
  WashLive.onStartLink = shortcuts.startFromLink;

  runApp(StoreScope(store: store, child: WashApp(onLocaleChanged: shortcuts.sync)));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Notifier.instance.consumeLaunch();
    WashLive.consumeLaunch();
    shortcuts.init();
  });
}

/// Schnellstart über das App-Icon (lange drücken) und über Links bzw.
/// NFC-Sticker: startet den Timer sofort.
class _Shortcuts {
  _Shortcuts(this.store);

  final WashStore store;
  final _qa = const QuickActions();
  String _last = '';

  void init() {
    _qa.initialize(_handle);
    sync();
    store.addListener(sync);
  }

  /// Kurzbefehle neu setzen (Programme oder Sprache geändert).
  void sync() {
    final items = <ShortcutItem>[
      for (final m in Machine.values)
        for (var i = 0; i < 2; i++)
          ShortcutItem(
            type: 'start:${m.name}:$i',
            localizedTitle: t.shortcut(m, store.programs(m)[i].name),
            icon: m == Machine.wash ? 'ic_shortcut_wash' : 'ic_shortcut_dry',
          ),
    ];
    final key = items.map((e) => e.localizedTitle).join('|');
    if (key == _last) return;
    _last = key;
    _qa.setShortcutItems(items);
  }

  Future<void> _handle(String type) async {
    final parts = type.split(':');
    if (parts.length != 3 || parts[0] != 'start') return;
    final m = Machine.values.where((x) => x.name == parts[1]).firstOrNull;
    final i = int.tryParse(parts[2]);
    if (m == null || i == null || i < 0 || i > 1) return;
    await start(m, program: i);
  }

  /// Link bzw. NFC-Sticker: `wash://start?machine=wash&program=1` (1 oder 2)
  /// oder `&minutes=90` (optional `&name=…`).
  void startFromLink(String machine, {int? program, int? minutes, String? name}) {
    final m = Machine.values.where((x) => x.name == machine).firstOrNull;
    if (m == null) return;
    if (minutes != null && minutes > 0 && minutes <= 600) {
      start(m, minutes: minutes, name: name);
    } else {
      start(m, program: ((program ?? 1) - 1).clamp(0, 1));
    }
  }

  /// Startet sofort – außer die Maschine läuft schon, dann nur anzeigen.
  Future<void> start(Machine m, {int program = 0, int? minutes, String? name}) async {
    final nav = navigatorKey.currentState;
    final running = store.run(m);
    if (running != null && !running.isDone(DateTime.now())) {
      // Läuft schon – nichts überschreiben, nur anzeigen.
      nav?.popUntil((r) => r.isFirst);
      nav?.push(MaterialPageRoute(builder: (_) => MachineFlow(machine: m)));
      return;
    }
    final p = minutes != null ? Program(name ?? t.customTime, minutes) : store.programs(m)[program];
    final run = await store.start(m, p.name, p.minutes);
    HapticFeedback.mediumImpact();
    nav?.popUntil((r) => r.isFirst);
    messengerKey.currentState?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.ink,
      shape: const StadiumBorder(),
      content: Text(t.startedSnack(p.name, formatClock(run.end)),
          style: font(size: 15, weight: FontWeight.w600, color: C.white)),
    ));
  }
}

class WashApp extends StatefulWidget {
  const WashApp({super.key, this.onLocaleChanged});

  /// Für alles außerhalb der Widgets, das die Sprache kennt (Schnellstart).
  final VoidCallback? onLocaleChanged;

  @override
  State<WashApp> createState() => _WashAppState();
}

/// Folgt der Sprache des Systems (bzw. der für die App gewählten Sprache) –
/// auch wenn sie sich ändert, während die App läuft.
class _WashAppState extends State<WashApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final next = S.forLocale(locales?.firstOrNull);
    if (identical(next, t)) return;
    t = next;
    _rebuildAll();
    Notifier.instance.refreshChannels();
    widget.onLocaleChanged?.call();
  }

  @override
  void didChangePlatformBrightness() {
    final dark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    if (dark == C.dark) return;
    C.dark = dark;
    _rebuildAll();
  }

  /// Texte und Farben werden beim Bauen gelesen – nach einem Wechsel von
  /// Sprache oder Hell/Dunkel also den ganzen Baum neu bauen (auch
  /// const-Widgets), ohne den Navigationsstand zu verlieren.
  void _rebuildAll() {
    setState(() {});
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (C.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent),
      child: MaterialApp(
        title: 'wa:sh',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        theme: buildTheme(),
        locale: Locale(t.code),
        supportedLocales: S.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Große Schrift wird unterstützt, aber begrenzt – die großen
        // Überschriften und Kacheln bleiben so lesbar statt überzulaufen.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1, maxScaleFactor: 1.3)),
            child: child!,
          );
        },
        home: const HomeScreen(),
      ),
    );
  }
}
