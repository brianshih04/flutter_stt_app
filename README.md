# Flutter Speech-to-Text Application

A multi-language speech-to-text application built with Flutter, supporting Traditional Chinese (zh-TW), English (en-US), and Japanese (ja-JP).

## Features

- **Multi-language Support**: Switch between zh-TW, en-US, and ja-JP in real-time.
- **Real-time Transcription**: See text as you speak.
- **State Management**: Uses BLoC pattern for predictable state management.
- **Error Handling**: Graceful handling of permissions and errors.
- **Visual Feedback**: Animated recording button and status indicators.

## Prerequisites

- Flutter SDK (Latest Stable)
- Android SDK (minSdkVersion 21)
- Physical Android device (recommended for STT testing)

## Setup

1. **Clone the repository:**

    ```bash
    git clone https://github.com/your-username/flutter_stt_app.git
    cd flutter_stt_app
    ```

2. **Install dependencies:**

    ```bash
    flutter pub get
    ```

3. **Run the app:**

    ```bash
    flutter run
    ```

## Usage

1. **Grant Permissions**: On first launch, grant microphone permissions.
2. **Select Language**: Use the dropdown menu to select your desired language.
3. **Start Recording**: Tap the microphone button to start listening.
4. **Speak**: Speak clearly into the microphone. The text will appear on screen.
5. **Stop Recording**: Tap the stop button or wait for silence (STT may auto-stop depending on settings).

## Project Structure

- `lib/main.dart`: Entry point.
- `lib/screens/stt_screen.dart`: Main UI screen.
- `lib/bloc/`: BLoC state management logic.
- `lib/services/stt_service.dart`: Speech recognition service.
- `lib/widgets/`: Reusable UI components.
- `lib/utils/`: Utility classes (Logger).
- `lib/constants/`: App constants (Languages).

## Troubleshooting

- **"Speech recognition not available"**: Ensure your device has Google app installed and enabled, and supports speech recognition for the selected language.
- **"Permission denied"**: Go to App Settings and manually enable Microphone permission if the prompt was denied.
- **No text output**: Check your internet connection (some STT engines require it). This app uses on-device STT where supported, but may fallback to network.
