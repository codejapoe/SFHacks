import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  // Get API key from environment variables
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static final model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: _apiKey,
  );

  static Future<String> getResponse(String prompt) async {
    try {
      // Check if API key is available
      if (_apiKey.isEmpty) {
        print('❌ Gemini API key not found in environment variables');
        return 'Sorry, there was an error with my configuration.';
      }

      final systemInstruction = Content.text(
        'You are a emotional robot companion named Emo. Your creators are Inky, Codejapoe, Elija. Your response must be as short as possible, friendly, and casual no more than 20 words.'
      );
      
      final content = Content.text(prompt);
      final response = await model.generateContent(
        [systemInstruction, content],
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 100,
        ),
      );
      
      return response.text ?? 'Sorry, I could not generate a response.';
    } catch (e, stackTrace) {
      stderr.writeln('❌ Gemini API Error:');
      stderr.writeln('Error: $e');
      stderr.writeln('Stack trace: $stackTrace');
      stderr.writeln('Prompt that caused error: $prompt');
      return 'Sorry, there was an error processing your request.';
    }
  }
} 