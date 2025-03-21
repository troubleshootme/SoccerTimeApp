import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../session_dialog.dart';

class SessionPromptScreen extends StatefulWidget {
  @override
  _SessionPromptScreenState createState() => _SessionPromptScreenState();
}

class _SessionPromptScreenState extends State<SessionPromptScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSessionDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SoccerTimeApp')),
      body: Container(),
    );
  }

  void _showSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SessionDialog(
        onSessionSelected: (sessionId) async {
          final appState = Provider.of<AppState>(context, listen: false);
          await appState.loadSession(sessionId);
          Navigator.pushReplacementNamed(context, '/main');
        },
      ),
    );
  }
}