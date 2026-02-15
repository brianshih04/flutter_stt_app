import 'package:flutter_bloc/flutter_bloc.dart';
import 'stt_event.dart';
import 'stt_state.dart';
import '../services/stt_service.dart';
import '../services/translation_service.dart';
import '../constants/languages.dart';
import '../utils/logger.dart';

class SttBloc extends Bloc<SttEvent, SttState> {
  final SttService _sttService;
  final TranslationService _translationService;

  String _currentLanguage = Languages.english.code;
  String _targetLanguage = Languages.traditionalChinese.code;

  SttBloc(this._sttService, this._translationService)
      : super(const SttInitial()) {
    on<InitializeStt>(_onInitialize);
    on<RetryStt>(_onRetry);
    on<StartListening>(_onStartListening);
    on<StopListening>(_onStopListening);
    on<ChangeLanguage>(_onChangeLanguage);
    on<ChangeTargetLanguage>(_onChangeTargetLanguage);
    on<UpdateTranscription>(_onUpdateTranscription);
    on<OpenLanguageSettings>(_onOpenLanguageSettings);
  }

  Future<void> _onInitialize(
    InitializeStt event,
    Emitter<SttState> emit,
  ) async {
    emit(const SttInitializing());

    try {
      final result = await _sttService.initialize(
        onStatus: (status) {
          Logger.info('BLoC received status: $status');
          if (status == 'done' || status == 'notListening') {
            add(const StopListening());
          }
        },
        onError: (error) {
          Logger.severe('BLoC received error: $error');
          final errorStr = error.toString();
          if (errorStr.contains('error_language_unavailable') ||
              errorStr.contains('error_language_not_supported')) {
            // Don't auto-stop — show a specific error for language unavailable
          } else {
            add(const StopListening());
          }
        },
      );

      if (result['success'] == true) {
        emit(SttReady(
          currentLanguage: _currentLanguage,
          targetLanguage: _targetLanguage,
          availableLocales: const [],
        ));
      } else {
        final errorType = result['error'] ?? 'unknown';
        final errorMessage = result['message'] ?? '';

        if (errorType == 'permission_denied') {
          emit(const SttPermissionDenied());
        } else if (errorType == 'recognizer_not_available') {
          emit(const SttError('找不到語音服務。請從 Play 商店安裝 "Google" 應用程式。'));
        } else {
          // Show detailed error from native layer
          emit(SttError(
            '初始化失敗: $errorType\n$errorMessage',
          ));
        }
      }
    } catch (e, stackTrace) {
      Logger.severe('Failed to initialize STT', e, stackTrace);
      emit(SttError('初始化例外: $e'));
    }
  }

  Future<void> _onRetry(
    RetryStt event,
    Emitter<SttState> emit,
  ) async {
    // Just re-run initialization
    add(const InitializeStt());
  }

  Future<void> _onStartListening(
    StartListening event,
    Emitter<SttState> emit,
  ) async {
    if (!_sttService.isAvailable) {
      emit(const SttError('語音辨識無法使用'));
      return;
    }

    try {
      // Check translation models
      emit(const SttDownloadingModel('Checking translation models...'));
      final modelsAvailable = await _translationService.downloadModels(
          _currentLanguage, _targetLanguage);

      if (!modelsAvailable) {
        emit(const SttError('下載翻譯模型失敗。請檢查網路連線。'));
        return;
      }

      final language = Languages.getByCode(_currentLanguage);

      emit(SttListening(
        currentLanguage: _currentLanguage,
        targetLanguage: _targetLanguage,
        transcription: '',
        translatedText: '',
      ));

      await _sttService.startListening(
        localeId: language.localeId,
        onResult: (text) {
          add(UpdateTranscription(text, isFinal: false));
        },
        onFinalResult: (isFinal) {
          if (isFinal) {
            add(const StopListening());
          }
        },
      );
    } catch (e, stackTrace) {
      Logger.severe('Failed to start listening', e, stackTrace);
      // Show detailed error in UI
      emit(SttError(
        '啟動聆聽失敗\n\n錯誤: $e',
        currentLanguage: _currentLanguage,
      ));
    }
  }

  Future<void> _onStopListening(
    StopListening event,
    Emitter<SttState> emit,
  ) async {
    try {
      await _sttService.stopListening();

      // If we have a final result with text, keep showing it
      if (state is SttListening) {
        final listeningState = state as SttListening;
        if (listeningState.transcription.isNotEmpty) {
          emit(SttResult(
            currentLanguage: _currentLanguage,
            targetLanguage: _targetLanguage,
            transcription: listeningState.transcription,
            translatedText: listeningState.translatedText,
            isFinal: true,
          ));
          return;
        }
      }

      emit(SttReady(
        currentLanguage: _currentLanguage,
        targetLanguage: _targetLanguage,
        availableLocales: const [],
      ));
    } catch (e, stackTrace) {
      Logger.severe('Failed to stop listening', e, stackTrace);
      emit(SttError('停止聆聽失敗: $e', currentLanguage: _currentLanguage));
    }
  }

  Future<void> _onChangeLanguage(
    ChangeLanguage event,
    Emitter<SttState> emit,
  ) async {
    _currentLanguage = event.languageCode;
    Logger.info('Source Language changed to: $_currentLanguage');

    if (state is SttReady) {
      final currentState = state as SttReady;
      emit(SttReady(
        currentLanguage: _currentLanguage,
        targetLanguage: _targetLanguage,
        availableLocales: currentState.availableLocales,
      ));
    }
  }

  Future<void> _onChangeTargetLanguage(
    ChangeTargetLanguage event,
    Emitter<SttState> emit,
  ) async {
    _targetLanguage = event.languageCode;
    Logger.info('Target Language changed to: $_targetLanguage');

    if (state is SttReady) {
      final currentState = state as SttReady;
      emit(SttReady(
        currentLanguage: _currentLanguage,
        targetLanguage: _targetLanguage,
        availableLocales: currentState.availableLocales,
      ));
    } else if (state is SttResult) {
      final currentState = state as SttResult;
      emit(const SttDownloadingModel('翻譯中...'));

      final translated = await _translationService.translate(
        currentState.transcription,
        _currentLanguage,
        _targetLanguage,
      );

      emit(SttResult(
        currentLanguage: _currentLanguage,
        targetLanguage: _targetLanguage,
        transcription: currentState.transcription,
        translatedText: translated,
        isFinal: true,
      ));
    }
  }

  Future<void> _onUpdateTranscription(
    UpdateTranscription event,
    Emitter<SttState> emit,
  ) async {
    if (state is SttListening) {
      final translated = await _translationService.translate(
        event.text,
        _currentLanguage,
        _targetLanguage,
      );

      emit(SttListening(
        currentLanguage: _currentLanguage,
        targetLanguage: _targetLanguage,
        transcription: event.text,
        translatedText: translated,
      ));
    }
  }

  Future<void> _onOpenLanguageSettings(
    OpenLanguageSettings event,
    Emitter<SttState> emit,
  ) async {
    try {
      await _sttService.openLanguageSettings();
    } catch (e) {
      Logger.severe('Failed to open language settings: $e');
    }
  }

  @override
  Future<void> close() async {
    _translationService.dispose();
    await _sttService.dispose();
    super.close();
  }
}
