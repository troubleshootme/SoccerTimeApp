import 'package:flutter/material.dart';
import 'database.dart';

class SessionDialog extends StatelessWidget {
  final Function(int sessionId) onSessionSelected;

  const SessionDialog({super.key, required this.onSessionSelected});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sessions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showCreateSessionDialog(context),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Create New Session'),
            ),
            const SizedBox(height: 16),
            _buildSessionList(context),
          ],
        ),
      ),
    );
  }

  void _showCreateSessionDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Session'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Session Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final sessionId = await SessionDatabase.instance.insertSession(controller.text);
                onSessionSelected(sessionId);
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SessionDatabase.instance.getAllSessions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final sessions = snapshot.data!;
        return SizedBox(
          height: 200,
          child: ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(session['name']),
                  subtitle: Text(DateTime.fromMillisecondsSinceEpoch(session['created_at']).toString()),
                  onTap: () {
                    onSessionSelected(session['id']);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}