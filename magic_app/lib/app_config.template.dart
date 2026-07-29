// Template di configurazione
// Duplicare il file, rinominare in app_config.dart e inserire i valori reali

class AppConfig {
  // URL manifest (GitHub Gist) - Corso 1
  static const String manifestUrl = 'INSERIRE_MANIFEST_URL';

  // URL pacchetto ZIP (GitHub Releases) - Corso 1
  static const String packageUrl = 'INSERIRE_PACKAGE_URL';

  // ID pacchetto
  static const String packageId = 'INSERIRE_PACKAGE_ID';

  // VPN necessaria
  static get apiBaseUrl => 'INSERIRE_API_BASE_URL';

  // Aggiornare quando disponibile dataset Girolamini
  static get chatSelectCode => 'INSERIRE_CHAT_SELECT_CODE';

  // Cambia periodicamente
  static get chatBaseUrl => 'INSERIRE_CHAT_BASE_URL';
}
