// Configurazione RevenueCat (vedi docs/TODO_strada_A.md, sezione 4).
//
// La SDK key Android è una chiave PUBBLICA (viene spedita dentro ogni copia
// dell'app), non un segreto — sta bene nel repo. È comunque overridabile con
// `--dart-define=REVENUECAT_ANDROID_KEY=goog_...` (fallback al valore reale,
// così F5 funziona senza configurazione extra). La secret key e il service
// account Google NON stanno mai qui.
const String kRevenueCatAndroidKey = String.fromEnvironment(
  'REVENUECAT_ANDROID_KEY',
  defaultValue: 'goog_vQpfCRECkEkLcKvxuURNNvGCdsB',
);

/// Entitlement che sblocca il premium (creato su RevenueCat).
const String kEntitlementPremium = 'premium';

/// Offering di default del progetto. `offerings.current` di solito basta;
/// questo è il fallback per nome.
const String kOfferingDefault = 'default';
