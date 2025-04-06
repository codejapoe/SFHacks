import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class VoiceService {
  static const String _baseUrl = 'https://ggwave-to-file.ggerganov.com/';

  /// Encodes a message into an audio file using ggwave
  /// 
  /// [message] - The message to encode
  /// [protocolId] - Transmission protocol to use (default: 1)
  /// [sampleRate] - Output sample rate (default: 48000)
  /// [volume] - Output volume (default: 50)
  /// [payloadLength] - If positive, use fixed-length encoding (default: -1)
  /// [useDSS] - If positive, use DSS (default: 0)
  /// 
  /// Returns the path to the generated audio file
  static Future<String> encodeMessage({
    required String message,
    int protocolId = 1,
    double sampleRate = 48000,
    int volume = 100,
    int payloadLength = -1,
    int useDSS = 0,
  }) async {
    try {
      // Create query parameters
      final params = {
        'm': message,
        'p': protocolId.toString(),
        's': sampleRate.toString(),
        'v': volume.toString(),
        'l': payloadLength.toString(),
        'd': useDSS.toString(),
      };

      // Make the API request
      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.body.isEmpty || response.body.contains('Usage: ggwave-to-file')) {
        throw Exception('Request failed');
      }

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/encoded_message.wav';

      // Write the audio data to a file
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      return filePath;
    } catch (e) {
      throw Exception('Failed to encode message: $e');
    }
  }

  /// Deletes the temporary audio file
  static Future<void> cleanup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Failed to delete audio file: $e');
    }
  }
} 