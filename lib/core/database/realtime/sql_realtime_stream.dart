import 'dart:async';
import 'package:flutter/foundation.dart';

/// Groclyra SQL Realtime Stream Manager
/// Provides push-based reactivity over native SQLite tables.
class SqlRealtimeStreamManager {
  SqlRealtimeStreamManager._();
  static final SqlRealtimeStreamManager instance = SqlRealtimeStreamManager._();

  final StreamController<String> _bus = StreamController<String>.broadcast();

  /// Stream of table mutations. Emits the table name whenever an INSERT, UPDATE, or DELETE occurs.
  Stream<String> get tableChanges => _bus.stream;

  /// Watch a specific SQL table for mutations.
  Stream<String> watchTable(String table) {
    return _bus.stream.where((t) => t.toLowerCase() == table.toLowerCase());
  }

  /// Watch multiple SQL tables simultaneously (e.g. for joins or composite views).
  Stream<String> watchTables(Iterable<String> tables) {
    final lowerTables = tables.map((t) => t.toLowerCase()).toSet();
    return _bus.stream.where((t) => lowerTables.contains(t.toLowerCase()));
  }

  /// Notify that a table has been mutated in SQLite.
  void notifyTable(String table) {
    if (!_bus.isClosed) {
      _bus.add(table);
      debugPrint('[SqlRealtime] Broadcast mutation on table: $table');
    }
  }

  /// Creates a real-time reactive Stream from any asynchronous SQL query.
  /// Executes immediately with the initial query result, and re-executes whenever
  /// any of the watched tables are modified.
  Stream<T> createRealtimeQuery<T>({
    required List<String> watchTables,
    required Future<T> Function() query,
  }) async* {
    yield await query();

    final lowerTables = watchTables.map((t) => t.toLowerCase()).toSet();
    await for (final mutatedTable in _bus.stream) {
      if (lowerTables.contains(mutatedTable.toLowerCase())) {
        try {
          final result = await query();
          yield result;
        } catch (e) {
          debugPrint('[SqlRealtimeQuery] Error re-executing query for $mutatedTable: $e');
        }
      }
    }
  }

  void dispose() {
    _bus.close();
  }
}

