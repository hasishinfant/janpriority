import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/language_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) {
      context.go('/citizen/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read selected language so splash also respects it if already set
    final lang = ref.watch(selectedLanguageProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF002244),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Official Emblem
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFF9933), width: 3),
                ),
                child: const Center(
                  child: Icon(
                    Icons.account_balance,
                    size: 48,
                    color: Color(0xFF002244),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                getLocalizedText('app_name', lang),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  getLocalizedText('app_tagline', lang),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              // National color stripes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 40, height: 4, color: const Color(0xFFFF9933)),
                  Container(width: 40, height: 4, color: Colors.white),
                  Container(width: 40, height: 4, color: const Color(0xFF128807)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                getLocalizedText('ministry_label', lang),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
