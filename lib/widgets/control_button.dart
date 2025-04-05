import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ControlButton extends StatelessWidget {
  final String label;
  final String command;
  final IconData icon;

  const ControlButton({
    Key? key,
    required this.label,
    required this.command,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => ApiService.sendCommand(command),
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontSize: 18),
      ),
    );
  }
} 