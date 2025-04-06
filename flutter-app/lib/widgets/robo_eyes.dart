import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class RoboEyes extends StatefulWidget {
  final bool isMuted;
  final bool isFullScreen;
  
  const RoboEyes({
    Key? key, 
    this.isMuted = false,
    this.isFullScreen = false,
  }) : super(key: key);

  @override
  _RoboEyesState createState() => _RoboEyesState();
}

class _RoboEyesState extends State<RoboEyes> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _eyeAnimation;
  Timer? blinkTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _eyeAnimation = Tween<double>(begin: 36, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        }
      });

    scheduleBlink();
  }

  void scheduleBlink() {
    blinkTimer?.cancel();
    blinkTimer = Timer(Duration(seconds: 3 + Random().nextInt(4)), () {
      _controller.forward();
      scheduleBlink();
    });
  }

  @override
  void dispose() {
    blinkTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _eyeAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EyeWidget(height: _eyeAnimation.value),
            const SizedBox(width: 10),
            EyeWidget(height: _eyeAnimation.value),
          ],
        );
      },
    );
  }
}

class EyeWidget extends StatelessWidget {
  final double height;

  const EyeWidget({Key? key, required this.height}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: height * 2,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
} 