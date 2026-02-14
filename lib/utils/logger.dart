// Simple logger utility for debugging and monitoring

import 'package:flutter/foundation.dart';

class Logger {
  static void info(String message) {
    if (kDebugMode) {
      print('[INFO] ${DateTime.now()}: $message');
    }
  }

  static void severe(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('[ERROR] ${DateTime.now()}: $message');
      if (error != null) {
        print('Error: $error');
      }
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      print('[WARNING] ${DateTime.now()}: $message');
    }
  }
}
