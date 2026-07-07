import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/firebase_service.dart';
import '../../../shared/services/language_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _verifyPhone() async {
    final lang = ref.read(selectedLanguageProvider);
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getLocalizedText('invalid_phone', lang))),
        );
      }
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _isLoading = false;
      _otpSent = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getLocalizedText('otp_sent_msg', lang))),
      );
    }
  }

  void _verifyOtp() async {
    final lang = ref.read(selectedLanguageProvider);
    final otp = _otpController.text.trim();
    if (otp != '123456' && otp.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getLocalizedText('invalid_otp', lang))),
        );
      }
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _isLoading = false);

    ref.read(userPhoneProvider.notifier).state = '+91 ${_phoneController.text}';

    if (mounted) {
      context.go('/citizen/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(selectedLanguageProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _otpSent
              ? getLocalizedText('otp_verification', lang)
              : getLocalizedText('login_title', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF002244),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Official Emblem
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF002244).withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 64,
                      color: Color(0xFF002244),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _otpSent
                      ? getLocalizedText('enter_otp', lang)
                      : getLocalizedText('secure_login', lang),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002244),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _otpSent
                      ? '${getLocalizedText('otp_sent_subtitle', lang)} +91 ${_phoneController.text}'
                      : getLocalizedText('login_subtitle', lang),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (!_otpSent) ...[
                  // Phone Input
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: getLocalizedText('mobile_label', lang),
                      prefixText: '+91 ',
                      prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      border: const OutlineInputBorder(),
                      counterText: '',
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF002244), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _verifyPhone,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF002244),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            getLocalizedText('get_otp', lang),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ] else ...[
                  // OTP Input
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: getLocalizedText('otp_pin_label', lang),
                      labelStyle: const TextStyle(letterSpacing: 0, fontSize: 16),
                      border: const OutlineInputBorder(),
                      counterText: '',
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF002244), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF002244),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            getLocalizedText('verify_proceed', lang),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _otpSent = false;
                        _otpController.clear();
                      });
                    },
                    child: Text(
                      getLocalizedText('edit_phone', lang),
                      style: const TextStyle(color: Color(0xFF002244)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
