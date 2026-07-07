// Web-only TTS implementation using the browser's SpeechSynthesis API.
// This uses dart:html directly so we avoid flutter_tts's async voice-loading bug.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Speaks [text] using the browser's SpeechSynthesis API.
/// Executes synchronously if voices are already available, preserving user gesture context.
void speakWeb(String text, List<String> localePriority) {
  final synth = html.window.speechSynthesis;
  if (synth == null) return;

  // Cancel any ongoing speech
  synth.cancel();

  final voices = synth.getVoices();
  if (voices.isNotEmpty) {
    _speakWithVoices(synth, text, localePriority, voices);
    return;
  }

  // If voices are not yet loaded, wait for the voiceschanged event.
  // Note: This async fallback might run outside the user gesture tick,
  // but it is only hit on initial load.
  html.window.on['voiceschanged'].first.then((_) {
    final loadedVoices = synth.getVoices();
    if (loadedVoices.isNotEmpty) {
      _speakWithVoices(synth, text, localePriority, loadedVoices);
    }
  });
}

void _speakWithVoices(html.SpeechSynthesis synth, String text,
    List<String> localePriority, List<html.SpeechSynthesisVoice> voices) {
  // Find the best matching voice for the requested locales
  html.SpeechSynthesisVoice? matchedVoice;
  for (final locale in localePriority) {
    for (final v in voices) {
      final voiceLang = v.lang ?? '';
      if (voiceLang.toLowerCase().startsWith(locale.toLowerCase())) {
        matchedVoice = v;
        break;
      }
    }
    if (matchedVoice != null) {
      break;
    }
  }

  // Build the utterance
  final utterance = html.SpeechSynthesisUtterance(text);
  utterance.rate = 0.9;
  utterance.pitch = 1.0;
  utterance.volume = 1.0;

  if (matchedVoice != null) {
    utterance.voice = matchedVoice;
    utterance.lang = matchedVoice.lang ?? localePriority.first;
  } else {
    // No matching voice installed — set the BCP-47 code anyway and let the
    // browser pick the closest available voice
    utterance.lang = localePriority.first;
  }

  synth.speak(utterance);
}

/// Cancels ongoing speech.
void stopWeb() {
  html.window.speechSynthesis?.cancel();
}

// ── Native stubs (never called on web but needed for conditional import) ──────
Future<void> speakNative(String text, String lang) async {}
Future<void> stopNative() async {}
