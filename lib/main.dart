import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/uno_colors.dart';
import 'views/lobby/lobby_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
