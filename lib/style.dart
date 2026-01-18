
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final ThemeData kAppTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.red,
  primaryColor: Colors.red.shade500,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.red.shade500,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: Color.fromRGBO(35, 35, 35, 1.0),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.red,
    foregroundColor: Color.fromRGBO(35, 35, 35, 1.0),
  )
);

final kCJKTextStyle = GoogleFonts.notoSansSc().copyWith(
  fontFamilyFallback: [
    GoogleFonts.notoSansTc().fontFamily!,
  ],
  color: Colors.white
);

final kUITextStyle = GoogleFonts.nunito();