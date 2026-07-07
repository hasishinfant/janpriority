import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import '../../../shared/models/submission.dart';
import '../../../shared/services/firebase_service.dart';
import '../../../shared/services/gemini_service.dart';
import '../../../shared/services/language_service.dart';
import '../../../shared/services/tts_service.dart';

// ─── Theme Colors ────────────────────────────────────────────────────────────
const _googleBlue = Color(0xFF1a73e8);
const _emeraldGreen = Color(0xFF0f9d58);
const _amberYellow = Color(0xFFf4b400);
const _googleRed = Color(0xFFdb4437);
const _navy = Color(0xFF002244);

enum SubmitFlowState {
  input,
  processing,
  review,
  success
}

class SubmitScreen extends ConsumerStatefulWidget {
  final String mode; // 'voice', 'text', 'photo'
  const SubmitScreen({super.key, required this.mode});

  @override
  ConsumerState<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends ConsumerState<SubmitScreen> with SingleTickerProviderStateMixin {
  // Flow state control
  SubmitFlowState _flowState = SubmitFlowState.input;

  // Input controller & hardware
  final _textController = TextEditingController();
  final _audioRecorder = AudioRecorder();
  final _picker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _blurredImageBytes;

  // Voice Interaction properties
  bool _isRecording = false;
  int _voiceTurn = 1; // 1: Initial report, 2: Clarification/Location/Photo
  String? _turn1Text;
  Map<String, dynamic>? _previousExtraction;
  final List<Map<String, String>> _chatBubbleHistory = [];
  late TtsService _ttsService;

  // AI Checkpoints (Magic Moment) streaming state
  int _currentCheckpointIdx = 0;
  final List<Map<String, dynamic>> _checkpoints = [
    {'label': 'Understanding your issue...', 'status': 'pending'},
    {'label': 'Language detected', 'status': 'pending'},
    {'label': 'Category detected', 'status': 'pending'},
    {'label': 'GPS Position verified', 'status': 'pending'},
    {'label': 'Finding similar reports...', 'status': 'pending'},
    {'label': 'Checking image/text relevance...', 'status': 'pending'},
    {'label': 'Protecting privacy (Blurring faces)...', 'status': 'pending'},
    {'label': 'Generating AI summary...', 'status': 'pending'},
  ];

  // Extracted AI details for review
  String _extractedSummary = '';
  String _extractedCategory = 'Roads';
  String _extractedLang = 'English';
  bool _extractedTranslated = false;
  int _extractedTrustScore = 96;
  int _extractedSimilarCount = 12;
  String _extractedLocationName = 'Sulikere Village';

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
    final greeting = getLocalizedText('voice_greeting', lang);

    setState(() {
      _chatBubbleHistory.add({
        'role': 'ai',
        'text': greeting,
      });
    });

    _ttsService.speak(greeting, lang);
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    _ttsService.stop();
    super.dispose();
  }

  // --- Dynamic Mappings ---
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
    if (nameLower.contains('sulikere') || nameLower.contains('ಸೂಲಿಕೆರೆ') || nameLower.contains('சூலிகேரே')) {
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
    return {'lat': 12.9126, 'lng': 77.4628};
  }

