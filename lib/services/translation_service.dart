import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class TranslationService {
  static const String _baseUrl = 'https://api.mymemory.translated.net/get';

  // 30+ languages
  static const Map<String, String> languages = {
    'en': 'English',
    'hi': 'हिन्दी',
    'bn': 'বাংলা',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'mr': 'मराठी',
    'gu': 'ગુજરાતી',
    'kn': 'ಕನ್ನಡ',
    'ml': 'മലയാളം',
    'pa': 'ਪੰਜਾਬੀ',
    'ur': 'اردو',
    'or': 'ଓଡ଼ିଆ',
    'as': 'অসমীয়া',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Português',
    'ru': 'Русский',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
    'ar': 'العربية',
    'tr': 'Türkçe',
    'fa': 'فارسی',
    'vi': 'Tiếng Việt',
    'th': 'ไทย',
    'id': 'Bahasa Indonesia',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'sw': 'Kiswahili',
    'he': 'עברית',
    'el': 'Ελληνικά',
  };

  final Map<String, String> _cache = {};
  String? getCached(String key) => _cache[key];
  void cache(String key, String value) => _cache[key] = value;
  void clearCache() => _cache.clear();

  /// Get current user's email for higher API limit (50K/day per user)
  String? get _userEmail {
    try {
      return FirebaseAuth.instance.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  /// Translate text from [fromLang] to [toLang]
  Future<String?> translate(
    String text,
    String toLang, {
    String fromLang = 'autodetect',
  }) async {
    if (text.trim().isEmpty) return null;
    if (fromLang != 'autodetect' && fromLang == toLang) return text;

    try {
      final email = _userEmail;

      // Build URL with user's email for 50K/day limit per user
      final baseQuery = 'q=${Uri.encodeComponent(text)}'
          '&langpair=${fromLang == 'autodetect' ? 'Autodetect' : fromLang}|$toLang';

      final emailParam = email != null ? '&de=${Uri.encodeComponent(email)}' : '';

      final url = Uri.parse('$_baseUrl?$baseQuery$emailParam');

      final response = await http.get(url).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translated = data['responseData']?['translatedText'];
        if (translated != null && translated.toString().isNotEmpty) {
          return translated.toString();
        }
      }
      return null;
    } catch (e) {
      print('Translation error: $e');
      return null;
    }
  }
}
