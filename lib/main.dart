import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/uno_colors.dart';
import 'firebase_options.dart';
import 'views/lobby/lobby_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init fallback: $e');
  }
  runApp(const UnoNoMercyApp());
}

class UnoNoMercyApp extends StatelessWidget {
  const UnoNoMercyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNO Show \'em No Mercy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: UnoColors.background,
        textTheme: GoogleFonts.rubikTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const LobbyScreen(),
    );
  }
}
