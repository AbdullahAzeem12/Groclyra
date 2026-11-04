/// Connection/sync status for the admin platform.
/// This is the single source of truth for how live the data is.
enum ConnectionStatus {
  /// Most recent Firestore snapshot arrived within threshold
  live,

  /// Actively fetching / re-subscribing
  syncing,

  /// Waiting for first event
  connecting,

  /// Data is stale (last sync > staleThresholdSec ago) but not errored
  stale,

  /// Firestore returned an error / no network
  offline,

  /// Partially connected — some streams healthy, some degraded
  degraded,

  /// Permanent error that needs user action
  error,
}

extension ConnectionStatusLabel on ConnectionStatus {
  String get label {
    switch (this) {
      case ConnectionStatus.live:
        return 'Live';
      case ConnectionStatus.syncing:
        return 'Syncing...';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.stale:
        return 'Stale';
      case ConnectionStatus.offline:
        return 'Offline';
      case ConnectionStatus.degraded:
        return 'Degraded';
      case ConnectionStatus.error:
        return 'Error';
    }
  }

  bool get isHealthy => this == ConnectionStatus.live || this == ConnectionStatus.syncing;
}
