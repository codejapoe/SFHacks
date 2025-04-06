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
  SpeechToText _speechToText = SpeechToText();
  String? _audioPath;
  String _lastWords = '';
  String _geminiResponse = 'Initializing...';
  bool _isFullScreen = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isAudioPlaying = false;
  bool _isMuted = false;
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

    _audioPlayer.onPlayerStateChanged.listen((state) {
      print('🔊 Audio player state changed to: $state');
      
      // Handle audio starting to play - stop microphone
      if (state == PlayerState.playing && _isListening) {
        print('🔊 Audio started playing, stopping microphone');
        _stopListening();
      }
      
      setState(() {
        _isAudioPlaying = state == PlayerState.playing;
      });
      
      // Handle audio completion - restart microphone
      if (state == PlayerState.completed) {
        print('🔊 Audio playback completed, resuming listening...');
        _startListening();
        setState(() {
          _isListening = true;
        });
      }
    });
    
    _initSpeech();
    _playGreeting();
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
    if (_isInitialized) return;
    
    print('🔊 Initializing speech recognition...');
    final status = await Permission.microphone.request();
    print('🔊 Microphone permission status: $status');
    
    if (status.isGranted) {
      print('🔊 Microphone permission granted, initializing speech to text...');
      bool success = await _speechToText.initialize(
        onError: (error) {
          print('🔊 Speech recognition error: $error');
          
          // Handle ANY permanent error by completely reinitializing speech recognition
          if (error.permanent) {
            print('🔊 Permanent error detected: ${error.errorMsg}, reinitializing speech recognition...');
            
            _speechToText.stop();
            setState(() {
              _isListening = false;
              _isInitialized = false;  // Reset initialization flag
            });
            
            // Create a new instance
            _speechToText = SpeechToText();
            
            // Reinitialize after a short delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && !_isAudioPlaying) {
                _initSpeech().then((_) {
                  if (mounted && _isInitialized && !_isAudioPlaying) {
                    _startListening();
                  }
                });
              }
            });
          } else if (error.errorMsg == 'error_speech_timeout') {
            // Handle timeout specifically
            _handleTimeout();
          }
        }
      );
      print('🔊 Speech to text initialized: $success');
      
      if (!mounted) return;
      
      setState(() {
        _isInitialized = true;
      });
    } else {
      print('🔊 Microphone permission denied');
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
      setState(() {
        _geminiResponse = 'Hello world!';
      });
      // Encode the greeting message
      _audioPath = await VoiceService.encodeMessage(
        message: "Hello world!",
        protocolId: 1,
        sampleRate: 48000,
        volume: 100,
      );

      // Play the audio file only if not muted
      if (!_isMuted) {
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
      }
      
      // Start listening after greeting
      _startListening();
    } catch (e) {
      print('Failed to play greeting: $e');
      // Even if greeting fails, start listening
      _startListening();
    }
  }

  void _startListening() async {
    if (!_isInitialized || _isListening || _isAudioPlaying) {
      print('🔊 Cannot start listening: initialized=$_isInitialized, listening=$_isListening, audioPlaying=$_isAudioPlaying');
      return;
    }
    
    print('🔊 Starting listening...');
    try {
      setState(() => _isListening = true);
      await _speechToText.listen(
        onResult: (result) {
          print('🔊 Speech result [final=${result.finalResult}]: "${result.recognizedWords}"');
          if (result.recognizedWords.isNotEmpty) {
            setState(() {
              _lastWords = result.recognizedWords;
            });
            if (result.finalResult) {
              print('🔊 Final result received, processing speech...');
              _processSpeech();
              _stopListening();
              _startListening();
            }
          }
        },
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
        listenFor: const Duration(seconds: 15),  
        onSoundLevelChange: (level) {
          // Print sound level changes occasionally for debugging
          if (level > 0 && DateTime.now().second % 5 == 0) {
            print('🔊 Sound level: $level');
          }
        }
      );
      print('🔊 Started listening successfully');
    } catch (e) {
      print('🔊 Error starting speech recognition: $e');
      setState(() {
        _isListening = false;
        _isInitialized = false;
      });
      
      // Recreate the speech recognition instance
      _speechToText = SpeechToText();
      
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_isAudioPlaying) {
          _initSpeech().then((_) {
            if (mounted && _isInitialized && !_isAudioPlaying) {
              _startListening();
            }
          });
        }
      });
    }
  }

  void _stopListening() {
    if (!_isListening) return;
    
    print('🔊 Stopping listening...');
    _speechToText.stop();
    setState(() => _isListening = false);
    print('🔊 Listening stopped');
  }

  void _forceRestartListening() {
    print('🔊 Force restarting listening...');
    _speechToText.stop();
    setState(() => _isListening = false);
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_isAudioPlaying) {
        _startListening();
      }
    });
  }

  Future<void> _processSpeech() async {
    if (_lastWords.isEmpty) {
      print('🔊 No words to process, continuing to listen');
      return;
    }

    // Check for mute/unmute commands
    final lowerCaseWords = _lastWords.toLowerCase().trim();
    if (lowerCaseWords == "mute yourself") {
      setState(() {
        _isMuted = true;
        _geminiResponse = "I'm now muted. Say 'unmute yourself' to hear me again.";
      });
      print('🔊 Audio muted by voice command');
      return;
    } else if (lowerCaseWords == "unmute yourself" || lowerCaseWords == "and you yourself") {
      setState(() {
        _isMuted = false;
        _lastWords = 'unmute yourself';
        _geminiResponse = "I'm unmuted and ready to speak again.";
      });
      print('🔊 Audio unmuted by voice command');
      return;
    }

    print('🔊 Processing speech: $_lastWords');
    _stopListening();  // Stop listening first
    
    setState(() {
      _isProcessing = true;
    });

    try {
      print('🔊 Getting response from Gemini...');
      _geminiResponse = await GeminiService.getResponse(_lastWords);
      print('🔊 Gemini response received: $_geminiResponse');
      
      setState(() {});
      
      // Only encode and play audio if not muted
      if (!_isMuted) {
        print('🔊 Encoding response to audio...');
        _audioPath = await VoiceService.encodeMessage(
          message: _geminiResponse.length > 5 ? _geminiResponse.substring(0, 5) : _geminiResponse,
          protocolId: 1,
          sampleRate: 48000,
          volume: 100,
        );

        // Make absolutely sure microphone is stopped before playing audio
        if (_isListening) {
          print('🔊 Ensuring microphone is off before playing audio');
          _stopListening();
        }

        print('🔊 Playing response audio...');
        try {
          await _audioPlayer.play(DeviceFileSource(_audioPath!));
          print('🔊 Audio playback started successfully');
        } catch (audioError) {
          print('🔊 ERROR PLAYING AUDIO: $audioError');
          // If audio fails, force restart listening
          _forceRestartListening();
        }
      } else {
        print('🔊 Audio is muted, skipping playback');
        _forceRestartListening();
      }
      
      setState(() {
        _isProcessing = false;
      });
      
      // If muted, we need to manually restart listening since there won't be an audio completion event
      if (_isMuted) {
        _forceRestartListening();
      }
      // Otherwise, listening will resume from the audioPlayer.onPlayerStateChanged handler
    } catch (e) {
      print('🔊 Error processing speech: $e');
      setState(() {
        _isProcessing = false;
      });
      // Force restart listening if there was an error
      _forceRestartListening();
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

  // Add a method to handle timeout and recreate the instance
  void _handleTimeout() {
    print('🔊 Speech recognition timeout, recreating instance...');
    _speechToText.stop();
    setState(() {
      _isListening = false;
      _isInitialized = false;
    });
    
    // Create a new instance
    _speechToText = SpeechToText();
    
    // Reinitialize after delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isAudioPlaying) {
        _initSpeech().then((_) {
          if (mounted && _isInitialized && !_isAudioPlaying) {
            _startListening();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
      
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleFullScreen,
          onDoubleTap: () {
            setState(() {
              _isMuted = !_isMuted;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isMuted ? 'Audio muted' : 'Audio unmuted'),
                  duration: const Duration(seconds: 1),
                ),
              );
            });
          },
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: EdgeInsets.only(right: isLandscape ? 50 : 0, bottom: isLandscape ? 0 : 40),
                  child: Transform.scale(
                    scale: isLandscape ? 3.0 : 1.0,
                    child: RoboEyes(isMuted: _isMuted, isFullScreen: false),
                  ),
                ),
              ),
              Positioned(
                top: isLandscape ? 25 : 50,
                right: isLandscape ? 20 : 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(1),
                      ),
                      child: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up, 
                        color: Colors.white, 
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(1),
                      ),
                      child: const Icon(
                        Icons.battery_5_bar, 
                        color: Colors.white, 
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: isLandscape ? 0 : 40,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 0 : 24, 
                    vertical: 16
                  ),
                  margin: EdgeInsets.only(
                    right: isLandscape ? 50 : 0
                  ),
                  child: Text(
                    _geminiResponse,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
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
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _toggleFullScreen,
                    onDoubleTap: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isMuted ? 'Audio muted' : 'Audio unmuted'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      });
                    },
                    child: RoboEyes(isMuted: _isMuted, isFullScreen: false),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Icon(Icons.battery_full, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_lastWords.isNotEmpty) ...[
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
                    ],
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
                      _geminiResponse.isNotEmpty ? _geminiResponse : '',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
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