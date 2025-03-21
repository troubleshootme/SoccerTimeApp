import 'package:flutter/material.dart';

class SessionScreen extends StatefulWidget {
  // ... (existing code)
  @override
  _SessionScreenState createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  // ... (existing code)

  @override
  Widget build(BuildContext context) {
    // ... (existing code)

    return Scaffold(
      appBar: AppBar(
        title: Text('Session Screen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ... (existing code)

            ElevatedButton(
              onPressed: () async {
                final name = textController.text.trim();
                if (name.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a session name')),
                    );
                  }
                  return;
                }
                
                try {
                  await appState.createSession(name);
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/main');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating session: $e')),
                    );
                  }
                }
              },
              child: Text('Create Session'),
            ),
          ],
        ),
      ),
    );
  }
} 