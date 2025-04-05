import 'package:flutter/material.dart';
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
      home: const LoginPage(),
    );
  }
} 