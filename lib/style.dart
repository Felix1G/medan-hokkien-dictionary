
import 'package:flutter/material.dart';

const kBackgroundColor = Color.fromRGBO(35, 35, 35, 1.0);

final ThemeData kAppTheme = ThemeData(
  fontFamily: 'DefaultFont',
  textTheme: ThemeData.dark().textTheme.apply(
    fontFamily: 'DefaultFont'
  ),
  brightness: Brightness.dark,
  primarySwatch: Colors.red,
  primaryColor: Colors.red.shade500,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.red.shade500,
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: kBackgroundColor,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.red,
    foregroundColor: kBackgroundColor,
  ),
  pageTransitionsTheme: PageTransitionsTheme(
    builders: {
      TargetPlatform.android: AppPageTransitionBuilder(),
      TargetPlatform.iOS: AppPageTransitionBuilder(),
      TargetPlatform.linux: AppPageTransitionBuilder(),
      TargetPlatform.macOS: AppPageTransitionBuilder(),
      TargetPlatform.windows: AppPageTransitionBuilder(),
      TargetPlatform.fuchsia: AppPageTransitionBuilder(),
    }
  )
);

final kDefaultTextStyle = TextStyle(
  fontFamily: 'DefaultFont'
);

final kCJKTextStyle = TextStyle(
  fontFamily: 'DefaultFont'
).copyWith(
  fontFamilyFallback: ['CJKFont1', 'CJKFont2', 'CJKFont3', 'CJKFont4'],
  color: Colors.white
);

final kUITextStyle = TextStyle(
  fontFamily: 'NunitoFont'
);

final kCategoryTextStyle = TextStyle(
  fontFamily: 'ThickFont'
);

class AppPageTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.05),
        end: Offset.zero
      ).animate(animation),
      child: FadeTransition(
        opacity: animation,
        child: child
      )
    );
  }
}