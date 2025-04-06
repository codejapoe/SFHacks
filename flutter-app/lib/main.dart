import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robot_control_center/pages/login_page.dart';
import 'package:robot_control_center/pages/robot_id_page.dart';
import 'package:robot_control_center/pages/control_center_page.dart';

void main() {
  runApp(const EmoRoboApp());
}

class EmoRoboApp extends StatelessWidget {
  const EmoRoboApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emo-Robo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      home: const InitialPage(),
    );
  }
}

class InitialPage extends StatefulWidget {
  const InitialPage({Key? key}) : super(key: key);

  @override
  State<InitialPage> createState() => _InitialPageState();
}

class _InitialPageState extends State<InitialPage> {
  bool _isLoading = true;
  bool _hasRobotId = false;
  bool _hasRobotIds = false;

  @override
  void initState() {
    super.initState();
    _checkRobotId();
  }

  Future<void> _checkRobotId() async {
    final prefs = await SharedPreferences.getInstance();
    final currentId = prefs.getString('current_id');
    final robotIds = prefs.getStringList('robot_ids') ?? [];
    setState(() {
      _hasRobotId = currentId != null && robotIds.isNotEmpty;
      _hasRobotIds = robotIds.isNotEmpty;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasRobotId) {
      return const ControlCenterPage();
    }

    if (_hasRobotIds) {
      return const RobotIdPage();
    }
    return const LoginPage();
  }
} 