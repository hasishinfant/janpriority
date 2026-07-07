import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../shared/services/language_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _gpsChecked = false;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectAndSetLanguage();
    });
  }

  Future<void> _detectAndSetLanguage() async {
    if (_gpsChecked) return;
    _gpsChecked = true;

    setState(() => _isDetecting = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isDetecting = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isDetecting = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isDetecting = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 3));

      final detectedLang = detectStateLanguage(position.latitude, position.longitude);
      ref.read(selectedLanguageProvider.notifier).state = detectedLang;

      if (mounted) {
        final lang = ref.read(selectedLanguageProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getLocalizedText('location_detected', lang)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error detecting language via GPS: $e');
    } finally {
      if (mounted) {
        setState(() => _isDetecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguage = ref.watch(selectedLanguageProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          getLocalizedText('app_name', selectedLanguage),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF002244)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.account_balance, size: 80, color: Color(0xFF002244)),
              const SizedBox(height: 24),
              Text(
                getLocalizedText('welcome_title', selectedLanguage),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF002244),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                getLocalizedText('welcome_subtitle', selectedLanguage),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Language selector label with GPS spinner
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    getLocalizedText('select_language', selectedLanguage),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  if (_isDetecting) ...[
                    const SizedBox(width: 10),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF002244),
                      ),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 16),
              ...supportedLanguages.entries.map((entry) {
                final isSelected = selectedLanguage == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? const Color(0xFF002244) : Colors.grey[100],
                      foregroundColor: isSelected ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: isSelected ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF002244) : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    onPressed: () {
                      ref.read(selectedLanguageProvider.notifier).state = entry.key;
                    },
                    child: Text(entry.value, style: const TextStyle(fontSize: 16)),
                  ),
                );
              }),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  context.go('/citizen/login');
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF002244),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  getLocalizedText('continue_btn', selectedLanguage),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
