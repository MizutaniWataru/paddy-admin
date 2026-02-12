const String kFieldDbBaseUrl = String.fromEnvironment(
  'PADDY_DB_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

const String kPaddyDbBaseUrl = kFieldDbBaseUrl;
const String kBaseUrl = kFieldDbBaseUrl;

const String kDebugOwnerId = String.fromEnvironment(
  'PADDY_DEBUG_OWNER_ID',
  defaultValue: 'owner_debug_001',
);

const String kDebugOwnerHeaderName = 'X-Debug-Owner-ID';
