import 'package:flutter/foundation.dart';

/// Système de logging structuré pour l'application.
///
/// Utilise print() en debug mode, silent en release mode.
class AppLogger {
  /// Log de niveau DEBUG
  static void d(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _log('DEBUG', message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log de niveau INFO
  static void i(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _log('INFO', message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log de niveau WARNING
  static void w(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _log('WARNING', message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log de niveau ERROR
  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _log('ERROR', message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log de niveau FATAL
  static void f(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _log('FATAL', message, error: error, stackTrace: stackTrace);
    }
  }

  static void _log(String level, String message, {Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [$level] $message';
    
    if (error != null) {
      print('$logMessage\nError: $error');
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
    } else {
      print(logMessage);
    }
  }
}
