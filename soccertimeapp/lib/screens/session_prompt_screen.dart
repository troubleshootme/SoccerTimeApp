import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../providers/app_state.dart';
import 'main_screen.dart';
import '../session_dialog.dart';

class SessionPromptScreen extends StatefulWidget {
  @override
  _SessionPromptScreenState createState() => _SessionPromptScreenState();
}

class _SessionPromptScreenState extends State<SessionPromptScreen> {
  final _passwordController = TextEditingController();
  String _buttonText = 'Start Session';
  String _motd = '';

  @override
  void initState() {
    super.initState();
    _loadMotd();
    _checkSavedSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSessionDialog(context);
    });
  }

  Future<void> _checkSavedSession() async {
    var appState = Provider.of<AppState>(context, listen: false);
    var savedPassword = await appState.loadSessionPassword();
    if (savedPassword != null) {
      await appState.startOrResumeSession(savedPassword);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    }
  }

  Future<void> _loadMotd() async {
    try {
      String text = await rootBundle.loadString('assets/motd.txt');
      setState(() {
        if (text.trim().isEmpty) {
          _motd = 'No message of the day available.';
        } else {
          _motd = text;
        }
      });
    } catch (error) {
      setState(() {
        _motd = 'Failed to load message of the day: $error';
      });
    }
  }

  Future<void> _updateButtonLabel() async {
    var password = _passwordController.text.trim();
    if (password.isNotEmpty) {
      var appState = Provider.of<AppState>(context, listen: false);
      var exists = await appState.checkSessionExists(password);
      setState(() {
        _buttonText = exists ? 'Resume Session' : 'Start Session';
      });
    } else {
      setState(() {
        _buttonText = 'Start Session';
      });
    }
  }

  void _startOrResumeSession() async {
    var password = _passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a session password')),
      );
      return;
    }
    var appState = Provider.of<AppState>(context, listen: false);
    await appState.startOrResumeSession(password);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainScreen()),
    );
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