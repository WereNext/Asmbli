import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/color_schemes.dart';
import 'features/mvp/mvp.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if setup is complete to determine initial route
  final prefs = await SharedPreferences.getInstance();
  final setupComplete = prefs.getBool('mvp_setup_complete') ?? false;

  runApp(
    ProviderScope(
      child: MvpApp(initialRoute: setupComplete ? '/mvp/chat' : '/mvp'),
    ),
  );
}

/// MVP Theme state
class MvpThemeState {
  final ThemeMode mode;
  final String colorScheme;

  const MvpThemeState({
    this.mode = ThemeMode.dark,
    this.colorScheme = AppColorSchemes.warmNeutral,
  });

  MvpThemeState copyWith({ThemeMode? mode, String? colorScheme}) {
    return MvpThemeState(
      mode: mode ?? this.mode,
      colorScheme: colorScheme ?? this.colorScheme,
    );
  }
}

/// MVP Theme notifier using SharedPreferences
class MvpThemeNotifier extends StateNotifier<MvpThemeState> {
  static const String _themeModeKey = 'mvp_theme_mode';
  static const String _colorSchemeKey = 'mvp_color_scheme';

  MvpThemeNotifier() : super(const MvpThemeState()) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString(_themeModeKey) ?? 'dark';
    final colorScheme = prefs.getString(_colorSchemeKey) ?? AppColorSchemes.warmNeutral;

    state = MvpThemeState(
      mode: _modeFromString(modeString),
      colorScheme: colorScheme,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _modeToString(mode));
  }

  Future<void> setColorScheme(String colorScheme) async {
    state = state.copyWith(colorScheme: colorScheme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorSchemeKey, colorScheme);
  }

  ThemeMode _modeFromString(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  String _modeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

/// Provider for MVP theme
final mvpThemeProvider = StateNotifierProvider<MvpThemeNotifier, MvpThemeState>(
  (ref) => MvpThemeNotifier(),
);

class MvpApp extends ConsumerWidget {
  final String initialRoute;

  const MvpApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(mvpThemeProvider);

    return MaterialApp.router(
      title: 'Asmbli MVP',
      debugShowCheckedModeBanner: false,
      theme: AppColorSchemes.getTheme(themeState.colorScheme, false),
      darkTheme: AppColorSchemes.getTheme(themeState.colorScheme, true),
      themeMode: themeState.mode,
      routerConfig: GoRouter(
        initialLocation: initialRoute,
        routes: [
          GoRoute(
            path: '/mvp',
            builder: (context, state) => const MvpWelcomeScreen(),
          ),
          GoRoute(
            path: '/mvp/setup',
            builder: (context, state) => const MvpSetupScreen(),
          ),
          GoRoute(
            path: '/mvp/chat',
            builder: (context, state) => const MvpChatScreen(),
          ),
          GoRoute(
            path: '/mvp/settings',
            builder: (context, state) => const MvpSettingsScreen(),
          ),
        ],
      ),
    );
  }
}
