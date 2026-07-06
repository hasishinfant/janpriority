import 'dart:convert';
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
  List<Map<String, String>> _chatBubbleHistory = [];

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    super.dispose();
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

    // Mock Vision API duplicate/spam check for photos
    if (widget.mode == 'photo') {
      await Future.delayed(const Duration(seconds: 1));
      
      final descLower = _textController.text.toLowerCase();
      if (descLower.contains('spam') || descLower.contains('fake') || descLower.contains('stock')) {
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
              'Gemini Vision has flagged this photo as a likely duplicate, screenshot, or stock photo. Please upload a real photo of the site.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        return;
      }
    }

    await Future.delayed(const Duration(seconds: 1));
    
    final newSub = Submission(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
      citizenPhone: userPhone.substring(userPhone.length - 4).padLeft(userPhone.length, '*'),
      mode: widget.mode,
      originalText: _textController.text.isEmpty 
          ? (widget.mode == 'photo' ? 'Photo submission of Road blockage' : 'Text request')
          : _textController.text,
      originalLanguage: selectedLang,
      translatedText: _textController.text,
      category: widget.mode == 'photo' ? 'Roads' : 'Other',
      extractedLocation: {'ward': 'Ward 4', 'village': ''},
      severity: 0.6,
      sentiment: -0.3,
      status: 'Submitted',
      createdAt: DateTime.now(),
    );

    // Write to State
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
        
        // Start recording
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
          // Mock local path read
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
    final userPhone = ref.read(userPhoneProvider);

    // Call voice processing.
    // In a live environment with Firebase enabled, we'd trigger the Cloud Function.
    // We simulate the multi-turn conversational intake flow here for the demo.
    await Future.delayed(const Duration(seconds: 2));

    if (_voiceTurn == 1) {
      // Turn 1 complete: Speech-to-text outputs a grievance but no location
      final transcript = selectedLang == 'hi' 
          ? 'यहाँ वार्ड ४ में ३ दिनों से पीने का पानी नहीं आ रहा है।'
          : (selectedLang == 'kn' ? 'ನಮ್ಮ ವಾರ್ಡ್ ೪ ರಲ್ಲಿ ಕುಡಿಯುವ ನೀರು ಬರುತ್ತಿಲ್ಲ.' : 'There is no drinking water.');
      
      final followUp = selectedLang == 'hi'
          ? 'क्या आप बता सकते हैं कि यह किस वार्ड या गाँव में है?'
          : (selectedLang == 'kn' 
              ? 'ದಯವಿಟ್ಟು ಇದು ಯಾವ ವಾರ್ಡ್ ಅಥವಾ ಗ್ರಾಮದಲ್ಲಿದೆ ಎಂದು ಹೇಳಬಹುದೇ?'
              : (selectedLang == 'ta' 
                  ? 'தயவுசெய்து இது எந்த வார்டு அல்லது கிராமத்தில் உள்ளது என்று கூற முடியுமா?'
                  : 'Could you please tell me which ward or village this issue is located in?'));

      setState(() {
        _voiceTurn = 2;
        _turn1Text = transcript;
        _followUpQuestion = followUp;
        _previousExtraction = {
          'category': 'Water',
          'urgency': 'High',
          'description': 'No drinking water for 3 days'
        };
        _chatBubbleHistory.addAll([
          {'role': 'user', 'text': transcript},
          {'role': 'model', 'text': followUp},
        ]);
        _isProcessingVoice = false;
      });
    } else {
      // Turn 2 complete: location provided
      final responseText = selectedLang == 'hi' ? 'वार्ड ४' : (selectedLang == 'kn' ? 'ವಾರ್ಡ್ ೪' : 'Ward 4');
      
      setState(() {
        _chatBubbleHistory.add({'role': 'user', 'text': responseText});
        _isProcessingVoice = false;
        _isSubmitting = true;
      });

      await Future.delayed(const Duration(seconds: 1));

      // Finalize submission
      final newSub = Submission(
        id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
        citizenPhone: userPhone.substring(userPhone.length - 4).padLeft(userPhone.length, '*'),
        mode: 'voice',
        originalText: '$_turn1Text (Location: $responseText)',
        originalLanguage: selectedLang,
        translatedText: '$_turn1Text (Location: $responseText)',
        category: 'Water',
        extractedLocation: {'ward': 'Ward 4', 'village': ''},
        severity: 0.9,
        sentiment: -0.6,
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
                  children: [
                    _buildModeSpecificUI(lang),
                    const SizedBox(height: 24),
                    Text(getLocalizedText('location', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.red[400]),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('GPS: Ward 4 (Verified)')),
                          TextButton(onPressed: () {}, child: const Text('Edit')),
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
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(getLocalizedText('submit_request', lang), style: const TextStyle(fontSize: 18)),
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
          const Icon(Icons.record_voice_over, size: 48, color: Colors.orange),
          const SizedBox(height: 8),
          Text(
            _followUpQuestion ?? getLocalizedText('tap_mic', lang),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Conversation bubble list for feedback
          if (_chatBubbleHistory.isNotEmpty)
            Container(
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
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
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.orange[100] : Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(bubble['text'] ?? '', style: const TextStyle(fontSize: 14)),
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
                Text(getLocalizedText('processing', lang)),
              ],
            )
          else
            InkWell(
              onTap: _isRecording ? _stopRecording : _startRecording,
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? Colors.red : Colors.orange).withOpacity(0.4),
                      blurRadius: _isRecording ? 20 : 10,
                      spreadRadius: _isRecording ? 8 : 2,
                    )
                  ]
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
            
          const SizedBox(height: 12),
          Text(
            _isRecording ? getLocalizedText('listening', lang) : getLocalizedText('tap_record_label', lang),
            style: TextStyle(color: _isRecording ? Colors.red : Colors.grey[600]),
          ),
        ],
      );
    } else if (widget.mode == 'photo') {
      return Column(
        children: [
          InkWell(
            onTap: _pickImage,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _pickedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb 
                          ? Image.network(_pickedImage!.path, fit: BoxFit.cover, width: double.infinity)
                          : const Center(child: Text("Image loaded")),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Upload photo of the site', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _textController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: getLocalizedText('add_desc', lang),
              border: const OutlineInputBorder(),
            ),
          )
        ],
      );
    } else {
      // Text mode
      return TextField(
        controller: _textController,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: getLocalizedText('describe_pothole', lang),
          border: const OutlineInputBorder(),
        ),
      );
    }
  }
}
