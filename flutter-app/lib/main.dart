import 'package:flutter/material.dart';
import 'widgets/control_button.dart';

void main() {
  runApp(const RobotControlApp());
}

class RobotControlApp extends StatelessWidget {
  const RobotControlApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Control Center',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ControlCenterScreen(),
    );
  }
}

class ControlCenterScreen extends StatelessWidget {
  const ControlCenterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot Control Center'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Robot Controls',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ControlButton(
                  label: 'Forward',
                  command: 'forward',
                  icon: Icons.arrow_upward,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ControlButton(
                  label: 'Left',
                  command: 'left',
                  icon: Icons.arrow_back,
                ),
                ControlButton(
                  label: 'Stop',
                  command: 'stop',
                  icon: Icons.stop,
                ),
                ControlButton(
                  label: 'Right',
                  command: 'right',
                  icon: Icons.arrow_forward,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ControlButton(
                  label: 'Backward',
                  command: 'backward',
                  icon: Icons.arrow_downward,
                ),
              ],
            ),
            const SizedBox(height: 32),
            ControlButton(
              label: 'Special Action',
              command: 'special',
              icon: Icons.star,
            ),
          ],
        ),
      ),
    );
  }
} 