import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Minimal logging surface.
///
/// The app used to swallow every I/O failure with `catch (_) {}`, which made
/// data-loss bugs invisible. Anything caught must now be reported here, and
/// anything the user needs to know about must additionally be surfaced
/// through the controllers' `lastError`.
void logError(String message, Object error, [StackTrace? stackTrace]) {
  developer.log(message, name: 'arpege', error: error, stackTrace: stackTrace);
  if (kDebugMode) {
    debugPrint('[arpege] $message: $error');
  }
}

void logInfo(String message) {
  developer.log(message, name: 'arpege');
}
