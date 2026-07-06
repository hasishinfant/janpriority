import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedLanguageProvider = StateProvider<String>((ref) => 'en');

const supportedLanguages = {
  'en': 'English',
  'hi': 'हिन्दी (Hindi)',
  'kn': 'ಕನ್ನಡ (Kannada)',
  'ta': 'தமிழ் (Tamil)',
};

String getLocalizedText(String key, String lang) {
  const translations = {
    'new_request': {
      'en': 'New Request',
      'hi': 'नई शिकायत',
      'kn': 'ಹೊಸ ವಿನಂತಿ',
      'ta': 'புதிய கோரிக்கை',
    },
    'my_submissions': {
      'en': 'My Submissions',
      'hi': 'मेरी शिकायतें',
      'kn': 'ನನ್ನ ಸಲ್ಲಿಕೆಗಳು',
      'ta': 'எனது சமர்ப்பிப்புகள்',
    },
    'no_submissions': {
      'en': 'No submissions yet.',
      'hi': 'अभी तक कोई शिकायत नहीं है।',
      'kn': 'ಇನ್ನೂ ಯಾವುದೇ ಸಲ್ಲಿಕೆಗಳಿಲ್ಲ.',
      'ta': 'இன்னும் சமர்ப்பிப்புகள் இல்லை.',
    },
    'tap_mic': {
      'en': 'Tap the mic to start a natural conversation',
      'hi': 'प्राकृतिक बातचीत शुरू करने के लिए माइक पर टैप करें',
      'kn': 'ನೈಸರ್ಗಿಕ ಸಂಭಾಷಣೆಯನ್ನು ಪ್ರಾರಂಭಿಸಲು ಮೈಕ್ ಟ್ಯಾಪ್ ಮಾಡಿ',
      'ta': 'இயற்கையான உரையாடலைத் தொடங்க மைக்கைத் தட்டவும்',
    },
    'listening': {
      'en': 'Listening...',
      'hi': 'सुन रहा हूँ...',
      'kn': 'ಕೇಳಿಸಿಕೊಳ್ಳುತ್ತಿದ್ದೇನೆ...',
      'ta': 'கேட்டுக்கொண்டிருக்கிறது...',
    },
    'processing': {
      'en': 'Processing your voice...',
      'hi': 'आपकी आवाज को प्रोसेस किया जा रहा है...',
      'kn': 'ನಿಮ್ಮ ಧ್ವನಿಯನ್ನು ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲಾಗುತ್ತಿದೆ...',
      'ta': 'உங்கள் குரல் செயலாக்கப்படுகிறது...',
    },
    'location': {
      'en': 'Location',
      'hi': 'स्थान',
      'kn': 'ಸ್ಥಳ',
      'ta': 'இடம்',
    },
    'submit_request': {
      'en': 'Submit Request',
      'hi': 'शिकायत दर्ज करें',
      'kn': 'ವಿನಂತಿಯನ್ನು ಸಲ್ಲಿಸಿ',
      'ta': 'கோரிக்கையைச் சமர்ப்பிக்கவும்',
    },
    'success_msg': {
      'en': 'Request submitted successfully!',
      'hi': 'शिकायत सफलतापूर्वक दर्ज की गई!',
      'kn': 'ವಿನಂತಿಯನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಸಲ್ಲಿಸಲಾಗಿದೆ!',
      'ta': 'கோரிக்கை வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது!',
    },
    'offline_banner': {
      'en': 'Offline - Viewing Cached Data',
      'hi': 'ऑफ़लाइन - कैश्ड डेटा देख रहे हैं',
      'kn': 'ಆಫ್‌ಲೈನ್ - ಸಂಗ್ರಹಿಸಿದ ಡೇಟಾವನ್ನು ವೀಕ್ಷಿಸಲಾಗುತ್ತಿದೆ',
      'ta': 'ஆஃப்லைன் - தற்காலிக சேமிப்புத் தரவைப்பார்க்கிறது',
    },
    'community_board': {
      'en': 'Community Board',
      'hi': 'सामुदायिक बोर्ड',
      'kn': 'ಸಮುದಾಯ ಬೋರ್ಡ್',
      'ta': 'சமூக வாரியம்',
    },
    'upvote': {
      'en': 'Upvote',
      'hi': 'समर्थन करें',
      'kn': 'ಬೆಂಬಲಿಸು',
      'ta': 'ஆதரவு',
    },
    'tap_record_label': {
      'en': 'Tap to record details',
      'hi': 'विवरण रिकॉर्ड करने के लिए टैप करें',
      'kn': 'ವಿವರಗಳನ್ನು ರೆಕಾರ್ಡ್ ಮಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ',
      'ta': 'விவரங்களை பதிவு செய்ய தட்டவும்',
    },
    'add_desc': {
      'en': 'Add a description (optional)',
      'hi': 'विवरण जोड़ें (वैकल्पिक)',
      'kn': 'ವಿವರಣೆಯನ್ನು ಸೇರಿಸಿ (ಐಚ್ಛಿಕ)',
      'ta': 'விளக்கத்தைச் சேர்க்கவும் (விருப்பத்திற்குரியது)',
    },
    'describe_pothole': {
      'en': 'Describe the issue or request in detail...',
      'hi': 'समस्या या अनुरोध का विस्तार से वर्णन करें...',
      'kn': 'ಸಮಸ್ಯೆ ಅಥವಾ ವಿನಂತಿಯನ್ನು ವಿವರವಾಗಿ ವಿವರಿಸಿ...',
      'ta': 'சிக்கல் அல்லது கோரிக்கையை விரிவாக விவரிக்கவும்...',
    },
    'reconnecting': {
      'en': 'Reconnecting...',
      'hi': 'पुनः कनेक्ट कर रहा है...',
      'kn': 'ಮರುಸಂಪರ್ಕಿಸಲಾಗುತ್ತಿದೆ...',
      'ta': 'மீண்டும் இணைக்கிறது...',
    }
  };
  return translations[key]?[lang] ?? translations[key]?['en'] ?? key;
}
