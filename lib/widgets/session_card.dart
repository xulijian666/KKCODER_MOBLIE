import 'package:flutter/material.dart';
import '../models/session.dart';

class SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;

  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: session.type == 'claude'
              ? Colors.orange.shade700
              : Colors.blue.shade700,
          child: Icon(
            session.type == 'claude' ? Icons.terminal : Icons.smart_toy,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          session.name.isNotEmpty ? session.name : session.id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          session.project.isNotEmpty ? session.project : session.type,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade400),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
