// Native stub — used on non-web platforms via conditional import.
// The real implementation on native uses flutter_tts.
import 'package:flutter_tts/flutter_tts.dart';

final _flutterTts = FlutterTts();
bool _nativeInitialized = false;

Future<void> _initNative() async {
  if (_nativeInitialized) return;
  try {
    await _flutterTts.setSharedInstance(true);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _nativeInitialized = true;
  } catch (_) {}
}

String _mapLang(String lang) {
  switch (lang) {
    case 'ta': return 'ta-IN';
    case 'hi': return 'hi-IN';
    case 'kn': return 'kn-IN';
    case 'ml': return 'ml-IN';
    case 'mr': return 'mr-IN';
    default:   return 'en-IN';
  }
}

Future<void> speakNative(String text, String lang) async {
  await _initNative();
  try {
    await _flutterTts.setLanguage(_mapLang(lang));
    await _flutterTts.speak(text);
  } catch (_) {}
}

Future<void> stopNative() async {
  try { await _flutterTts.stop(); } catch (_) {}
}

// Web stubs — never actually called on native
void speakWeb(String text, List<String> localePriority) {}
void stopWeb() {}
