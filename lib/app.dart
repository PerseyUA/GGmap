import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/map_screen.dart';

class GgmapApp extends StatelessWidget {
  const GgmapApp({super.key});

  static const _seed = Color(0xFF2E7D6B);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GGMap',
      debugShowCheckedModeBanner: false,
      locale: const Locale('uk'),
      supportedLocales: const [Locale('uk')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
