import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

class GeminiService {
  String getGeminiApiKey() {
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    if (!kIsWeb) {
      try {
        final key = io.Platform.environment['GEMINI_API_KEY'];
        if (key != null && key.isNotEmpty) return key;
      } catch (_) {}
      try {
        final envFile = io.File('.env');
        if (envFile.existsSync()) {
          final lines = envFile.readAsLinesSync();
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('GEMINI_API_KEY=')) {
              final val = trimmed.split('GEMINI_API_KEY=')[1].trim();
              if (val.isNotEmpty && !val.contains('YOUR_GEMINI_API_KEY_HERE')) {
                return val;
              }
            }
          }
        }
      } catch (_) {}
    }
    return 'MOCK_KEY';
  }

  Future<Map<String, dynamic>> processAudioOrText({
    String? base64Audio,
    String? mimeType,
    String? textContent,
  }) async {
    final apiKey = getGeminiApiKey();
    if (apiKey == 'MOCK_KEY' || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not configured.');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final List<Map<String, dynamic>> parts = [];
    if (base64Audio != null && mimeType != null) {
      parts.add({
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Audio,
        }
      });
    }
    if (textContent != null) {
      parts.add({'text': textContent});
    }

    parts.add({
      'text': 'Transcribe this content, detect the spoken language or text language, translate the content to English, and extract structured civic complaint data. Return ONLY valid JSON matching the exact schema, no other text.'
    });

    final requestBody = {
      'contents': [
        {
          'parts': parts,
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'object',
          'properties': {
            'detected_language': {'type': 'string'},
            'original_transcript': {'type': 'string'},
            'translated_description': {'type': 'string'},
            'category': {
              'type': 'string',
              'enum': [
                'road',
                'water',
                'electricity',
                'sanitation',
                'education',
                'health',
                'other'
              ]
            },
            'urgency': {
              'type': 'string',
              'enum': ['low', 'medium', 'high']
            },
            'location_mentioned': {'type': 'string'},
            'confidence': {'type': 'number'}
          },
          'required': [
            'detected_language',
            'translated_description',
            'category',
            'urgency',
            'confidence'
          ]
        }
      }
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API call failed with status ${response.statusCode}: ${response.body}');
    }

    final jsonResponse = jsonDecode(response.body);
    final text = jsonResponse['candidates'][0]['content']['parts'][0]['text'] as String;
    return jsonDecode(text.trim()) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> processPhoto(Uint8List imageBytes) async {
    final apiKey = getGeminiApiKey();
    if (apiKey == 'MOCK_KEY' || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not configured.');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final base64Image = base64Encode(imageBytes);

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            },
            {
              'text': 'Analyze this image. Determine if it shows a relevant infrastructure or civic issue (e.g. road damage, water leakage, sanitation issue, etc.), detect its category, flag if there are human faces, and locate bounding boxes for any faces. Return ONLY valid JSON matching the exact schema.'
            }
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'object',
          'properties': {
            'is_relevant_infrastructure_issue': {'type': 'boolean'},
            'detected_category': {'type': 'string'},
            'confidence': {'type': 'number'},
            'contains_faces': {'type': 'boolean'},
            'face_bounding_boxes': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'x': {'type': 'number'},
                  'y': {'type': 'number'},
                  'width': {'type': 'number'},
                  'height': {'type': 'number'}
                }
              }
            }
          }
        }
      }
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini Vision API call failed with status ${response.statusCode}: ${response.body}');
    }

    final jsonResponse = jsonDecode(response.body);
    final text = jsonResponse['candidates'][0]['content']['parts'][0]['text'] as String;
    return jsonDecode(text.trim()) as Map<String, dynamic>;
  }

  Future<Uint8List> blurFacesOnImage(Uint8List imageBytes, List<dynamic> boundingBoxes) async {
    if (boundingBoxes.isEmpty) return imageBytes;

    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

      canvas.drawImage(image, Offset.zero, Paint());

      for (final box in boundingBoxes) {
        if (box is! Map) continue;
        double x = (box['x'] as num).toDouble();
        double y = (box['y'] as num).toDouble();
        double w = (box['width'] as num).toDouble();
        double h = (box['height'] as num).toDouble();

        // Check if coordinates are in [0, 1000] range instead of [0.0, 1.0]
        if (x > 1.0 || y > 1.0 || w > 1.0 || h > 1.0) {
          x /= 1000.0;
          y /= 1000.0;
          w /= 1000.0;
          h /= 1000.0;
        }

        final rect = Rect.fromLTWH(
          x * image.width,
          y * image.height,
          w * image.width,
          h * image.height,
        );

        final paint = Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0);

        canvas.saveLayer(rect, paint);
        canvas.drawImage(image, Offset.zero, Paint());
        canvas.restore();
      }

      final picture = recorder.endRecording();
      final imgBlurred = await picture.toImage(image.width, image.height);
      final byteData = await imgBlurred.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return imageBytes;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error blurring faces on client side: $e');
      return imageBytes;
    }
  }
}
