import 'package:equatable/equatable.dart';

// States for STT BLoC
abstract class SttState extends Equatable {
  const SttState();

  @override
  List<Object?> get props => [];
}

class SttInitial extends SttState {
  const SttInitial();
}

class SttInitializing extends SttState {
  const SttInitializing();
}

class SttReady extends SttState {
  final String currentLanguage;
  final String targetLanguage;
  final List<String> availableLocales;

  const SttReady({
    required this.currentLanguage,
    required this.targetLanguage,
    required this.availableLocales,
  });

  @override
  List<Object?> get props =>
      [currentLanguage, targetLanguage, availableLocales];
}

class SttListening extends SttState {
  final String currentLanguage;
  final String targetLanguage;
  final String transcription;
  final String translatedText;

  const SttListening({
    required this.currentLanguage,
    required this.targetLanguage,
    this.transcription = '',
    this.translatedText = '',
  });

  @override
  List<Object?> get props =>
      [currentLanguage, targetLanguage, transcription, translatedText];
}

class SttResult extends SttState {
  final String currentLanguage;
  final String targetLanguage;
  final String transcription;
  final String translatedText;
  final bool isFinal;

  const SttResult({
    required this.currentLanguage,
    required this.targetLanguage,
    required this.transcription,
    required this.translatedText,
    this.isFinal = false,
  });

  @override
  List<Object?> get props =>
      [currentLanguage, targetLanguage, transcription, translatedText, isFinal];
}

class SttDownloadingModel extends SttState {
  final String message;

  const SttDownloadingModel(this.message);

  @override
  List<Object?> get props => [message];
}

class SttError extends SttState {
  final String message;
  final String? currentLanguage;

  const SttError(this.message, {this.currentLanguage});

  @override
  List<Object?> get props => [message, currentLanguage];
}

class SttPermissionDenied extends SttState {
  const SttPermissionDenied();
}
