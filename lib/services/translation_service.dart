import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../utils/logger.dart';

class TranslationService {
  OnDeviceTranslator? _translator;
  String _currentSourceLang = '';
  String _currentTargetLang = '';

  // Get ML Kit TranslateLanguage from our app's language code
  TranslateLanguage _getTranslateLanguage(String languageCode) {
    switch (languageCode) {
      case 'zh-TW':
        return TranslateLanguage.chinese;
      case 'en-US':
        return TranslateLanguage.english;
      case 'ja-JP':
        return TranslateLanguage.japanese;
      case 'ru-RU':
        return TranslateLanguage.russian;
      case 'th-TH':
        return TranslateLanguage.thai;
      case 'id-ID':
        return TranslateLanguage.indonesian;
      default:
        return TranslateLanguage.english;
    }
  }

  // Initialize or update the translator instance
  Future<void> _updateTranslator(String sourceLang, String targetLang) async {
    if (_translator != null &&
        _currentSourceLang == sourceLang &&
        _currentTargetLang == targetLang) {
      return; // Already configured
    }

    _disposeTranslator();

    final source = _getTranslateLanguage(sourceLang);
    final target = _getTranslateLanguage(targetLang);

    Logger.info('Initializing translator: $sourceLang -> $targetLang');

    _translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );

    _currentSourceLang = sourceLang;
    _currentTargetLang = targetLang;
  }

  // Ensure models are downloaded
  Future<bool> downloadModels(String sourceLang, String targetLang) async {
    try {
      final source = _getTranslateLanguage(sourceLang);
      final target = _getTranslateLanguage(targetLang);
      final modelManager = OnDeviceTranslatorModelManager();

      Logger.info(
          'Checking/Downloading models for $sourceLang and $targetLang');

      final bool sourceDownloaded =
          await modelManager.isModelDownloaded(source.bcpCode);
      if (!sourceDownloaded) {
        Logger.info('Downloading source model: ${source.bcpCode}');
        final result = await modelManager.downloadModel(source.bcpCode);
        if (!result) {
          Logger.severe('Failed to download source model: ${source.bcpCode}');
          return false;
        }
      }

      final bool targetDownloaded =
          await modelManager.isModelDownloaded(target.bcpCode);
      if (!targetDownloaded) {
        Logger.info('Downloading target model: ${target.bcpCode}');
        final result = await modelManager.downloadModel(target.bcpCode);
        if (!result) {
          Logger.severe('Failed to download target model: ${target.bcpCode}');
          return false;
        }
      }

      return true;
    } catch (e, stackTrace) {
      Logger.severe('Error downloading models', e, stackTrace);
      return false;
    }
  }

  // Translate text
  Future<String> translate(
      String text, String sourceLang, String targetLang) async {
    if (text.isEmpty) return '';
    if (sourceLang == targetLang) return text;

    try {
      await _updateTranslator(sourceLang, targetLang);

      if (_translator == null) {
        throw Exception('Translator not initialized');
      }

      final result = await _translator!.translateText(text);
      Logger.info('Translation: "$text" -> "$result"');
      return result;
    } catch (e, stackTrace) {
      Logger.severe('Translation failed', e, stackTrace);
      return 'Translation Error';
    }
  }

  void _disposeTranslator() {
    _translator?.close();
    _translator = null;
  }

  void dispose() {
    _disposeTranslator();
  }
}
