import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/session_prompt_screen.dart';
import 'screens/main_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'providers/app_state.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: SoccerTimeApp(),
    ),
  );
}

class SoccerTimeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'SoccerTimeApp',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: appState.isDarkTheme ? Brightness.dark : Brightness.light,
            fontFamily: 'Verdana',
          ),
          home: SessionPromptScreen(),
          routes: {
            '/main': (context) => MainScreen(),
          },
        );
      },
    );
  }
}