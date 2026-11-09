import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:groclyra/core/database/backup/database_backup_service.dart';

/// Modal bottom sheet displaying real-time SQLite database diagnostics,
/// on-disk storage locations, table row counts, PRAGMA integrity checks,
/// defragmentation (VACUUM), and database backups.
class SqlDatabaseDiagnosticsSheet extends StatefulWidget {
  const SqlDatabaseDiagnosticsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SqlDatabaseDiagnosticsSheet(),
    );
  }

  @override
  State<SqlDatabaseDiagnosticsSheet> createState() =>
      _SqlDatabaseDiagnosticsSheetState();
}

class _SqlDatabaseDiagnosticsSheetState
    extends State<SqlDatabaseDiagnosticsSheet> {
  String? _dbPath;
  int _dbSizeBytes = 0;
  Map<String, int> _tableStats = {};
  Map<String, dynamic>? _integrityResult;
  bool _isLoading = true;
  bool _isActionRunning = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);
    final backupService = DatabaseBackupService.instance;
    final path = await backupService.getDatabasePath();
    final size = await backupService.getDatabaseSizeBytes();
    final stats = await backupService.getTableStatistics();

    if (mounted) {
      setState(() {
        _dbPath = path;
        _dbSizeBytes = size;
        _tableStats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _runIntegrityCheck() async {
    setState(() => _isActionRunning = true);
    final result = await DatabaseBackupService.instance.checkIntegrity();
    if (mounted) {
      setState(() {
        _integrityResult = result;
        _isActionRunning = false;
      });
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PRAGMA Integrity: ${result['integrityCheck'] ?? 'OK'} | Foreign Keys: ${result['foreignKeysCheck'] ?? 'OK'}',
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _runVacuum() async {
    setState(() => _isActionRunning = true);
    await DatabaseBackupService.instance.vacuumDatabase();
    await _loadDiagnostics();
    if (mounted) {
      setState(() => _isActionRunning = false);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database defragmented and vacuumed successfully.'),
          backgroundColor: Color(0xFF3B82F6),
        ),
      );
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isActionRunning = true);
    final backup = await DatabaseBackupService.instance.createBackupCopy();
    if (mounted) {
      setState(() => _isActionRunning = false);
      HapticFeedback.heavyImpact();
      if (backup != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup created: ${backup.path.split(RegExp(r'[\\/]')).last}'),
            backgroundColor: const Color(0xFF8B5CF6),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup creation note: Running in test/memory mode.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return 'In-Memory / Asset Mode';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalRows = _tableStats.values.fold(0, (sum, count) => sum + count);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 30,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storage_rounded,
                        color: Color(0xFF3B82F6),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SQL Realtime Database Engine',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'SQLite 3.x • groclyra.db • WAL ACID Architecture',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh Stats',
                      onPressed: _loadDiagnostics,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Physical storage location card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.folder_open_rounded,
                                      size: 16,
                                      color: Color(0xFF3B82F6),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Physical Database Path (On-Disk):',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_dbPath != null)
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Copy Path',
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: _dbPath!),
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Database path copied to clipboard'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  _dbPath ?? 'Loading database path...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'File Size: ${_formatBytes(_dbSizeBytes)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    Text(
                                      'Total Records: $totalRows rows',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Integrity Status Pill
                          if (_integrityResult != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF10B981),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'PRAGMA integrity_check: ${_integrityResult!['integrityCheck']} | Foreign Keys: ${_integrityResult!['foreignKeysCheck']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Actions Row
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.fact_check_outlined, size: 15),
                                  label: const Text('Integrity Check', style: TextStyle(fontSize: 11)),
                                  onPressed: _isActionRunning ? null : _runIntegrityCheck,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D9488),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.cleaning_services_rounded, size: 15),
                                  label: const Text('VACUUM', style: TextStyle(fontSize: 11)),
                                  onPressed: _isActionRunning ? null : _runVacuum,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.backup_rounded, size: 15),
                                  label: const Text('Backup .db', style: TextStyle(fontSize: 11)),
                                  onPressed: _isActionRunning ? null : _createBackup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Table row counts grid
                          const Text(
                            '18 Relational SQL Tables & Live Statistics',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 2.8,
                            ),
                            itemCount: _tableStats.length,
                            itemBuilder: (ctx, index) {
                              final entry = _tableStats.entries.elementAt(index);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : Colors.black12,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            entry.key,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'SQL Table',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? Colors.white38 : Colors.black45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${entry.value}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // Schema details note
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Schema source: assets/sql/schema.sql & lib/core/database/sql/schema.sql\n'
                              'Engine: SQLite (sqflite) with Foreign Keys & Automatic Triggers.\n'
                              'Reactivity: SqlRealtimeStreamManager table mutation broadcast bus.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

