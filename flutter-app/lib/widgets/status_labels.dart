import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StatusLabels extends StatefulWidget {
  const StatusLabels({Key? key}) : super(key: key);

  @override
  State<StatusLabels> createState() => _StatusLabelsState();
}

class _StatusLabelsState extends State<StatusLabels> {
  String _status = 'Offline';
  String _mood = 'Neutral';
  Timer? _statusTimer;
  Timer? _moodTimer;

  @override
  void initState() {
    super.initState();
    _startStatusCheck();
    _startMoodCheck();
  }

  void _startStatusCheck() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final response = await http.get(Uri.parse('https://example.com'));
        if (mounted) {
          setState(() {
            _status = response.statusCode == 200 ? 'Active' : 'Offline';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _status = 'Offline';
          });
        }
      }
    });
  }

  void _startMoodCheck() {
    _updateMood();
    _moodTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateMood();
    });
  }

  void _updateMood() {
    final now = DateTime.now();
    final hour = now.hour;
    if (mounted) {
      setState(() {
        _mood = (hour >= 23 || hour < 7) ? 'Sleepy' : 'Neutral';
      });
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _moodTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _status == 'Active' ? Colors.green : Colors.red,
              width: 2,
            ),
          ),
          child: Text(
            'Status: $_status',
            style: TextStyle(
              color: _status == 'Active' ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _mood == 'Sleepy' ? Colors.purple : Colors.blue,
              width: 2,
            ),
          ),
          child: Text(
            'Mood: $_mood',
            style: TextStyle(
              color: _mood == 'Sleepy' ? Colors.purple : Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
} 