import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://example.com';

  static Future<void> sendCommand(String command) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/something'),
        body: {'command': command},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send command: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending command: $e');
    }
  }
} 