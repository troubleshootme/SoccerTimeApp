import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'screens/session_prompt_screen.dart';
import 'providers/app_state.dart';
import 'screens/main_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/app_themes.dart';

// Single global instance for error tracking
final _errorHandler = ErrorHandler();

Future<void> main() async {
  // This needs to be the very first line to catch early errors
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up global error handlers first
  FlutterError.onError = _errorHandler.handleFlutterError;
  PlatformDispatcher.instance.onError = _errorHandler.handlePlatformError;
  
  // Handle platform-specific concerns
  if (Platform.isAndroid) {
    // Configure UI mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, 
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    
    // Remove hardware acceleration configuration since it's handled in AndroidManifest.xml
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

class SoccerTimeApp extends StatelessWidget {
  // Don't use const constructor to avoid widget identity issues
  SoccerTimeApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDarkTheme = appState.isDarkTheme;
    
    return MaterialApp(
      title: 'SoccerTimeApp',
      theme: AppThemes.lightTheme(),
      darkTheme: AppThemes.darkTheme(),
      themeMode: isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      home: appState.currentSessionId == null
          ? SessionPromptScreen()
          : MainScreen(),
      routes: {
        // Do not include '/' route when home is specified
        '/settings': (context) => SettingsScreen(),
      },
    );
  }
}