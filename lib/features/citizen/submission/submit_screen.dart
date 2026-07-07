import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import '../../../shared/services/language_service.dart';
import '../../../shared/services/firebase_service.dart';
import '../../../shared/models/submission.dart';

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
  bool _isSubmitting = false;
  
  // Voice conversation state variables
  bool _isRecording = false;
  bool _isProcessingVoice = false;
  int _voiceTurn = 1;
  String? _turn1Text;
  String? _followUpQuestion;
  Map<String, dynamic>? _previousExtraction;
  final List<Map<String, String>> _chatBubbleHistory = [];

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _submitTextOrPhoto() async {
    final selectedLang = ref.read(selectedLanguageProvider);
    final userPhone = ref.read(userPhoneProvider);
    final isFirebaseActive = ref.read(firebaseInitializedProvider);
    
    if (widget.mode == 'text' && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Mock Vision API duplicate/spam check for photos in local mode
    if (widget.mode == 'photo' && !isFirebaseActive) {
      await Future.delayed(const Duration(seconds: 1));
      
      final descLower = _textController.text.toLowerCase();
      if (descLower.contains('spam') || descLower.contains('fake') || descLower.contains('stock') || descLower.contains('selfie')) {
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
    }

    // Prepare new submission object
    final String subId = 'sub_${DateTime.now().millisecondsSinceEpoch}';
    final newSub = Submission(
      id: subId,
      citizenPhone: userPhone.substring(userPhone.length - 4).padLeft(userPhone.length, '*'),
      mode: widget.mode,
      originalText: _textController.text.isEmpty 
          ? (widget.mode == 'photo' ? 'Photo submission' : 'Text request')
          : _textController.text,
      originalLanguage: selectedLang,
      translatedText: _textController.text,
      category: widget.mode == 'photo' ? 'Roads' : 'Other',
      extractedLocation: {'ward': 'General', 'village': 'Sulikere'},
      severity: 0.6,
      sentiment: -0.3,
      status: 'Submitted',
      createdAt: DateTime.now(),
    );

    // Add submission (handles firestore or local cache dynamically)
    ref.read(localDataProvider.notifier).addSubmission(newSub);
    
    setState(() => _isSubmitting = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getLocalizedText('success_msg', selectedLang))),
      );
      context.go('/citizen/home');
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
          // Read local path (mocking bytes for local audio files)
          audioBytes = Uint8List(0);
        }
        final base64Audio = base64Encode(audioBytes);
        _processVoiceInput(base64Audio);
      } else {
        setState(() => _isProcessingVoice = false);
      }
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      setState(() => _isProcessingVoice = false);
    }
  }

  void _processVoiceInput(String base64Audio) async {
    final selectedLang = ref.read(selectedLanguageProvider);
    final isFirebaseActive = ref.read(firebaseInitializedProvider);

    if (isFirebaseActive) {
      try {
        // Trigger live Firebase Cloud Function
        final result = await FirebaseFunctions.instance
            .httpsCallable('processVoiceIntake')
            .call({
              'audio': base64Audio,
              'language': selectedLang,
              'chatHistory': _chatBubbleHistory,
              'previousExtraction': _previousExtraction
            });
        
        final resData = result.data;
        if (resData['status'] == 'need_location') {
          setState(() {
            _voiceTurn = 2;
            _followUpQuestion = resData['followUpQuestion'];
            _previousExtraction = resData['extractedData'];
            _chatBubbleHistory.addAll([
              {'role': 'user', 'text': resData['transcription'] ?? ''},
              {'role': 'model', 'text': resData['followUpQuestion'] ?? ''},
            ]);
            _isProcessingVoice = false;
          });
          return;
        } else {
          // Process success
          setState(() => _isProcessingVoice = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(getLocalizedText('success_msg', selectedLang))),
          );
          context.go('/citizen/home');
          return;
        }
      } catch (err) {
        debugPrint('Cloud Function failed, falling back to mock conversation: $err');
      }
    }

    // Mock Falling-Back Conversational Intake Loop
    await Future.delayed(const Duration(seconds: 2));

    if (_voiceTurn == 1) {
      // Turn 1: Speech-to-text transcribes a request, missing location
      final transcript = selectedLang == 'hi' 
          ? 'सड़क पर गंदा पानी जमा हो रहा है और बदबू आ रही है।'
          : (selectedLang == 'kn' ? 'ರಸ್ತೆಯಲ್ಲಿ ಗಲೀಜು ನೀರು ನಿಂತಿದೆ ಮತ್ತು ವಾಸನೆ ಬರುತ್ತಿದೆ.' : 'Garbage is piling up on the road.');
      
      final followUp = selectedLang == 'hi'
          ? 'क्या आप बता सकते हैं कि यह किस वार्ड या गाँव में है?'
          : (selectedLang == 'kn' 
              ? 'ದಯವಿಟ್ಟು ಇದು ಯಾವ ವಾರ್ಡ್ ಅಥವಾ ಗ್ರಾಮದಲ್ಲಿದೆ ಎಂದು ಹೇಳಬಹುದೇ?'
              : (selectedLang == 'ta' 
                  ? 'தயவுசெய்து இது எந்த வார்டு அல்லது கிராமத்தில் உள்ளது என்று கூற முடியுமா?'
                  : 'Could you please share the ward or village name of the site?'));

      setState(() {
        _voiceTurn = 2;
        _turn1Text = transcript;
        _followUpQuestion = followUp;
        _previousExtraction = {
          'category': 'Sanitation',
          'urgency': 'Medium',
          'description': 'Garbage piling up on the road'
        };
        _chatBubbleHistory.addAll([
          {'role': 'user', 'text': transcript},
          {'role': 'model', 'text': followUp},
        ]);
        _isProcessingVoice = false;
      });
    } else {
      // Turn 2: Location provided (e.g. Sulikere)
      final responseText = selectedLang == 'hi' ? 'सुलीकेरे' : (selectedLang == 'kn' ? 'ಸೂಲಿಕೆರೆ' : 'Sulikere');
      
      setState(() {
        _chatBubbleHistory.add({'role': 'user', 'text': responseText});
        _isProcessingVoice = false;
        _isSubmitting = true;
      });

      await Future.delayed(const Duration(seconds: 1));

      // Finalize submission
      final String userPhone = ref.read(userPhoneProvider);
      final newSub = Submission(
        id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
        citizenPhone: userPhone.substring(userPhone.length - 4).padLeft(userPhone.length, '*'),
        mode: 'voice',
        originalText: '$_turn1Text (Location: $responseText)',
        originalLanguage: selectedLang,
        translatedText: '$_turn1Text (Location: $responseText)',
        category: 'Sanitation',
        extractedLocation: {'ward': 'General', 'village': 'Sulikere'},
        severity: 0.7,
        sentiment: -0.5,
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

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedImage = picked;
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
                          const Expanded(
                            child: Text(
                              'Auto-Detected GPS: Sulikere Village',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () {}, 
                            child: const Text('Edit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                          const Center(
                            child: Icon(Icons.check_circle, size: 64, color: Colors.green),
                          ),
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(4),
                              child: const Text(
                                'Photo attached successfully',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 56, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'Upload photo of the site',
                            style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
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
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal[850]!, width: 2)),
            ),
          )
        ],
      );
    } else {
      // Text mode
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Describe grievance details:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 6,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: getLocalizedText('describe_pothole', lang),
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal[850]!, width: 2)),
            ),
          ),
        ],
      );
    }
  }
}
