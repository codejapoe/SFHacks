import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/control_button.dart';
import '../widgets/robo_eyes.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/status_labels.dart';
import 'robot_id_page.dart';
import '../services/voice_service.dart';
import '../services/gemini_service.dart';

class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({Key? key}) : super(key: key);

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

class _ControlCenterPageState extends State<ControlCenterPage> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SpeechToText _speechToText = SpeechToText();
  String? _audioPath;
  String _lastWords = '';
  String _geminiResponse = '';
  bool _isFullScreen = false;
  bool _isListening = false;
  bool _isProcessing = false;
  late AnimationController _blinkController;
  late AnimationController _loadingController;
  late Animation<double> _dot1Animation;
  late Animation<double> _dot2Animation;
  late Animation<double> _dot3Animation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _dot1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: const Interval(0.0, 0.33, curve: Curves.easeInOut),
      ),
    );
    
    _dot2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: const Interval(0.33, 0.66, curve: Curves.easeInOut),
      ),
    );
    
    _dot3Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: const Interval(0.66, 1.0, curve: Curves.easeInOut),
      ),
    );
    
    _initSpeech();
  }

  @override
  void dispose() {
    _stopListening();
    _blinkController.dispose();
    _loadingController.dispose();
    _audioPlayer.dispose();
    if (_audioPath != null) {
      VoiceService.cleanup(_audioPath!);
    }
    super.dispose();
  }

  Future<void> _initSpeech() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      await _speechToText.initialize();
      if (!mounted) return;
      _playGreeting();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for speech recognition'),
          ),
        );
      }
    }
  }

  Future<void> _playGreeting() async {
    try {
      // Encode the greeting message
      _audioPath = await VoiceService.encodeMessage(
        message: "Hello world!",
        protocolId: 1,
        sampleRate: 48000,
        volume: 100,
      );

      // Play the audio file
      await _audioPlayer.play(DeviceFileSource(_audioPath!));
      
      // Start listening after greeting
      _startListening();
    } catch (e) {
      print('Failed to play greeting: $e');
      // Even if greeting fails, start listening
      _startListening();
    }
  }

  void _startListening() async {
    if (!_isListening) {
      try {
        bool available = await _speechToText.initialize();
        if (available) {
          setState(() => _isListening = true);
          await _speechToText.listen(
            onResult: (result) {
              setState(() {
                _lastWords = result.recognizedWords;
              });
              if (result.finalResult) {
                _processSpeech();
              }
            },
            listenMode: ListenMode.dictation,
            cancelOnError: false,
            partialResults: true,
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 3),
          );
        } else {
          print('Speech recognition not available, retrying...');
          Future.delayed(const Duration(seconds: 1), () {
            _startListening();
          });
        }
      } catch (e) {
        print('Error starting speech recognition: $e');
        Future.delayed(const Duration(seconds: 1), () {
          _startListening();
        });
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speechToText.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _processSpeech() async {
    if (_lastWords.isEmpty) return;

    // Stop listening before processing
    _stopListening();
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // Get response from Gemini
      _geminiResponse = await GeminiService.getResponse(_lastWords);
      
      // Update UI with response immediately
      setState(() {});
      
      // Encode and play the response
      _audioPath = await VoiceService.encodeMessage(
        message: _geminiResponse,
        protocolId: 1,
        sampleRate: 48000,
        volume: 100,
      );

      await _audioPlayer.play(DeviceFileSource(_audioPath!));
      
      // Wait for audio to finish playing before starting to listen again
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Clear the last words to prepare for new input
      setState(() {
        _lastWords = '';
      });
      
      // Start listening again after response
      _startListening();
    } catch (e) {
      print('Error processing speech: $e');
      _startListening();
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

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

  Future<void> _handleDisconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_id');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RobotIdPage()),
        (route) => false,
      );
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        onDisconnect: _handleDisconnect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
      
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleFullScreen,
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(right: isLandscape ? 50 : 0),
              child: Transform.scale(
                scale: isLandscape ? 4.0 : 1.0,
                child: const RoboEyes(),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
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
                    onPressed: _showSettings,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              child: GestureDetector(
                onTap: _toggleFullScreen,
                child: const RoboEyes(),
              ),
            ),
            const SizedBox(height: 20),
            if (_lastWords.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lastWords,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    if (_geminiResponse.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Emo:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _geminiResponse,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _dot1Animation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _dot1Animation.value,
                          child: const Text(
                            '.',
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: _dot2Animation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _dot2Animation.value,
                          child: const Text(
                            '.',
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: _dot3Animation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _dot3Animation.value,
                          child: const Text(
                            '.',
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const StatusLabels(),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                children: [
                  // Add your existing widgets here
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 