/// Règle d’upsert SO depuis le cloud (testable sans Drift).
bool shouldSkipSalesOrderRemoteUpsert({
  required int? localVersion,
  required int remoteVersion,
  required bool force,
}) {
  if (force) return false;
  if (localVersion == null) return false;
  return localVersion >= remoteVersion;
}
