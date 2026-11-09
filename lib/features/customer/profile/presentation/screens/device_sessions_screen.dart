import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_dimensions.dart';
import '../../../../../core/security/device_session_service.dart';
import '../../../../../core/theme/theme_controller.dart';
import '../../../../../shared/widgets/gradient_app_bar.dart';
import '../../../../auth/presentation/controllers/auth_controller.dart';

class DeviceSessionsScreen extends ConsumerStatefulWidget {
  const DeviceSessionsScreen({super.key});

  @override
  ConsumerState<DeviceSessionsScreen> createState() => _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends ConsumerState<DeviceSessionsScreen> {
  bool _isLoading = true;
  List<UserSessionEntity> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final service = ref.read(deviceSessionServiceProvider);
    // Ensure current device session is registered
    await service.registerSession(user.id);
    final sessions = await service.getUserSessions(user.id);

    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  Future<void> _revokeSession(UserSessionEntity session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Device Session?'),
        content: Text(
          'This will immediately log out ${session.deviceName} and terminate all active sessions on that device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke Access', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(deviceSessionServiceProvider);
      await service.revokeSession(session.id);
      await _loadSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session revoked for ${session.deviceName}')),
        );
      }
    }
  }

  Future<void> _revokeAllOtherSessions() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out All Other Devices?'),
        content: const Text(
          'All other phones, tablets, or computers logged into your account will be signed out immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out Other Devices', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(deviceSessionServiceProvider);
      await service.revokeAllOtherSessions(user.id);
      await _loadSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out of all other devices successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = ref.watch(themeControllerProvider).palette;
    final otherSessionsCount = _sessions.where((s) => !s.isCurrent).length;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Active Device Sessions',
        subtitle: 'Multi-Device Access & Session Revocation',
        showThemePicker: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSessions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppDimensions.p20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Banner Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131A29) : Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(
                          color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.devices_rounded,
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
                                  '${_sessions.length} Active Device${_sessions.length > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Devices currently logged into your Groclyra account with active SQLite authentication tokens.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Logged-in Devices',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ..._sessions.map((session) => _buildSessionTile(session, isDark, palette)),

                    if (otherSessionsCount > 0) ...[
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: Text('Sign Out All Other Devices ($otherSessionsCount)'),
                          onPressed: _revokeAllOtherSessions,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSessionTile(UserSessionEntity session, bool isDark, dynamic palette) {
    final dateFormat = DateFormat('MMM d, y • h:mm a');
    final formattedDate = dateFormat.format(session.lastActiveAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A29) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: session.isCurrent
              ? Colors.green.withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: session.isCurrent
                  ? Colors.green.withValues(alpha: 0.12)
                  : (isDark ? const Color(0xFF1B2433) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _resolveDeviceIcon(session.platform),
              color: session.isCurrent ? Colors.green : (isDark ? Colors.white70 : Colors.black54),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.deviceName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (session.isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'THIS DEVICE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.platform.toUpperCase()} • ${session.ipAddress ?? "Authorized Network"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last active: $formattedDate',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey[600],
                  ),
                ),
                if (!session.isCurrent) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.remove_circle_outline, size: 15),
                      label: const Text('Revoke Session', style: TextStyle(fontSize: 12)),
                      onPressed: () => _revokeSession(session),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _resolveDeviceIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('android') || p.contains('ios') || p.contains('mobile')) {
      return Icons.smartphone_rounded;
    }
    if (p.contains('web')) {
      return Icons.language_rounded;
    }
    if (p.contains('windows') || p.contains('pc')) {
      return Icons.desktop_windows_rounded;
    }
    if (p.contains('mac') || p.contains('darwin')) {
      return Icons.laptop_mac_rounded;
    }
    return Icons.devices_other_rounded;
  }
}

