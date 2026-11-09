import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_dimensions.dart';
import '../../../../../core/database/backup/database_backup_service.dart';
import '../../../../../core/theme/theme_controller.dart';
import '../../../../../shared/widgets/gradient_app_bar.dart';
import '../../../../../shared/widgets/gradient_button.dart';

class DatabaseBackupScreen extends ConsumerStatefulWidget {
  const DatabaseBackupScreen({super.key});

  @override
  ConsumerState<DatabaseBackupScreen> createState() => _DatabaseBackupScreenState();
}

class _DatabaseBackupScreenState extends ConsumerState<DatabaseBackupScreen> {
  bool _isLoading = true;
  bool _isCreatingBackup = false;
  List<DatabaseBackupEntity> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final service = ref.read(databaseBackupServiceProvider);
    final list = await service.listBackups();
    if (mounted) {
      setState(() {
        _backups = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _createBackup() async {
    final passphraseController = TextEditingController();

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Encrypted Database Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A complete snapshot of all 26 relational SQLite tables will be encrypted with AES-256 and saved locally.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passphraseController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Optional Encryption Passphrase',
                hintText: 'Leave empty for default vault key',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create Backup'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      setState(() => _isCreatingBackup = true);
      try {
        final service = ref.read(databaseBackupServiceProvider);
        final passphrase = passphraseController.text.trim();
        final entity = await service.createEncryptedBackup(
          userPassphrase: passphrase.isNotEmpty ? passphrase : null,
        );
        await _loadBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup created: ${entity.fileName} (${entity.formattedSize}) ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isCreatingBackup = false);
      }
    }
  }

  Future<void> _exportBackup(DatabaseBackupEntity backup) async {
    try {
      final service = ref.read(databaseBackupServiceProvider);
      await service.exportBackup(backup);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _restoreBackup(DatabaseBackupEntity backup) async {
    final passphraseController = TextEditingController();

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Backup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restoring will replace the active SQLite database with the snapshot from ${backup.fileName}. All tables and records will be overwritten.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passphraseController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Passphrase (if custom key was used)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore Database', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (proceed == true) {
      setState(() => _isLoading = true);
      try {
        final service = ref.read(databaseBackupServiceProvider);
        final passphrase = passphraseController.text.trim();
        final success = await service.restoreBackupFromFile(
          backup.filePath,
          userPassphrase: passphrase.isNotEmpty ? passphrase : null,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database successfully restored and re-synchronized ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restore error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteBackup(DatabaseBackupEntity backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup Snapshot?'),
        content: Text('Delete ${backup.fileName} permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(databaseBackupServiceProvider);
      await service.deleteBackup(backup);
      await _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup snapshot deleted.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = ref.watch(themeControllerProvider).palette;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Database Backup & Recovery',
        subtitle: 'AES-256 Encrypted SQLite Snapshots',
        showThemePicker: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBackups,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppDimensions.p20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Overview Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131A29) : Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(
                          color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: palette.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.storage_rounded,
                                  color: palette.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SQLite Relational Engine',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '26 Synchronized Tables • groclyra.db',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'HEALTHY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GradientButton(
                            text: 'Create Encrypted Backup Now',
                            isLoading: _isCreatingBackup,
                            onPressed: _createBackup,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Saved Backup Snapshots (${_backups.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_backups.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131A29) : Colors.white,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                          border: Border.all(
                            color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'No backups created yet.',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap the button above to generate your first encrypted database snapshot.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ..._backups.map((b) => _buildBackupTile(b, isDark, palette)),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBackupTile(DatabaseBackupEntity backup, bool isDark, dynamic palette) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final formattedDate = dateFormat.format(backup.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A29) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.lock_outline_rounded, color: palette.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backup.fileName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$formattedDate • ${backup.formattedSize}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'SHA-256: ${backup.checksum.substring(0, 16)}...',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Export / Share'),
                onPressed: () => _exportBackup(backup),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Restore'),
                onPressed: () => _restoreBackup(backup),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                tooltip: 'Delete Backup',
                onPressed: () => _deleteBackup(backup),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

