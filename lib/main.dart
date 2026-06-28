// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/login_screen.dart';
import 'screens/calculator_screen.dart';
import 'screens/admin_screen.dart';
import 'services/gold_price_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GoldPriceService _goldService = GoldPriceService();

  @override
  void initState() {
    super.initState();
    // Fetch latest prices immediately on app start (no user interaction)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _goldService.fetchLatestPrices();
      } catch (e) {
        // ignore: avoid_print
        print('Failed to fetch initial prices: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حاسبة الصاغة المصرية',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar')],
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37),
          secondary: Color(0xFFD4AF37),
        ),
        primaryColor: const Color(0xFFD4AF37),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black87,
          foregroundColor: Color(0xFFD4AF37),
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
          ),
        ),
        cardColor: const Color(0xFF1E1E1E),
      ),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/calculator': (context) => const CalculatorScreen(),
        '/admin': (context) => const AdminScreen(),
      },
    );
  }
}
