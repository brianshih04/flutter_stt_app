import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/logger.dart';
import '../constants/languages.dart';

class SttService {
  static const _methodChannel = MethodChannel('com.antigravity.stt/speech');
  static const _eventChannel =
      EventChannel('com.antigravity.stt/speech_events');

  String _currentLocale = Languages.english.localeId;
  bool _isAvailable = false;
  bool _isListening = false;

  StreamSubscription? _eventSubscription;

  // Callbacks set during listening
  Function(String text)? _onResult;
  Function(bool isFinal)? _onFinalResult;
  Function(String status)? _onStatusCallback;
  Function(dynamic error)? _onErrorCallback;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  String get currentLocale => _currentLocale;

  /// Initialize speech recognition using native Android SpeechRecognizer.
  /// Includes automatic retry logic (up to 3 attempts).
  Future<Map<String, dynamic>> initialize({
    required Function(String status) onStatus,
    required Function(dynamic error) onError,
  }) async {
    _onStatusCallback = onStatus;
    _onErrorCallback = onError;

    Logger.info('Initializing native STT service...');

    // Try up to 3 times with delay between attempts
    for (int attempt = 1; attempt <= 3; attempt++) {
      Logger.info('Initialization attempt $attempt/3');

      try {
        final result = await _methodChannel
            .invokeMethod('initialize')
            .timeout(const Duration(seconds: 8), onTimeout: () {
          Logger.severe('Native initialize timed out (attempt $attempt)');
          return {
            'success': false,
            'error': 'timeout',
            'message': 'Initialization timed out'
          };
        });

        final Map<String, dynamic> resultMap =
            Map<String, dynamic>.from(result as Map);

        if (resultMap['success'] == true) {
          _isAvailable = true;
          Logger.info(
              'Native STT initialized successfully on attempt $attempt');

          // Set up event channel listener
          _setupEventListener();

          return {'success': true};
        }

        final errorType = resultMap['error'] ?? 'unknown';
        final errorMessage = resultMap['message'] ?? 'Unknown error';
        Logger.severe(
            'Init attempt $attempt failed: $errorType — $errorMessage');

        if (errorType == 'recognizer_not_available') {
          // No point retrying if recognizer doesn't exist
          return {
            'success': false,
            'error': 'recognizer_not_available',
            'message': errorMessage,
          };
        }

        // Wait before retrying
        if (attempt < 3) {
          Logger.info('Waiting 2s before retry...');
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e, stackTrace) {
        Logger.severe('Init attempt $attempt exception', e, stackTrace);

        if (attempt == 3) {
          return {
            'success': false,
            'error': 'exception',
            'message': e.toString(),
          };
        }

        await Future.delayed(const Duration(seconds: 2));
      }
    }

    return {
      'success': false,
      'error': 'max_retries',
      'message': '初始化失敗（已重試3次）',
    };
  }

  void _setupEventListener() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final type = event['type'] as String?;
          Logger.info('Native event: $type');

          switch (type) {
            case 'status':
              final status = event['status'] as String? ?? '';
              final message = event['message'] as String?;
              
              Logger.info('Status: $status ${message != null ? "($message)" : ""}');
              _onStatusCallback?.call(status);
              
              if (status == 'listening') {
                _isListening = true;
              } else if (status == 'speechDetected') {
                // Speech detected - user is speaking
                _isListening = true;
                if (message != null) {
                  Logger.info('Speech detected: $message');
                }
              } else if (status == 'speechEnd') {
                _isListening = false;
              }
              break;

            case 'result':
              final text = event['text'] as String? ?? '';
              final isFinal = event['isFinal'] as bool? ?? false;
              Logger.info(
                  'Recognition ${isFinal ? "final" : "partial"}: $text');
              _onResult?.call(text);
              if (isFinal) {
                _isListening = false;
                _onFinalResult?.call(true);
                _onStatusCallback?.call('done');
              }
              break;

            case 'error':
              final errorCode = event['errorCode'] as int? ?? -1;
              final errorMessage =
                  event['errorMessage'] as String? ?? 'unknown';
              Logger.severe('Native STT error: $errorCode ($errorMessage)');
              _isListening = false;

              // Show user-friendly message
              String userMessage = _getUserFriendlyError(errorMessage);
              _onErrorCallback
                  ?.call('Android錯誤: $userMessage\n(code: $errorMessage)');
              _onStatusCallback?.call('error');
              break;
          }
        }
      },
      onError: (error) {
        Logger.severe('EventChannel error: $error');
        _onErrorCallback?.call(error);
      },
    );
  }

  /// Start listening with specified locale
  Future<void> startListening({
    required String localeId,
    required Function(String text) onResult,
    required Function(bool isFinal) onFinalResult,
  }) async {
    _currentLocale = localeId;
    _onResult = onResult;
    _onFinalResult = onFinalResult;

    Logger.info('Starting native listening with locale: $localeId');

    try {
      // Re-setup event listener to ensure it's fresh
      _setupEventListener();

      final result = await _methodChannel.invokeMethod('startListening', {
        'localeId': localeId,
      });

      final Map<String, dynamic> resultMap =
          Map<String, dynamic>.from(result as Map);

      if (resultMap['success'] != true) {
        final error = resultMap['error'] ?? 'unknown';
        final message = resultMap['message'] ?? '';
        throw Exception('startListening failed: $error — $message');
      }

      _isListening = true;
    } catch (e, stackTrace) {
      Logger.severe('Failed to start native listening', e, stackTrace);
      rethrow;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    try {
      Logger.info('Stopping native listening...');
      await _methodChannel.invokeMethod('stopListening');
      _isListening = false;
    } catch (e, stackTrace) {
      Logger.severe('Failed to stop listening', e, stackTrace);
      rethrow;
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    try {
      Logger.info('Cancelling native listening...');
      await _methodChannel.invokeMethod('cancelListening');
      _isListening = false;
    } catch (e, stackTrace) {
      Logger.severe('Failed to cancel listening', e, stackTrace);
      rethrow;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    try {
      await _methodChannel.invokeMethod('dispose');
    } catch (e) {
      Logger.severe('Failed to dispose native STT: $e');
    }
  }

  String _getUserFriendlyError(String errorCode) {
    switch (errorCode) {
      case 'error_permission':
        return '麥克風權限被拒絕';
      case 'error_network':
        return '網路錯誤';
      case 'error_network_timeout':
        return '網路超時';
      case 'error_no_match':
        return '沒有辨識到語音';
      case 'error_busy':
        return '語音辨識服務忙碌中';
      case 'error_server':
        return '伺服器錯誤';
      case 'error_speech_timeout':
        return '語音輸入超時（請說話）';
      case 'error_audio':
        return '音訊錯誤（麥克風可能被佔用）';
      case 'error_client':
        return '客戶端錯誤';
      case 'error_language_not_supported':
        return '不支援此語言';
      case 'error_language_unavailable':
        return '語言模型未下載';
      case 'error_too_many_requests':
        return '請求過於頻繁';
      default:
        return errorCode;
    }
  }
}
