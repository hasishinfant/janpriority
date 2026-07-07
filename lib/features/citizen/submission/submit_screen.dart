import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../shared/services/language_service.dart';
import '../../../shared/services/firebase_service.dart';
import '../../../shared/models/submission.dart';
import '../../../shared/services/gemini_service.dart';
import '../../../shared/services/tts_service.dart';

class SubmitScreen extends ConsumerStatefulWidget {
  final String mode; // 'voice', 'text', 'photo'
  
  const SubmitScreen({super.key, required this.mode});

  @override
  ConsumerState<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends ConsumerState<SubmitScreen> {
  final _textController = TextEditingController();
  final _audioRecorder = AudioRecorder();
  final _picker = ImagePicker();
  
  XFile? _pickedImage;
  Uint8List? _blurredImageBytes;
  bool _isSubmitting = false;
  
  // Voice conversation state variables
  bool _isRecording = false;
  bool _isProcessingVoice = false;
  int _voiceTurn = 1;
  String? _turn1Text;
  String? _followUpQuestion;
  Map<String, dynamic>? _previousExtraction;
  final List<Map<String, String>> _chatBubbleHistory = [];
  late TtsService _ttsService;

  @override
  void initState() {
    super.initState();
    _ttsService = ref.read(ttsServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.mode == 'voice') {
        _playGreeting();
      }
    });
  }

  void _playGreeting() {
    final lang = ref.read(selectedLanguageProvider);
    // Use centralized translation — consistent with the rest of the app
    final greeting = getLocalizedText('voice_greeting', lang);

    // 1. Show greeting as a visible AI chat bubble so it's always readable,
    //    even if the browser doesn't have the regional TTS voice installed.
    setState(() {
      _chatBubbleHistory.insert(0, {
        'role': 'ai',
        'text': greeting,
      });
    });

    // 2. Also speak it — silently degrades if voice unavailable on this browser
    _ttsService.speak(greeting, lang);
  }


  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    _ttsService.stop();
    super.dispose();
  }

  String mapCategory(String geminiCategory) {
    switch (geminiCategory.toLowerCase()) {
      case 'road': return 'Roads';
      case 'water': return 'Water';
      case 'electricity': return 'Electricity';
      case 'sanitation': return 'Sanitation';
      case 'education': return 'Education';
      case 'health': return 'Health';
      default: return 'Other';
    }
  }

  double mapUrgencyToSeverity(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'high': return 0.9;
      case 'medium': return 0.6;
      case 'low': return 0.3;
      default: return 0.5;
    }
  }

  Map<String, double> resolveCoordinates(String locationName) {
    final nameLower = locationName.toLowerCase();
    if (nameLower.contains('sulikere') || nameLower.contains('ಸೂಲಿಕೆರೆ') || nameLower.contains('சூലிகேரே')) {
      return {'lat': 12.9126, 'lng': 77.4628};
    }
    if (nameLower.contains('kommaghatta') || nameLower.contains('ಕೊಮ್ಮಘಟ್ಟ')) {
      return {'lat': 12.9145, 'lng': 77.4789};
    }
    if (nameLower.contains('ramohalli') || nameLower.contains('ರಾಮೋಹಳ್ಳಿ')) {
      return {'lat': 12.8988, 'lng': 77.4520};
    }
    if (nameLower.contains('bheemanakuppe') || nameLower.contains('ഭീമനകുപ്പെ')) {
      return {'lat': 12.9056, 'lng': 77.4423};
    }
    if (nameLower.contains('kenchanapura')) {
      return {'lat': 12.9192, 'lng': 77.4589};
    }
    if (nameLower.contains('vanimel') || nameLower.contains('വാനിമേൽ')) {
      return {'lat': 11.7804, 'lng': 75.7204};
    }
    if (nameLower.contains('onchiam') || nameLower.contains('ഒഞ്ചിയം')) {
      return {'lat': 11.7288, 'lng': 75.6104};
    }
    if (nameLower.contains('sarma nagar') || nameLower.contains('சர்மா நகர்')) {
      return {'lat': 13.1145, 'lng': 80.2878};
    }
    if (nameLower.contains('ramabai nagar') || nameLower.contains('रमाबाई नगर')) {
      return {'lat': 19.0178, 'lng': 72.8478};
    }
    return {'lat': 12.9126, 'lng': 77.4628};
  }

  Map<String, dynamic> getDemoFallback(String selectedLang, String mode, {String? textInput}) {
    final text = textInput?.toLowerCase() ?? '';
    
    // Scenario 1: Sulikere School
    if (text.contains('school') || text.contains('roof') || text.contains('leak') || text.contains('ಶಾಲೆ') || text.contains('ಸೋರುತ್ತಿದೆ')) {
      return {
        'detected_language': 'en',
        'original_transcript': 'Primary school roof is leaking and needs urgent repair in Sulikere.',
        'translated_description': 'Primary school roof is leaking and needs urgent repair in Sulikere.',
        'category': 'education',
        'urgency': 'high',
        'location_mentioned': 'Sulikere',
        'confidence': 0.95,
      };
    }
    
    // Scenario 2: Kommaghatta Water
    if (text.contains('water') || text.contains('drinking') || text.contains('ಕುಡಿಯುವ ನೀರು') || text.contains('ನೀರು')) {
      return {
        'detected_language': 'en',
        'original_transcript': 'There is no drinking water in Kommaghatta for the last 3 days.',
        'translated_description': 'There is no drinking water in Kommaghatta for the last 3 days.',
        'category': 'water',
        'urgency': 'high',
        'location_mentioned': 'Kommaghatta',
        'confidence': 0.95,
      };
    }

    // State-based default fallbacks
    switch (selectedLang) {
      case 'kn': // Karnataka
        return {
          'detected_language': 'kn',
          'original_transcript': 'ರಸ್ತೆಯಲ್ಲಿ ಗಲೀಜು ನೀರು ನಿಂತಿದೆ ಮತ್ತು ವಾಸನೆ ಬರುತ್ತಿದೆ.',
          'translated_description': 'Dirty water is stagnant on the road and it smells.',
          'category': 'sanitation',
          'urgency': 'high',
          'location_mentioned': 'Sulikere',
          'confidence': 0.95,
        };
      case 'ml': // Kerala
        return {
          'detected_language': 'ml',
          'original_transcript': 'കുടിവെള്ള പൈപ്പ് പൊട്ടി വഴിയിൽ വെള്ളം ഒഴുകുന്നു.',
          'translated_description': 'Drinking water pipe is broken and water is flowing on the street.',
          'category': 'water',
          'urgency': 'high',
          'location_mentioned': 'Vanimel',
          'confidence': 0.95,
        };
      case 'ta': // Tamil Nadu
        return {
          'detected_language': 'ta',
          'original_transcript': 'தெруவில் குப்பை கொட்டப்பட்டு கிடக்கிறது.',
          'translated_description': 'Garbage is dumped on the street.',
          'category': 'sanitation',
          'urgency': 'high',
          'location_mentioned': 'Sarma Nagar',
          'confidence': 0.95,
        };
      case 'mr': // Maharashtra
        return {
          'detected_language': 'mr',
          'original_transcript': 'रस्त्यावरील लाईट बंद आहे.',
          'translated_description': 'Street light is not working.',
          'category': 'electricity',
          'urgency': 'medium',
          'location_mentioned': 'Ramabai Nagar',
          'confidence': 0.95,
        };
      default:
        return {
          'detected_language': 'en',
          'original_transcript': 'Primary school roof is leaking and needs urgent repair in Sulikere.',
          'translated_description': 'Primary school roof is leaking and needs urgent repair in Sulikere.',
          'category': 'education',
          'urgency': 'high',
          'location_mentioned': 'Sulikere',
          'confidence': 0.95,
        };
    }
  }

  void _submitTextOrPhoto() async {
    final selectedLang = ref.read(selectedLanguageProvider);
    final userPhone = ref.read(userPhoneProvider);
    
    if (widget.mode == 'text' && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    if (widget.mode == 'text') {
      Map<String, dynamic> result;
      try {
        result = await ref.read(geminiServiceProvider).processAudioOrText(
          textContent: _textController.text,
        ).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Gemini Text call failed or timed out: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${getLocalizedText('reconnecting', selectedLang)} (Using local fallback)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        result = getDemoFallback(selectedLang, 'text', textInput: _textController.text);
      }

      final detectedLang = result['detected_language'] ?? selectedLang;
      final originalTranscript = result['original_transcript'] ?? _textController.text;
      final translatedDescription = result['translated_description'] ?? _textController.text;
      final category = result['category'] ?? 'other';
      final urgency = result['urgency'] ?? 'medium';
      final locationMentioned = result['location_mentioned'] ?? 'Sulikere';

      final resolvedLoc = resolveCoordinates(locationMentioned);
      final subId = 'sub_${DateTime.now().millisecondsSinceEpoch}';

      final newSub = Submission(
        id: subId,
        citizenPhone: userPhone.substring(userPhone.length - 4).padLeft(userPhone.length, '*'),
        mode: 'text',
        originalText: originalTranscript,
        originalLanguage: detectedLang,
        translatedText: translatedDescription,
        category: mapCategory(category),
        extractedLocation: {
          'ward': 'General',
          'village': locationMentioned,
          'lat': resolvedLoc['lat'],
          'lng': resolvedLoc['lng'],
        },
        severity: mapUrgencyToSeverity(urgency),
        sentiment: -0.4,
        status: 'Submitted',
        createdAt: DateTime.now(),
      );

      ref.read(localDataProvider.notifier).addSubmission(newSub);
      
      setState(() => _isSubmitting = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getLocalizedText('success_msg', selectedLang))),
        );
        context.go('/citizen/home');
      }
    } 
    else if (widget.mode == 'photo') {
      if (_pickedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a photo of the site.')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      Map<String, dynamic> result;
      Uint8List imageBytes;
      try {
        imageBytes = await _pickedImage!.readAsBytes();
      } catch (e) {
        debugPrint('Error reading image bytes: $e');
        setState(() => _isSubmitting = false);
        return;
      }

      try {
        result = await ref.read(geminiServiceProvider).processPhoto(imageBytes).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Gemini Photo call failed or timed out: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${getLocalizedText('reconnecting', selectedLang)} (Using local fallback)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        final descLower = _textController.text.toLowerCase();
        final isSpam = descLower.contains('spam') || descLower.contains('fake') || descLower.contains('stock') || descLower.contains('selfie');
        result = {
          'is_relevant_infrastructure_issue': !isSpam,
          'detected_category': 'Roads',
          'confidence': 0.9,
          'contains_faces': false,
          'face_bounding_boxes': []
        };
      }

      final isRelevant = result['is_relevant_infrastructure_issue'] ?? true;
      if (!isRelevant) {
        setState(() => _isSubmitting = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('AI Alert: Image Rejected'),
              ],
            ),
            content: const Text(
              'Gemini Vision has flagged this photo as irrelevant to civic issues (spam or containing faces without scene context). Please retake a photo of the issue.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        return;
      }

      final category = result['detected_category'] ?? 'Roads';
      final containsFaces = result['contains_faces'] ?? false;
      final faceBoxes = result['face_bounding_boxes'] as List<dynamic>? ?? [];

      if (containsFaces && faceBoxes.isNotEmpty) {
        final blurredBytes = await ref.read(geminiServiceProvider).blurFacesOnImage(imageBytes, faceBoxes);
        setState(() {
          _blurredImageBytes = blurredBytes;
        });
      }

      final subId = 'sub_${DateTime.now().millisecondsSinceEpoch}';
      final newSub = Submission(
        id: subId,
        citizenPhone: userPhone.substring(userPhone.length - 4).padLeft(userPhone.length, '*'),
        mode: 'photo',
        originalText: _textController.text.isEmpty ? 'Photo submission of $category' : _textController.text,
        originalLanguage: selectedLang,
        translatedText: _textController.text.isEmpty ? 'Photo submission of $category' : _textController.text,
        category: mapCategory(category),
        extractedLocation: {'ward': 'General', 'village': 'Sulikere'},
        severity: 0.6,
        sentiment: -0.3,
        status: 'Submitted',
        createdAt: DateTime.now(),
      );

      ref.read(localDataProvider.notifier).addSubmission(newSub);
      
      setState(() => _isSubmitting = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getLocalizedText('success_msg', selectedLang))),
        );
        context.go('/citizen/home');
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          _isRecording = true;
          _isProcessingVoice = false;
        });
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: '',
        );
      }
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isProcessingVoice = true;
      });

      if (path != null) {
        Uint8List audioBytes;
        if (kIsWeb) {
          final response = await http.get(Uri.parse(path));
          audioBytes = response.bodyBytes;
        } else {
          final file = io.File(path);
          audioBytes = await file.readAsBytes();
        }

        String mimeType = 'audio/wav';
        if (path.endsWith('.mp3')) {
          mimeType = 'audio/mp3';
        } else if (path.endsWith('.m4a')) {
          mimeType = 'audio/m4a';
        } else if (path.endsWith('.aac')) {
          mimeType = 'audio/aac';
        } else if (path.endsWith('.webm')) {
          mimeType = 'audio/webm';
        } else if (path.endsWith('.ogg')) {
          mimeType = 'audio/ogg';
        }

        final base64Audio = base64Encode(audioBytes);
        _processVoiceInput(base64Audio, mimeType);
      } else {
        setState(() => _isProcessingVoice = false);
      }
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      setState(() => _isProcessingVoice = false);
    }
  }

  void _processVoiceInput(String base64Audio, String mimeType) async {
    final selectedLang = ref.read(selectedLanguageProvider);
    final userPhone = ref.read(userPhoneProvider);

    setState(() => _isProcessingVoice = true);

    Map<String, dynamic> result;
    try {
      result = await ref.read(geminiServiceProvider).processAudioOrText(
        base64Audio: base64Audio,
        mimeType: mimeType,
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Gemini Voice call failed or timed out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${getLocalizedText('reconnecting', selectedLang)} (Using local fallback)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      result = getDemoFallback(selectedLang, 'voice');
    }

    final detectedLang = result['detected_language'] ?? selectedLang;
    final originalTranscript = result['original_transcript'] ?? '';
    final translatedDescription = result['translated_description'] ?? '';
    final category = result['category'] ?? 'other';
    final urgency = result['urgency'] ?? 'medium';
    final locationMentioned = result['location_mentioned'];

    if (_voiceTurn == 1) {
      if (locationMentioned == null || locationMentioned.toString().trim().isEmpty) {
        String followUp = 'Could you please share the ward or village name of the site?';
        if (selectedLang == 'hi') followUp = 'क्या आप बता सकते हैं कि यह किस वार्ड या गाँव में है?';
        else if (selectedLang == 'kn') followUp = 'ದಯವಿಟ್ಟು ಇದು ಯಾವ ವಾರ್ಡ್ ಅಥವಾ ಗ್ರಾಮದಲ್ಲಿದೆ ಎಂದು ಹೇಳಬಹುದೇ?';
        else if (selectedLang == 'ta') followUp = 'தயவுசெய்து இது எந்த வார்டு அல்லது கிராமத்தில் உள்ளது என்று கூற முடியுமா?';
        else if (selectedLang == 'ml') followUp = 'ദയവായി ഇത് ഏത് വാർഡിലോ ഗ്രാമത്തിലോ ആണെന്ന് പറയാമോ?';
        else if (selectedLang == 'mr') followUp = 'कृपया आपण सांगू शकता का की ही कोणती वॉर्ड किंवा गाव आहे?';

        setState(() {
          _voiceTurn = 2;
          _turn1Text = originalTranscript;
          _previousExtraction = result;
          _followUpQuestion = followUp;
          _chatBubbleHistory.addAll([
            {'role': 'user', 'text': originalTranscript},
            {'role': 'model', 'text': followUp},
          ]);
          _isProcessingVoice = false;
        });

        // Speak the follow-up question out loud in detected language
        _ttsService.speak(followUp, detectedLang);
      } else {
        setState(() {
          _chatBubbleHistory.add({'role': 'user', 'text': originalTranscript});
          _isProcessingVoice = false;
          _isSubmitting = true;
        });

        final resolvedLoc = resolveCoordinates(locationMentioned);
        final subId = 'sub_${DateTime.now().millisecondsSinceEpoch}';
        final newSub = Submission(
          id: subId,
          citizenPhone: userPhone.substring(userPhone.length - 4).padLeft(userPhone.length, '*'),
          mode: 'voice',
          originalText: originalTranscript,
          originalLanguage: detectedLang,
          translatedText: translatedDescription,
          category: mapCategory(category),
          extractedLocation: {
            'ward': 'General',
            'village': locationMentioned,
            'lat': resolvedLoc['lat'],
            'lng': resolvedLoc['lng'],
          },
          severity: mapUrgencyToSeverity(urgency),
          sentiment: -0.4,
          status: 'Submitted',
          createdAt: DateTime.now(),
        );

        ref.read(localDataProvider.notifier).addSubmission(newSub);
        setState(() => _isSubmitting = false);

        String successMsg = "Thank you, your complaint has been submitted successfully.";
        if (detectedLang == 'ta') {
          successMsg = "நன்றி, உங்கள் புகார் வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது.";
        } else if (detectedLang == 'hi') {
          successMsg = "धन्यवाद, आपकी शिकायत सफलतापूर्वक दर्ज की गई है।";
        } else if (detectedLang == 'kn') {
          successMsg = "ಧನ್ಯವಾದಗಳು, ನಿಮ್ಮ ವಿನಂತಿಯನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಸಲ್ಲಿಸಲಾಗಿದೆ.";
        } else if (detectedLang == 'ml') {
          successMsg = "നന്ദി, നിങ്ങളുടെ പരാതി വിജയകരമായി സമർപ്പിച്ചു.";
        } else if (detectedLang == 'mr') {
          successMsg = "धन्यवाद, तुमची तक्रार यशस्वीरित्या दाखल झाली आहे.";
        }

        _ttsService.speak(successMsg, detectedLang);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(getLocalizedText('success_msg', selectedLang))),
          );
          Future.delayed(const Duration(milliseconds: 2500), () {
            if (mounted) {
              context.go('/citizen/home');
            }
          });
        }
      }
    } else {
      setState(() {
        _chatBubbleHistory.add({'role': 'user', 'text': originalTranscript});
        _isProcessingVoice = false;
        _isSubmitting = true;
      });

      final locationName = originalTranscript;
      final resolvedLoc = resolveCoordinates(locationName);
      
      final turn1Cat = _previousExtraction?['category'] ?? 'other';
      final turn1Urg = _previousExtraction?['urgency'] ?? 'medium';
      final turn1Transcript = _turn1Text ?? 'Voice complaint';
      final turn1Translation = _previousExtraction?['translated_description'] ?? turn1Transcript;

      final subId = 'sub_${DateTime.now().millisecondsSinceEpoch}';
      final newSub = Submission(
        id: subId,
        citizenPhone: userPhone.substring(userPhone.length - 4).padLeft(userPhone.length, '*'),
        mode: 'voice',
        originalText: '$turn1Transcript (Location: $locationName)',
        originalLanguage: detectedLang,
        translatedText: '$turn1Translation (Location: $locationName)',
        category: mapCategory(turn1Cat),
        extractedLocation: {
          'ward': 'General',
          'village': locationName,
          'lat': resolvedLoc['lat'],
          'lng': resolvedLoc['lng'],
        },
        severity: mapUrgencyToSeverity(turn1Urg),
        sentiment: -0.4,
        status: 'Submitted',
        createdAt: DateTime.now(),
      );

      ref.read(localDataProvider.notifier).addSubmission(newSub);
      setState(() => _isSubmitting = false);

      String successMsg = "Thank you, your complaint has been submitted successfully.";
      if (detectedLang == 'ta') {
        successMsg = "நன்றி, உங்கள் புகார் வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது.";
      } else if (detectedLang == 'hi') {
        successMsg = "धन्यवाद, आपकी शिकायत सफलतापूर्वक दर्ज की गई है।";
      } else if (detectedLang == 'kn') {
        successMsg = "ಧನ್ಯವಾದಗಳು, ನಿಮ್ಮ ವಿನಂತಿಯನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಸಲ್ಲಿಸಲಾಗಿದೆ.";
      } else if (detectedLang == 'ml') {
        successMsg = "നന്ദി, നിങ്ങളുടെ പരാതി വിജയകരമായി സമർപ്പിച്ചു.";
      } else if (detectedLang == 'mr') {
        successMsg = "धन्यवाद, तुमची तक्रार यशस्वीरित्या दाखल झाली आहे.";
      }

      _ttsService.speak(successMsg, detectedLang);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getLocalizedText('success_msg', selectedLang))),
        );
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            context.go('/citizen/home');
          }
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedImage = picked;
        _blurredImageBytes = null;
        _textController.text = 'Pothole on the main road of Sulikere'; // autofill demo details
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(selectedLanguageProvider);

    return Scaffold(
      appBar: AppBar(title: Text(getLocalizedText('new_request', lang))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModeSpecificUI(lang),
                    const SizedBox(height: 32),
                    Text(
                      getLocalizedText('location', lang),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.teal[800], size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              getLocalizedText('gps_detected', lang),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () {}, 
                            child: Text(getLocalizedText('edit', lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.mode != 'voice')
              FilledButton(
                onPressed: _isSubmitting ? null : _submitTextOrPhoto,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal[800],
                ),
                child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        getLocalizedText('submit_request', lang),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSpecificUI(String lang) {
    if (widget.mode == 'voice') {
      return Column(
        children: [
          const Icon(Icons.record_voice_over, size: 56, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            _followUpQuestion ?? getLocalizedText('tap_mic', lang),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Conversational Exchange UI Bubble History
          if (_chatBubbleHistory.isNotEmpty)
            Container(
              height: 250,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListView.builder(
                itemCount: _chatBubbleHistory.length,
                itemBuilder: (context, index) {
                  final bubble = _chatBubbleHistory[index];
                  final isUser = bubble['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.orange[100] : Colors.teal[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        bubble['text'] ?? '', 
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          const SizedBox(height: 24),

          if (_isProcessingVoice)
            Column(
              children: [
                const CircularProgressIndicator(color: Colors.orange),
                const SizedBox(height: 12),
                Text(getLocalizedText('processing', lang), style: const TextStyle(fontSize: 14)),
              ],
            )
          else
            InkWell(
              onTap: _isRecording ? _stopRecording : _startRecording,
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? Colors.red : Colors.orange).withOpacity(0.4),
                      blurRadius: _isRecording ? 16 : 8,
                      spreadRadius: _isRecording ? 6 : 2,
                    )
                  ]
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            
          const SizedBox(height: 16),
          Text(
            _isRecording ? getLocalizedText('listening', lang) : getLocalizedText('tap_record_label', lang),
            style: TextStyle(
              color: _isRecording ? Colors.red : Colors.grey[600], 
              fontSize: 14, 
              fontWeight: FontWeight.bold
            ),
          ),
        ],
      );
    } else if (widget.mode == 'photo') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _pickImage,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _pickedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (kIsWeb)
                            const Center(child: Icon(Icons.check_circle, size: 64, color: Colors.green))
                          else ...[
                            _blurredImageBytes != null
                                ? Image.memory(_blurredImageBytes!, fit: BoxFit.cover)
                                : Image.file(io.File(_pickedImage!.path), fit: BoxFit.cover),
                            Container(
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ],
                          const Center(
                            child: Icon(Icons.check_circle, size: 64, color: Colors.white),
                          ),
                          if (_blurredImageBytes != null)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.blur_on, color: Colors.amber, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'AI Face Blur Applied',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                getLocalizedText('photo_attached', lang),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo, size: 56, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            getLocalizedText('upload_photo', lang),
                            style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            getLocalizedText('add_desc', lang),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 3,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'e.g. Broken pipe flooding the road...',
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal[800]!, width: 2)),
            ),
          )
        ],
      );
    } else {
      // Text mode
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            getLocalizedText('describe_issue', lang),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 6,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: getLocalizedText('describe_pothole', lang),
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal[800]!, width: 2)),
            ),
          ),
        ],
      );
    }
  }
}
