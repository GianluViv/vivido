import 'package:flutter_viz/utils/AppColors.dart';
import 'package:flutter_viz/utils/AppConstant.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  //
  AppTheme._();

  static final ThemeData lightTheme = ThemeData(
    primaryColor: colorPrimary,
    scaffoldBackgroundColor: colorPrimary,
    fontFamily: font,
    cardColor: scaffoldSecondaryDark,
    bottomNavigationBarTheme: BottomNavigationBarThemeData(backgroundColor: Colors.white),
    iconTheme: IconThemeData(color: Colors.black),
    unselectedWidgetColor: Colors.black,
    dividerColor: Colors.white,
    dialogTheme: DialogThemeData(backgroundColor: colorPrimary),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    primaryColor: darkModePrimaryColorBackground,
    scaffoldBackgroundColor: darkModePrimaryColorBackground,
    bottomNavigationBarTheme: BottomNavigationBarThemeData(backgroundColor: darkModeSecondaryBackgroundDark),
    iconTheme: IconThemeData(color: Colors.white),
    cardColor: darkModeSecondaryBackgroundDark,
    fontFamily: font,
    unselectedWidgetColor: Colors.grey,
    dividerColor: Colors.white,
    dialogTheme: DialogThemeData(backgroundColor: darkModeSecondaryBackgroundDark),
  ).copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
