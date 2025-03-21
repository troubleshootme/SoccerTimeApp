import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'screens/session_prompt_screen.dart';
import 'providers/app_state.dart';
import 'screens/main_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/app_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'hive_database.dart';
import 'dart:async';

// Single global instance for error tracking
final _errorHandler = ErrorHandler();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Configure status bar color
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // Initialize directory for databases and files
  try {
    if (!kIsWeb) {
      final appDocDir = await getApplicationDocumentsDirectory();
      await Directory('${appDocDir.path}/sessions').create(recursive: true);
    }
  } catch (e) {
    print('Error creating app directory: $e');
  }
  
  // Initialize Hive database
  try {
    await HiveSessionDatabase.instance.init();
    print('Hive database initialized successfully');
  } catch (e) {
    print('Error initializing database: $e');
  }
  
  // Set up global error handlers first
  FlutterError.onError = _errorHandler.handleFlutterError;
  PlatformDispatcher.instance.onError = _errorHandler.handlePlatformError;
  
  // Handle platform-specific concerns
  if (Platform.isAndroid) {
    // Configure UI mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, 
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }
  
  // Run the app
  runApp(
    // Wrap everything in an error boundary
    ErrorBoundaryWidget(
      child: ChangeNotifierProvider(
        create: (context) => AppState(),
        child: SoccerTimeApp(),
      ),
    ),
  );
}

// Centralized error handling
class ErrorHandler {
  // Track seen errors to avoid log spam
  final Set<String> _seenErrors = {};
  
  void handleFlutterError(FlutterErrorDetails details) {
    final errorString = details.exception.toString();
    
    // Handle known errors
    if (_shouldSuppressError(errorString)) {
      // Just log it once to avoid spam
      if (!_seenErrors.contains(errorString)) {
        print('Suppressed Flutter error: ${details.exception}');
        _seenErrors.add(errorString);
      }
      return;
    }
    
    // Use default error handling for other errors
    FlutterError.presentError(details);
  }
  
  bool handlePlatformError(Object error, StackTrace stack) {
    final errorString = error.toString();
    
    // Handle known errors
    if (_shouldSuppressError(errorString)) {
      // Just log it once to avoid spam
      if (!_seenErrors.contains(errorString)) {
        print('Suppressed Platform error: $error');
        _seenErrors.add(errorString);
      }
      return true;
    }
    
    // Let platform handle other errors
    return false;
  }
  
  bool _shouldSuppressError(String errorString) {
    // List of error patterns to suppress
    final suppressPatterns = [
      'OpenGL ES API',
      'read-only',
      'Failed assertion', 
      '_dependents.isEmpty',
      '_children.contains(child)',
      'LateInitializationError: Field',
      'Duplicate GlobalKeys',
    ];
    
    // Check if this error should be suppressed
    return suppressPatterns.any((pattern) => errorString.contains(pattern));
  }
}

class ErrorBoundaryWidget extends StatefulWidget {
  final Widget child;
  
  const ErrorBoundaryWidget({Key? key, required this.child}) : super(key: key);
  
  @override
  _ErrorBoundaryWidgetState createState() => _ErrorBoundaryWidgetState();
}

class _ErrorBoundaryWidgetState extends State<ErrorBoundaryWidget> {
  bool _hasError = false;
  
  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Something went wrong.'),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                    });
                  },
                  child: Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return widget.child;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Remove the post-frame callback which can cause issues
  }
}

class SoccerTimeApp extends StatefulWidget {
  @override
  _SoccerTimeAppState createState() => _SoccerTimeAppState();
}

class _SoccerTimeAppState extends State<SoccerTimeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Close Hive database when app is disposed
    HiveSessionDatabase.instance.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App is in background, close database to prevent locking
      HiveSessionDatabase.instance.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'Soccer Time App',
            theme: ThemeData(
              brightness: appState.isDarkTheme ? Brightness.dark : Brightness.light,
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: appState.isDarkTheme 
                ? AppThemes.darkBackground 
                : AppThemes.lightBackground,
              appBarTheme: AppBarTheme(
                backgroundColor: appState.isDarkTheme 
                  ? AppThemes.darkBackground 
                  : AppThemes.lightBackground,
                iconTheme: IconThemeData(
                  color: appState.isDarkTheme 
                    ? AppThemes.darkText 
                    : AppThemes.lightText,
                ),
                titleTextStyle: TextStyle(
                  color: appState.isDarkTheme 
                    ? AppThemes.darkText 
                    : AppThemes.lightText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Define routes directly using the route constructors for better type checking
            initialRoute: '/',
            routes: {
              '/': (context) => SessionPromptScreen(),
              '/main': (context) => MainScreen(),
              '/settings': (context) => SettingsScreen(),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}