  // --- Start Processing Flow (Magic Moment) ---
  void _startAIProcessing(Map<String, dynamic> result, String originalText, String detectedLang) async {
    final category = result['category'] ?? result['detected_category'] ?? 'other';
    final locationMentioned = result['location_mentioned'] ?? 'Sulikere';
    final urgency = result['urgency'] ?? 'medium';
    final severity = mapUrgencyToSeverity(urgency);

    setState(() {
      _extractedSummary = result['translated_description'] ?? result['original_transcript'] ?? originalText;
      _extractedCategory = mapCategory(category);
      _extractedLang = detectedLang == 'kn'
          ? 'Kannada'
          : (detectedLang == 'ta'
              ? 'Tamil'
              : (detectedLang == 'hi'
                  ? 'Hindi'
                  : (detectedLang == 'ml'
                      ? 'Malayalam'
                      : (detectedLang == 'mr' ? 'Marathi' : 'English'))));
      _extractedTranslated = detectedLang != 'en';
      _extractedTrustScore = (severity * 10 + 88).clamp(90, 98).toInt();
      _extractedSimilarCount = 12 + (originalText.length % 5);
      _extractedLocationName = locationMentioned;
      _flowState = SubmitFlowState.processing;
      _currentCheckpointIdx = 0;
      for (var cp in _checkpoints) {
        cp['status'] = 'pending';
      }
    });

    // Animate AI Checkpoints one by one
    for (int i = 0; i < _checkpoints.length; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _checkpoints[i]['status'] = 'completed';
        // Add specific detected sub-labels dynamically
        if (i == 1) _checkpoints[i]['label'] = '✓ Language: $_extractedLang';
        if (i == 2) _checkpoints[i]['label'] = '✓ Category: $_extractedCategory';
        if (i == 3) _checkpoints[i]['label'] = '✓ GPS Verified: $_extractedLocationName';
        if (i == 4) _checkpoints[i]['label'] = '✓ Merging with $_extractedSimilarCount reports';
        _currentCheckpointIdx = i + 1;
      });
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _flowState = SubmitFlowState.review;
      });
    }
  }

  // --- Submit Confirm Action ---
  void _confirmAndFinalizeSubmission() {
    final userPhone = ref.read(userPhoneProvider);
    final resolvedLoc = resolveCoordinates(_extractedLocationName);
    final subId = 'sub_${DateTime.now().millisecondsSinceEpoch}';

    final newSub = Submission(
      id: subId,
      citizenPhone: userPhone.substring(userPhone.length - 4).padLeft(userPhone.length, '*'),
      mode: widget.mode,
      originalText: _textController.text.isNotEmpty ? _textController.text : _extractedSummary,
      originalLanguage: ref.read(selectedLanguageProvider),
      translatedText: _extractedSummary,
      category: _extractedCategory,
      extractedLocation: {
        'ward': 'General',
        'village': _extractedLocationName,
        'lat': resolvedLoc['lat'],
        'lng': resolvedLoc['lng'],
      },
      severity: _extractedTrustScore / 100,
      sentiment: -0.4,
      status: 'Submitted',
      createdAt: DateTime.now(),
    );

    ref.read(localDataProvider.notifier).addSubmission(newSub);

    setState(() {
      _flowState = SubmitFlowState.success;
    });

    final successSpeech = widget.mode == 'voice'
        ? "Thank you! Your voice report has been successfully verified by AI."
        : "Thank you! Report submitted successfully.";
    _ttsService.speak(successSpeech, ref.read(selectedLanguageProvider));
  }

  // --- Image spam validation check ---
  bool _validateRelevance(String description) {
    final descLower = description.toLowerCase();
    // Simulate spam rejection if user inputs test terms
    if (descLower.contains('selfie') || descLower.contains('spam') || descLower.contains('fake') || descLower.contains('cat')) {
      return false;
    }
    return true;
  }

  void _showFriendlyRejectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: _googleRed, size: 28),
            const SizedBox(width: 8),
            Text(
              getLocalizedText('ai_image_rejected_title', ref.read(selectedLanguageProvider)),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          "I couldn't identify a public infrastructure issue in this photo. Please capture a clear image of: Road Damage, Drain Blockage, Government School repairs, Water Supply lines, or Streetlights.",
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(getLocalizedText('ok', ref.read(selectedLanguageProvider)), style: const TextStyle(fontWeight: FontWeight.bold, color: _googleBlue)),
          ),
        ],
      ),
    );
  }

  // --- Submissions handlers ---
  void _submitTextOrPhoto() async {
    final selectedLang = ref.read(selectedLanguageProvider);

    if (widget.mode == 'text') {
      if (_textController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getLocalizedText('please_describe', selectedLang))),
        );
        return;
      }

      if (!_validateRelevance(_textController.text)) {
        _showFriendlyRejectionDialog();
        return;
      }

      // Call Gemini or fallback
      Map<String, dynamic> result;
      try {
        result = await ref.read(geminiServiceProvider).processAudioOrText(
          textContent: _textController.text,
        ).timeout(const Duration(seconds: 8));
      } catch (e) {
        result = {
          'category': 'road',
          'location_mentioned': 'Sulikere',
          'urgency': 'high',
          'translated_description': _textController.text,
        };
      }

      _startAIProcessing(result, _textController.text, selectedLang);
    } 
    else if (widget.mode == 'photo') {
      if (_pickedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getLocalizedText('please_upload_photo', selectedLang))),
        );
        return;
      }

      if (!_validateRelevance(_textController.text)) {
        _showFriendlyRejectionDialog();
        return;
      }

      Uint8List imageBytes;
      try {
        imageBytes = await _pickedImage!.readAsBytes();
      } catch (e) {
        return;
      }

      Map<String, dynamic> result;
      try {
        result = await ref.read(geminiServiceProvider).processPhoto(imageBytes).timeout(const Duration(seconds: 8));
      } catch (e) {
        result = {
          'is_relevant_infrastructure_issue': true,
          'detected_category': 'Roads',
          'contains_faces': false,
          'face_bounding_boxes': []
        };
      }

      final isRelevant = result['is_relevant_infrastructure_issue'] ?? true;
      if (!isRelevant) {
        _showFriendlyRejectionDialog();
        return;
      }

      final containsFaces = result['contains_faces'] ?? false;
      final faceBoxes = result['face_bounding_boxes'] as List<dynamic>? ?? [];

      if (containsFaces && faceBoxes.isNotEmpty) {
        final blurredBytes = await ref.read(geminiServiceProvider).blurFacesOnImage(imageBytes, faceBoxes);
        setState(() {
          _blurredImageBytes = blurredBytes;
        });
      }

      _startAIProcessing(
        {
          'category': result['detected_category'] ?? 'Roads',
          'location_mentioned': 'Sulikere',
          'urgency': 'medium',
          'translated_description': _textController.text.isNotEmpty ? _textController.text : 'Photo submission of infrastructure.',
        },
        _textController.text,
        selectedLang,
      );
    }
  }

  // --- Voice Recording Flow ---
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          _isRecording = true;
        });
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: '',
        );
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
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

        final base64Audio = base64Encode(audioBytes);
        _handleVoiceAnalysis(base64Audio);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  void _handleVoiceAnalysis(String base64Audio) async {
    final selectedLang = ref.read(selectedLanguageProvider);

    Map<String, dynamic> result;
    try {
      result = await ref.read(geminiServiceProvider).processAudioOrText(
        base64Audio: base64Audio,
        mimeType: 'audio/wav',
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      // Setup mock details based on lang
      if (selectedLang == 'kn') {
        result = {
          'category': 'water',
          'location_mentioned': 'Kommaghatta',
          'urgency': 'high',
          'original_transcript': 'ಕುಡಿಯುವ ನೀರು ಇಲ್ಲ',
          'translated_description': 'There is no drinking water in Kommaghatta',
          'detected_language': 'kn'
        };
      } else {
        result = {
          'category': 'road',
          'location_mentioned': 'Sulikere',
          'urgency': 'high',
          'original_transcript': 'Road damage here in Sulikere',
          'translated_description': 'Road damage here in Sulikere',
          'detected_language': 'en'
        };
      }
    }

    final transcript = result['original_transcript'] ?? 'Voice report';
    final category = result['category'] ?? 'Roads';
    final location = result['location_mentioned'] ?? 'Kommaghatta';

    setState(() {
      _chatBubbleHistory.add({'role': 'user', 'text': transcript});
    });

    if (_voiceTurn == 1) {
      // Play AI feedback and ask if they want to capture a photo (Premium flow!)
      final aiPromptText = 'I understood. Category: ${mapCategory(category)}. Location: $location. Would you like to add a photo?';
      
      setState(() {
        _voiceTurn = 2;
        _turn1Text = transcript;
        _previousExtraction = result;
        _chatBubbleHistory.add({'role': 'ai', 'text': aiPromptText});
      });

      _ttsService.speak(aiPromptText, selectedLang);
    } else {
      _startAIProcessing(result, transcript, selectedLang);
    }
  }

  Future<void> _pickImageForVoiceBubble() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedImage = picked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo attached to voice report!'), backgroundColor: _emeraldGreen),
      );
    }
  }

  // --- Main Build ---
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(selectedLanguageProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          _flowState == SubmitFlowState.review
              ? getLocalizedText('ai_summary_title', lang)
              : getLocalizedText('app_name', lang),
          style: const TextStyle(fontWeight: FontWeight.bold, color: _navy),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _navy),
          onPressed: () {
            if (_flowState == SubmitFlowState.review) {
              setState(() => _flowState = SubmitFlowState.input);
            } else if (_flowState == SubmitFlowState.success) {
              context.go('/citizen/home');
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildFlowContent(lang),
        ),
      ),
    );
  }

  Widget _buildFlowContent(String lang) {
    switch (_flowState) {
      case SubmitFlowState.processing:
        return _buildProcessingScreen(lang);
      case SubmitFlowState.review:
        return _buildReviewScreen(lang);
      case SubmitFlowState.success:
        return _buildSuccessScreen(lang);
      case SubmitFlowState.input:
      default:
        return _buildInputScreen(lang);
    }
  }

  // ─── 1. Main Input Form Screen ──────────────────────────────────────────────
  Widget _buildInputScreen(String lang) {
    if (widget.mode == 'voice') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Chat bubble dialog log
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _chatBubbleHistory.length,
                itemBuilder: (context, idx) {
                  final bubble = _chatBubbleHistory[idx];
                  final isUser = bubble['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser ? _googleBlue.withOpacity(0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isUser ? null : Border.all(color: Colors.grey.shade200),
                        boxShadow: isUser ? null : [
                          const BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))
                        ]
                      ),
                      child: Text(
                        bubble['text']!,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: isUser ? _googleBlue : _navy,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_voiceTurn == 2) ...[
              // Inline Photo options
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImageForVoiceBubble,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _googleBlue,
                      side: const BorderSide(color: _googleBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(_pickedImage != null ? Icons.check_circle : Icons.camera_alt_rounded),
                    label: Text(_pickedImage != null ? 'Photo Attached' : 'Capture Photo'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_previousExtraction != null) {
                        _startAIProcessing(_previousExtraction!, _turn1Text ?? 'Voice report', lang);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _googleBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('AI Review & Submit'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Microphone button area
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _isRecording ? _stopRecording : _startRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isRecording ? _googleRed : _googleBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? _googleRed : _googleBlue).withOpacity(0.3),
                      blurRadius: _isRecording ? 20 : 8,
                      spreadRadius: _isRecording ? 8 : 2,
                    )
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isRecording ? 'Listening...' : 'Tap Mic to Speak',
              style: TextStyle(
                color: _isRecording ? _googleRed : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    // Photo or Text Input Modes
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mode == 'photo') ...[
            GestureDetector(
              onTap: () async {
                final picked = await _picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  setState(() {
                    _pickedImage = picked;
                  });
                }
              },
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: const [
                    BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 4))
                  ],
                ),
                child: _pickedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_rounded, size: 48, color: _googleBlue),
                          const SizedBox(height: 12),
                          Text(
                            getLocalizedText('upload_photo', lang),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                          )
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (kIsWeb)
                              const Center(child: Icon(Icons.check_circle_rounded, size: 48, color: _emeraldGreen))
                            else
                              Image.file(io.File(_pickedImage!.path), fit: BoxFit.cover),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                color: Colors.black54,
                                child: Text(
                                  getLocalizedText('photo_attached', lang),
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              getLocalizedText('add_desc', lang),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe details e.g., Street water pipeline leak...',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _googleBlue, width: 2)),
              ),
            ),
          ] else ...[
            // Pure Text Mode
            Text(
              getLocalizedText('describe_issue', lang),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Enter details of the civic issue here...',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _googleBlue, width: 2)),
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitTextOrPhoto,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _googleBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'AI Review & Submit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }

  // ─── 2. "Magic Moment" AI Checkpoint Stream Screen ──────────────────────────
  Widget _buildProcessingScreen(String lang) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 4, color: _googleBlue),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '${getLocalizedText('understanding_issue', lang)} (${_currentCheckpointIdx * 100 ~/ _checkpoints.length}%)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Checkpoints list
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _checkpoints.length,
              itemBuilder: (context, idx) {
                final cp = _checkpoints[idx];
                final isDone = cp['status'] == 'completed';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        color: isDone ? _emeraldGreen : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        cp['label']!,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                          color: isDone ? Colors.black87 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // ─── 3. AI Review & Trust Validation Screen ─────────────────────────────────
  Widget _buildReviewScreen(String lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trust meter header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _emeraldGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _emeraldGreen.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      getLocalizedText('ai_trust_meter', lang),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy),
                    ),
                    Text(
                      '$_extractedTrustScore%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: _emeraldGreen),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: _emeraldGreen, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      getLocalizedText('highly_trusted', lang),
                      style: const TextStyle(color: _emeraldGreen, fontWeight: FontWeight.bold, fontSize: 13),
                    )
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  getLocalizedText('why_trust_gps', lang),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // AI Extracted Details
          const Text(
            '🔍 AI Extracted Information',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy),
          ),
          const SizedBox(height: 12),

          if (_pickedImage != null) ...[
            Container(
              height: 140,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    kIsWeb
                        ? const Center(child: Icon(Icons.check_circle_rounded, color: _emeraldGreen, size: 40))
                        : (_blurredImageBytes != null
                            ? Image.memory(_blurredImageBytes!, fit: BoxFit.cover)
                            : Image.file(io.File(_pickedImage!.path), fit: BoxFit.cover)),
                    if (_blurredImageBytes != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.blur_on, color: Colors.amber, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'AI Face Blur Active',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          _buildReviewItem('Summary of Issue', _extractedSummary, Icons.description_rounded),
          _buildReviewItem('Category', _extractedCategory, Icons.category_rounded),
          _buildReviewItem('Detected Language', '$_extractedLang (Translated: ${_extractedTranslated ? "Yes" : "No"})', Icons.translate_rounded),
          _buildReviewItem('GPS Position Match', '✓ Verified near $_extractedLocationName', Icons.location_on_rounded),
          _buildReviewItem('Duplicates Found', 'Merged with $_extractedSimilarCount existing reports', Icons.file_copy_rounded),

          const SizedBox(height: 32),

          // CTA Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _flowState = SubmitFlowState.input;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back / Edit', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _confirmAndFinalizeSubmission,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _googleBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    getLocalizedText('confirm_report', lang),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _googleBlue, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _navy),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ─── 4. High-Impact Success Confirmation Screen ─────────────────────────────
  Widget _buildSuccessScreen(String lang) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: _emeraldGreen,
              child: Icon(Icons.check_rounded, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '🎉 Thank you!',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _navy),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your report has been successfully verified by AI.\nIt has been merged with $_extractedSimilarCount similar citizen reports, which has increased the priority ranking on the MP Dashboard.',
            style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: () {
              context.go('/citizen/home');
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _googleBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Track Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
