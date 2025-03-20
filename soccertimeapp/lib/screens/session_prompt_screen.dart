import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../providers/app_state.dart';
import 'main_screen.dart';
import 'package:http/http.dart' as http;
import '../models/session.dart';
import '../models/player.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: Offset(0, 5),
                  ),
                ],
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Session Password',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => _updateButtonLabel(),
                          onSubmitted: (value) => _startOrResumeSession(),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _startOrResumeSession,
                        child: Text(_buttonText),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black54
                          : Colors.black12,
                    ),
                    child: MarkdownBody(data: _motd),
                  ),
                  SizedBox(height: 12),
                  Text('Powered by:'),
                  SizedBox(height: 12),
                  Image.asset(
                    'assets/bcs-grad-logo.png', // Add this asset to your project
                    height: 50,
                  ),
                  SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      // Open documentation URL
                    },
                    child: Text('Documentation'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}