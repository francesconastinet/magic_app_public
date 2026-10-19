class AppConfig {
  static const String packageId = 'INSERIRE_PACKAGE_ID';
  static String get apiBaseUrl => 'INSERIRE_API_BASE_URL';
  static String get chatSelectCode => 'INSERIRE_CHAT_SELECT_CODE';
  static String get chatBaseUrl => 'INSERIRE_CHAT_BASE_URL';
  // tenant_id da mandare nel body della /query della chat. Vuoto = non viene
  // inviato, in build con --dart-define=TENANT_ID=...
  static String get tenantId => const String.fromEnvironment('TENANT_ID');
}