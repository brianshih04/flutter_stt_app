import 'package:equatable/equatable.dart';

// Events for STT BLoC
abstract class SttEvent extends Equatable {
  const SttEvent();

  @override
  List<Object?> get props => [];
}

class InitializeStt extends SttEvent {
  const InitializeStt();
}

class StartListening extends SttEvent {
  const StartListening();
}

class StopListening extends SttEvent {
  const StopListening();
}

class ChangeLanguage extends SttEvent {
  final String languageCode;

  const ChangeLanguage(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

class ChangeTargetLanguage extends SttEvent {
  final String languageCode;

  const ChangeTargetLanguage(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

class RetryStt extends SttEvent {
  const RetryStt();
}

class UpdateTranscription extends SttEvent {
  final String text;
  final bool isFinal;

  const UpdateTranscription(this.text, {this.isFinal = false});

  @override
  List<Object?> get props => [text, isFinal];
}
