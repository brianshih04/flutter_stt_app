// Language configuration constants for multi-language STT and Translation support

class SupportedLanguage {
  final String code;
  final String displayName;
  final String localeId;

  const SupportedLanguage({
    required this.code,
    required this.displayName,
    required this.localeId,
  });
}

class Languages {
  static const traditionalChinese = SupportedLanguage(
    code: 'zh-TW',
    displayName: '繁體中文',
    localeId: 'zh_TW',
  );

  static const english = SupportedLanguage(
    code: 'en-US',
    displayName: 'English (US)',
    localeId: 'en_US',
  );

  static const japanese = SupportedLanguage(
    code: 'ja-JP',
    displayName: '日本語',
    localeId: 'ja_JP',
  );

  static const russian = SupportedLanguage(
    code: 'ru-RU',
    displayName: 'Русский',
    localeId: 'ru_RU',
  );

  static const thai = SupportedLanguage(
    code: 'th-TH',
    displayName: 'ไทย',
    localeId: 'th_TH',
  );

  static const indonesian = SupportedLanguage(
    code: 'id-ID',
    displayName: 'Bahasa Indonesia',
    localeId: 'id_ID',
  );

  static const List<SupportedLanguage> all = [
    traditionalChinese,
    english,
    japanese,
    russian,
    thai,
    indonesian,
  ];

  static SupportedLanguage getByCode(String code) {
    return all.firstWhere(
      (lang) => lang.code == code,
      orElse: () => english,
    );
  }
}
