import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/core/theme/gradient_palette.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/features/auth/domain/entities/user_entity.dart';
import 'package:groclyra/features/customer/notifications/domain/entities/notification_preferences_entity.dart';

void main() {
  group('Theme Engine & Palette Switching Tests', () {
    test('All 5 luxury gradient themes are defined with valid gradients and surfaces', () {
      final themes = [
        GradientPalette.synthDusk,
        GradientPalette.emeraldMarket,
        GradientPalette.oceanGlass,
        GradientPalette.roseQuartz,
        GradientPalette.midnightAurora,
      ];

      expect(themes.length, equals(5));

      for (final theme in themes) {
        expect(theme.name, isNotEmpty);
        expect(theme.primaryGradient, isNotEmpty);
        expect(theme.primaryGradient.length, greaterThanOrEqualTo(2));
        expect(theme.linearGradient, isA<LinearGradient>());
        expect(theme.darkSurface, isNotNull);
        expect(theme.lightSurface, isNotNull);
      }
    });

    test('ThemeController switches palettes and persists activeThemeId', () {
      final controller = ThemeController();

      expect(controller.state.palette.id, equals('emerald_market'));

      controller.setPalette(GradientPalette.synthDusk);
      expect(controller.state.palette.id, equals('synth_dusk'));
      expect(controller.state.palette.name, equals('Synth Dusk'));

      controller.setPalette(GradientPalette.midnightAurora);
      expect(controller.state.palette.id, equals('midnight_aurora'));
    });

    test('ThemeController supports System, Light, and Dark mode selection', () {
      final controller = ThemeController();

      controller.setThemeMode(ThemeMode.dark);
      expect(controller.state.themeMode, equals(ThemeMode.dark));

      controller.setThemeMode(ThemeMode.light);
      expect(controller.state.themeMode, equals(ThemeMode.light));

      controller.setThemeMode(ThemeMode.system);
      expect(controller.state.themeMode, equals(ThemeMode.system));
    });
  });

  group('Quick Switch Portal Role Authorization Tests', () {
    test('Customer without elevated privileges is authorized only for Customer role', () {
      final basicCustomer = UserEntity(
        id: 'usr_normal_01',
        name: 'Zainab Ahmed',
        email: 'customer@groclyra.pk',
        phone: '+92 300 1234567',
        role: UserRole.customer,
        authorizedRoles: const [UserRole.customer],
        createdAt: DateTime(2026, 10, 21),
      );

      expect(basicCustomer.authorizedRoles.contains(UserRole.customer), isTrue);
      expect(basicCustomer.authorizedRoles.contains(UserRole.seller), isFalse);
      expect(basicCustomer.authorizedRoles.contains(UserRole.rider), isFalse);
      expect(basicCustomer.authorizedRoles.contains(UserRole.admin), isFalse);
    });

    test('Staff account with multi-role assignment can access authorized roles', () {
      final multiRoleUser = UserEntity(
        id: 'usr_staff_01',
        name: 'Khurram Shehzad',
        email: 'manager@groclyra.pk',
        phone: '+92 321 7654321',
        role: UserRole.customer,
        authorizedRoles: const [UserRole.customer, UserRole.seller, UserRole.admin],
        createdAt: DateTime(2026, 10, 21),
      );

      expect(multiRoleUser.authorizedRoles.contains(UserRole.customer), isTrue);
      expect(multiRoleUser.authorizedRoles.contains(UserRole.seller), isTrue);
      expect(multiRoleUser.authorizedRoles.contains(UserRole.admin), isTrue);
      expect(multiRoleUser.authorizedRoles.contains(UserRole.rider), isFalse);
    });
  });

  group('Notification Preferences Entity Tests', () {
    test('Default preferences enable critical order and delivery alerts', () {
      final defaultPrefs = NotificationPreferencesEntity.defaultPreferences('usr_789');

      expect(defaultPrefs.userId, equals('usr_789'));
      expect(defaultPrefs.orderUpdates, isTrue);
      expect(defaultPrefs.deliveryAlerts, isTrue);
      expect(defaultPrefs.priceDrops, isTrue);
      expect(defaultPrefs.backInStock, isTrue);
      expect(defaultPrefs.supportReplies, isTrue);
      expect(defaultPrefs.pushChannelEnabled, isTrue);
    });

    test('Serializes toMap and fromMap cleanly', () {
      final customPrefs = NotificationPreferencesEntity(
        userId: 'usr_custom_1',
        orderUpdates: true,
        deliveryAlerts: true,
        priceDrops: false, // user muted price drops
        backInStock: true,
        supportReplies: true,
        promotionsAndOffers: false, // user opted out of marketing
        securityAlerts: true,
        pushChannelEnabled: true,
        inAppChannelEnabled: true,
        smsChannelEnabled: false,
        updatedAt: DateTime(2026, 10, 21),
      );

      final map = customPrefs.toMap();
      final restored = NotificationPreferencesEntity.fromMap(map, 'usr_custom_1');

      expect(restored.priceDrops, isFalse);
      expect(restored.promotionsAndOffers, isFalse);
      expect(restored.orderUpdates, isTrue);
      expect(restored.securityAlerts, isTrue);
    });
  });
}
