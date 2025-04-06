import 'package:flutter/material.dart';

class SettingsDialog extends StatelessWidget {
  final VoidCallback onDisconnect;

  const SettingsDialog({
    Key? key,
    required this.onDisconnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: onDisconnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
} 