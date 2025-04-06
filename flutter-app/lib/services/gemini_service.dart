import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

class GeminiService {
  static const String _apiKey = 'AIzaSyA5HZcwQEbDhBcZNbLaQAAiTW5rRS04cIs';
  static final model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: _apiKey,
  );

  static Future<String> getResponse(String prompt) async {
    try {
      final systemInstruction = Content.text(
        'You are a emotional robot companion named Emo. Your response must be short, friendly, and casual no more than one sentence.'
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