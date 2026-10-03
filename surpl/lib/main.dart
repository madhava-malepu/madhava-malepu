import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';

import 'backend/firebase/firebase_config.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/nav/nav.dart';
import 'services/notification_service.dart';
import 'index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  // Global safety net: if any widget anywhere in the app throws during
  // build (a bug, unexpected null, anything), Flutter's default is a
  // red screen showing the raw error type, file, and stack trace -
  // exactly the kind of technical, non-branded content that shouldn't
  // ever reach a real user. This replaces that with a clean, branded
  // fallback everywhere in the app, automatically, without needing to
  // find and wrap every individual screen.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: const Color(0xFFF5F8F5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sentiment_dissatisfied_rounded,
            size: 40, color: Color(0xFF1A4731)),
          const SizedBox(height: 12),
          const Text('Something went wrong',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: Color(0xFF1A4731))),
          const SizedBox(height: 4),
          const Text('Please try again in a moment',
            style: TextStyle(fontSize: 12, color: Color(0xFF4D6B57))),
        ],
      ),
    );
  };

  // Log the real error for debugging (visible only in your own console,
  // never to the user) instead of letting Flutter's default handler
  // print/display it in a way that could surface technical details.
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Surpl internal error (not shown to user): ${details.exception}');
  };

  await initFirebase();
  await FlutterFlowTheme.initialize();
  await NotificationService.init();

  final appState = FFAppState();
  await appState.initializePersistedState();

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;
  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  late Stream<BaseAuthUser> userStream;

  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.path;
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();

  @override
  void initState() {
    super.initState();
    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = surplFirebaseUserStream()
      ..listen((user) => _appStateNotifier.update(user));
    jwtTokenStream.listen((_) {});
    Future.delayed(
      const Duration(milliseconds: 1000),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  static const _green = Color(0xFF1a4731);
  static const _amber = Color(0xFFf5a623);
  static const _lightGreen = Color(0xFFE8F5EE);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Surpl',
      // Clamp system text scaling app-wide. Many phones (especially
      // several popular Indian Android brands) ship with larger default
      // font sizes, and some users increase it further for readability.
      // Without a clamp, that can overflow fixed-size containers and
      // overlap other elements on screens that weren't built to expand —
      // this is a major source of "looks broken on some phones" bugs.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(
              mq.textScaler.scale(1.0).clamp(0.9, 1.15),
            ),
          ),
          child: child!,
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
        primaryColor: _green,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1a4731),
          secondary: Color(0xFFf5a623),
          surface: Color(0xFFF5F8F5),
          background: Color(0xFFF5F8F5),
          onPrimary: Colors.white,
          onSecondary: Color(0xFF1a4731),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F8F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1a4731),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFd4e8d4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFd4e8d4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF1a4731), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFd4e8d4), width: 0.5),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _lightGreen,
          selectedColor: _green,
          labelStyle: const TextStyle(
              color: Color(0xFF1a4731),
              fontWeight: FontWeight.w600,
              fontSize: 12),
          secondaryLabelStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1a4731),
          unselectedItemColor: Color(0xFF9aaa9a),
          selectedLabelStyle:
              TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle:
              TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          elevation: 12,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Color(0x99FFFFFF),
          indicatorColor: Color(0xFFf5a623),
          labelStyle:
              TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle:
              TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFf5a623),
          foregroundColor: Colors.white,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: Color(0xFF1a4731)),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1a4731),
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        dividerTheme: const DividerThemeData(
            color: Color(0xFFd4e8d4), thickness: 0.5),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
      ),
      // Locked to light mode always. The app's screens use hardcoded
      // light-mode colors throughout (not theme-derived), and the dark
      // theme above has no real color definitions of its own — so on any
      // phone with system dark mode on, Flutter was filling gaps with its
      // own generic dark defaults while hardcoded widgets stayed light,
      // causing scattered contrast/color mismatches across many screens.
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}