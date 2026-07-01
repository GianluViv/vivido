import 'package:flutter_viz/local/app_localizations.dart';
import 'package:flutter_viz/local/languages.dart';
import 'package:flutter_viz/local_storage/local_project_service.dart';
import 'package:flutter_viz/screen/dashboard_screen.dart';
import 'package:flutter_viz/screen/login_screen.dart';
import 'package:flutter_viz/screen/register_screen.dart';
import 'package:flutter_viz/store/AppStore.dart';
import 'package:flutter_viz/utils/AnalyticsService.dart';
import 'package:flutter_viz/utils/AppColors.dart';
import 'package:flutter_viz/utils/AppCommon.dart';
import 'package:flutter_viz/utils/AppConstant.dart';
import 'package:flutter_viz/utils/AppTheme.dart';
import 'package:flutter_viz/widgets/handle_keyboard_event.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'firebase_options.dart';

FirebaseAuth auth = FirebaseAuth.instance;

AppStore appStore = AppStore();
BaseLanguage? language;

GetIt locator = GetIt.instance;
FocusNode mainFocusNode = FocusNode();
PackageInfo? packageInfo;

double deviceWidth = 300;
double deviceHeight = 600;

double screenPreviewHeight = 500;
double screenPreviewWidth = 250;

final FocusScopeNode _node = FocusScopeNode();

ScreenshotController screenshotController = ScreenshotController();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Firebase is only configured for the web target today (see firebase_options.dart).
  /// TODO(local-desktop-plan Fase 4): remove Firebase entirely once auth is dropped.
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await initialize(aLocaleLanguageList: languageList());

  setupServiceLocator();

  /// Print Error
  FlutterError.onError = ((k) {
    printLogData(k.exceptionAsString());
    printLogData(k.stack.toString());
  });

  defaultRadius = 6;
  desktopBreakpointGlobal = 1100.0;

  textPrimaryColorGlobal = textColorPrimary;
  textSecondaryColorGlobal = textColorSecondary;
  appButtonBackgroundColorGlobal = scaffoldSecondaryDark;

  appStore.setLoggedIn(getBoolAsync(IS_LOGGED_IN));
  appStore.setProfileImage(getStringAsync(USER_PHOTO));
  appStore.setUserEmail(getStringAsync(USER_EMAIL));

  await appStore.setLanguage(getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: defaultLanguage));

  int themeModeIndex = getIntAsync(THEME_MODE_INDEX, defaultValue: ThemeModeDark);

  if (getStringAsync(USER_TYPE) == ADMIN) {
    appStore.setDarkMode(false);
  } else {
    if (themeModeIndex == ThemeModeDark) {
      appStore.setDarkMode(true);
    } else if (themeModeIndex == ThemeModeLight) {
      appStore.setDarkMode(false);
    }
  }
  await PackageInfo.fromPlatform().then((PackageInfo packageInformation) {
    packageInfo = packageInformation;
  });

  await dotenv.load(fileName: ".env");

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    tabKeyEvent(_node);
    return FocusScope(
      node: _node,
      child: Observer(builder: (context) {
        return MaterialApp(
          title: appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appStore.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          navigatorKey: navigatorKey,
          // TODO(local-desktop-plan Fase 0->4): temporary bypass of Login/Welcome so the editor
          // is reachable without a backend. Fase 4 replaces this with a real
          // "recent projects / new / open" start screen.
          home: DashboardScreen(),
          routes: <String, WidgetBuilder>{
            LoginScreen.tag: (_) => LoginScreen(),
            RegisterScreen.tag: (_) => RegisterScreen(),
            TRY_DEMO_ROUTE: (_) => const LoginScreen(isDemo: true),
          },
          supportedLocales: LanguageDataModel.languageLocales(),
          localizationsDelegates: [AppLocalizations(), GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
          localeResolutionCallback: (locale, supportedLocales) => locale,
          locale: Locale(appStore.selectedLanguageCode!),
        );
      }),
    );
  }
}

setupServiceLocator() {
  locator.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
  locator.registerLazySingleton<LocalProjectService>(() => LocalProjectService());
}
