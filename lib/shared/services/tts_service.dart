import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Only import dart:html on web
import 'web_speech_stub.dart' if (dart.library.html) 'web_speech.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

class TtsService {
  // Map our app language codes → BCP-47 locale prefixes (in priority order)
  static const _langToBcp47 = <String, List<String>>{
    'ta': ['ta-IN', 'ta'],
    'hi': ['hi-IN', 'hi'],
    'kn': ['kn-IN', 'kn'],
    'ml': ['ml-IN', 'ml'],
    'mr': ['mr-IN', 'mr'],
    'en': ['en-IN', 'en-US', 'en-GB', 'en'],
  };

  Future<void> speak(String text, String lang) async {
    if (kIsWeb) {
      speakWeb(text, _langToBcp47[lang] ?? ['en-US']);
    } else {
      await speakNative(text, lang);
    }
  }

  Future<void> stop() async {
    if (kIsWeb) {
      stopWeb();
    } else {
      await stopNative();
    }
  }
}
