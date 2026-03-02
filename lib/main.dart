import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TransportKidApp());
}

class TransportKidApp extends StatefulWidget {
  const TransportKidApp({super.key});

  @override
  State<TransportKidApp> createState() => _TransportKidAppState();
}

class _TransportKidAppState extends State<TransportKidApp> {
  @override
  void initState() {
    super.initState();
    ThemeProvider.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeProvider.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {
    final isDark = ThemeProvider.instance.isDark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark
            ? const Color(0xFF0C0120)
            : const Color(0xFFF8FAFC),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TransportKid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeProvider.instance.mode,
      routerConfig: appRouter,
    );
  }
}
