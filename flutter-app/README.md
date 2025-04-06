# Emo-Robo

A control center app for an emotional robot companion.

## Getting Started

### Environment Setup

The application uses environment variables to securely store API keys and other sensitive information. 

1. Create a `.env` file in the root directory of the project.
2. Copy the content from `.env.example` into your `.env` file.
3. Replace the placeholder values with your actual API keys:

```
GEMINI_API_KEY=your_actual_gemini_api_key_here
```

To get a Gemini API key:
1. Visit https://aistudio.google.com/app/apikey
2. Follow the instructions to create a new API key
3. Copy the key into your `.env` file

### Running the App

After setting up your environment variables:

```bash
flutter pub get
flutter run
```

## Features

- Voice interaction with the robot
- AI-powered responses using Google's Gemini
- Mute/unmute functionality
- Full screen mode
