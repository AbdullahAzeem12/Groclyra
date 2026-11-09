import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/realtime/sql_realtime_stream.dart';

enum SyncMode {
  standalone, // Local database only (default)
  hubServer,  // This device acts as the local Wi-Fi / LAN Sync Hub server
  clientPeer, // This device connects to a remote Hub Server IP
}

class SyncStatus {
  final SyncMode mode;
  final bool isConnected;
  final int connectedPeersCount;
  final String? hostAddress;
  final int port;
  final DateTime? lastSyncTime;
  final String? statusMessage;

  const SyncStatus({
    required this.mode,
    required this.isConnected,
    this.connectedPeersCount = 0,
    this.hostAddress,
    this.port = 8999,
    this.lastSyncTime,
    this.statusMessage,
  });

  SyncStatus copyWith({
    SyncMode? mode,
    bool? isConnected,
    int? connectedPeersCount,
    String? hostAddress,
    int? port,
    DateTime? lastSyncTime,
    String? statusMessage,
  }) {
    return SyncStatus(
      mode: mode ?? this.mode,
      isConnected: isConnected ?? this.isConnected,
      connectedPeersCount: connectedPeersCount ?? this.connectedPeersCount,
      hostAddress: hostAddress ?? this.hostAddress,
      port: port ?? this.port,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

final sqliteNetworkSyncProvider =
    StateNotifierProvider<SqliteNetworkSyncNotifier, SyncStatus>((ref) {
  return SqliteNetworkSyncNotifier();
});

class SqliteNetworkSyncNotifier extends StateNotifier<SyncStatus> {
  HttpServer? _server;
  final List<WebSocket> _clientSockets = [];
  WebSocket? _outgoingSocket;
  StreamSubscription<String>? _dbMutationSub;
  bool _isApplyingRemoteMutation = false;

  SqliteNetworkSyncNotifier()
      : super(const SyncStatus(
          mode: SyncMode.standalone,
          isConnected: false,
          statusMessage: 'Local SQLite Standalone Mode',
        )) {
    _initPreferences();
    _listenLocalDatabaseChanges();
  }

  Future<void> _initPreferences() async {
    try {
      final rows = await AppDatabase.instance.query(
        'app_preferences',
        where: 'key = ?',
        whereArgs: ['sync_mode'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final modeStr = rows.first['value']?.toString();
        final hostRows = await AppDatabase.instance.query(
          'app_preferences',
          where: 'key = ?',
          whereArgs: ['sync_host_ip'],
          limit: 1,
        );
        final hostIp = hostRows.isNotEmpty ? hostRows.first['value']?.toString() : '192.168.1.100';

        if (modeStr == 'hubServer') {
          await startHubServer();
        } else if (modeStr == 'clientPeer' && hostIp != null) {
          await connectAsClient(hostIp);
        }
      }
    } catch (e) {
      debugPrint('[NetworkSync] Prefs init notice: $e');
    }
  }

  void _listenLocalDatabaseChanges() {
    _dbMutationSub = SqlRealtimeStreamManager.instance.tableChanges.listen((table) {
      if (_isApplyingRemoteMutation) return;
      _broadcastLocalTableChange(table);
    });
  }

  /// Broadcasts local table mutation to connected peers or the server hub
  Future<void> _broadcastLocalTableChange(String table) async {
    // Only synchronize enterprise transactional tables
    const syncableTables = {
      'orders',
      'order_items',
      'delivery_tasks',
      'products',
      'seller_profiles',
      'rider_profiles',
      'users',
      'addresses',
    };

    if (!syncableTables.contains(table.toLowerCase())) return;

    try {
      final rows = await AppDatabase.instance.query(
        table,
        orderBy: 'updatedAt DESC, createdAt DESC',
        limit: 10,
      );

      final payload = jsonEncode({
        'type': 'TABLE_UPDATE',
        'table': table,
        'timestamp': DateTime.now().toIso8601String(),
        'rows': rows,
      });

      if (state.mode == SyncMode.hubServer) {
        for (final ws in List<WebSocket>.from(_clientSockets)) {
          try {
            ws.add(payload);
          } catch (_) {}
        }
      } else if (state.mode == SyncMode.clientPeer && _outgoingSocket != null) {
        _outgoingSocket!.add(payload);
      }
    } catch (e) {
      debugPrint('[NetworkSync] Broadcast error for $table: $e');
    }
  }

  /// Starts the embedded WebSocket & HTTP Sync Hub Server on this device
  Future<void> startHubServer({int port = 8999}) async {
    await stopSync();

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      state = state.copyWith(
        mode: SyncMode.hubServer,
        isConnected: true,
        port: port,
        statusMessage: 'Hub Server listening on port $port',
      );

      _persistPreference('sync_mode', 'hubServer');

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _clientSockets.add(socket);
          state = state.copyWith(connectedPeersCount: _clientSockets.length);

          // Send initial snapshot on new peer connection
          _sendSnapshotToSocket(socket);

          socket.listen(
            (data) => _handleIncomingMessage(data, fromSocket: socket),
            onDone: () {
              _clientSockets.remove(socket);
              state = state.copyWith(connectedPeersCount: _clientSockets.length);
            },
            onError: (err) {
              _clientSockets.remove(socket);
              state = state.copyWith(connectedPeersCount: _clientSockets.length);
            },
          );
        } else {
          // HTTP Health check response
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'app': 'Groclyra Sync Hub',
              'status': 'ONLINE',
              'connectedPeers': _clientSockets.length,
              'timestamp': DateTime.now().toIso8601String(),
            }))
            ..close();
        }
      });
    } catch (e) {
      debugPrint('[NetworkSync] Failed to start hub server: $e');
      state = state.copyWith(
        mode: SyncMode.standalone,
        isConnected: false,
        statusMessage: 'Hub server failed to start: $e',
      );
    }
  }

  /// Connects to a remote Hub Server as a Client Peer
  Future<void> connectAsClient(String hostIp, {int port = 8999}) async {
    await stopSync();

    state = state.copyWith(
      mode: SyncMode.clientPeer,
      hostAddress: hostIp,
      port: port,
      statusMessage: 'Connecting to ws://$hostIp:$port...',
    );

    try {
      _outgoingSocket = await WebSocket.connect(
        'ws://$hostIp:$port',
      ).timeout(const Duration(seconds: 6));

      state = state.copyWith(
        isConnected: true,
        connectedPeersCount: 1,
        statusMessage: 'Connected to Hub at $hostIp:$port',
        lastSyncTime: DateTime.now(),
      );

      _persistPreference('sync_mode', 'clientPeer');
      _persistPreference('sync_host_ip', hostIp);

      _outgoingSocket!.listen(
        (data) => _handleIncomingMessage(data),
        onDone: () {
          state = state.copyWith(
            isConnected: false,
            connectedPeersCount: 0,
            statusMessage: 'Disconnected from Hub server',
          );
        },
        onError: (err) {
          state = state.copyWith(
            isConnected: false,
            connectedPeersCount: 0,
            statusMessage: 'Connection error: $err',
          );
        },
      );
    } catch (e) {
      debugPrint('[NetworkSync] Client connection error: $e');
      state = state.copyWith(
        isConnected: false,
        statusMessage: 'Could not connect to $hostIp:$port ($e)',
      );
    }
  }

  Future<void> _handleIncomingMessage(dynamic rawData, {WebSocket? fromSocket}) async {
    try {
      final json = jsonDecode(rawData as String) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'TABLE_UPDATE' || type == 'SNAPSHOT') {
        final table = json['table'] as String;
        final rows = List<Map<String, dynamic>>.from(
          (json['rows'] as List? ?? []).map((r) => Map<String, dynamic>.from(r as Map)),
        );

        _isApplyingRemoteMutation = true;
        for (final row in rows) {
          await AppDatabase.instance.insertOrReplace(table, row);
        }
        _isApplyingRemoteMutation = false;

        AppDatabase.instance.notifyTable(table);

        state = state.copyWith(lastSyncTime: DateTime.now());

        // If hub server, relay to other peers
        if (state.mode == SyncMode.hubServer && fromSocket != null) {
          final broadcastPayload = rawData;
          for (final ws in _clientSockets) {
            if (ws != fromSocket) {
              try {
                ws.add(broadcastPayload);
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      _isApplyingRemoteMutation = false;
      debugPrint('[NetworkSync] Incoming message processing error: $e');
    }
  }

  Future<void> _sendSnapshotToSocket(WebSocket socket) async {
    const keyTables = ['orders', 'delivery_tasks', 'products', 'seller_profiles', 'rider_profiles'];
    for (final table in keyTables) {
      try {
        final rows = await AppDatabase.instance.query(table, limit: 100);
        if (rows.isNotEmpty) {
          socket.add(jsonEncode({
            'type': 'SNAPSHOT',
            'table': table,
            'rows': rows,
          }));
        }
      } catch (_) {}
    }
  }

  Future<void> stopSync() async {
    for (final ws in _clientSockets) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _clientSockets.clear();

    try {
      await _outgoingSocket?.close();
    } catch (_) {}
    _outgoingSocket = null;

    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;

    state = const SyncStatus(
      mode: SyncMode.standalone,
      isConnected: false,
      statusMessage: 'Standalone SQLite Mode',
    );

    _persistPreference('sync_mode', 'standalone');
  }

  Future<void> _persistPreference(String key, String value) async {
    try {
      await AppDatabase.instance.insertOrReplace('app_preferences', {
        'key': key,
        'value': value,
        'category': 'network_sync',
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _dbMutationSub?.cancel();
    stopSync();
    super.dispose();
  }
}

