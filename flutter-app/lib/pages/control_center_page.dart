import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/control_button.dart';

class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({Key? key}) : super(key: key);

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

class _ControlCenterPageState extends State<ControlCenterPage> {
  bool _isFullScreen = false;

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return GestureDetector(
        onTap: _toggleFullScreen,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Image.asset(
              'assets/EVE.gif',
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Emo-Robo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        // Settings functionality
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _toggleFullScreen,
                child: SizedBox(
                  height: 200,
                  child: Image.asset(
                    'assets/EVE.gif',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ControlButton(
                              label: '',
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
                              label: '',
                              command: 'left',
                              icon: Icons.arrow_back,
                            ),
                            ControlButton(
                              label: '',
                              command: 'stop',
                              icon: Icons.stop,
                            ),
                            ControlButton(
                              label: '',
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
                              label: '',
                              command: 'backward',
                              icon: Icons.arrow_downward,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 