import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/session_prompt_screen.dart';
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
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaleFactor: kIsWeb ? 1.0 : mediaQuery.textScaleFactor,
              ),
              child: child!,
            );
          },
          title: 'SoccerTimeApp',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: appState.isDarkTheme ? Brightness.dark : Brightness.light,
            fontFamily: 'Verdana',
          ),
          home: SessionPromptScreen(),
        );
      },
    );
  }
}