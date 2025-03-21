import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/session_prompt_screen.dart';
import 'providers/app_state.dart';
import 'screens/main_screen.dart';
import 'utils/app_themes.dart';

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
          theme: AppThemes.lightTheme(),
          darkTheme: AppThemes.darkTheme(),
          themeMode: appState.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
          home: SessionPromptScreen(),
          routes: {
            '/main': (context) => MainScreen(),
          },
        );
      },
    );
  }
}