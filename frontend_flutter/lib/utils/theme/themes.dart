import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  fontFamily: GoogleFonts.manrope().fontFamily,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF1DCD9F),
    surface: Color(0xFFEFEFEF),
    onSurface: Color(0xFF000000),
    error: Color(0xFFD72638),
  ),
);

final ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  fontFamily: GoogleFonts.manrope().fontFamily,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF1DCD9F),
    surface: Color(0xFF000000),
    onSurface: Color(0xFFEFEFEF),
    error: Color(0xFFD72638),
  ),
);
