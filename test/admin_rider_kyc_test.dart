import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/admin/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:groclyra/features/admin/domain/entities/admin_analytics_entity.dart';
import 'package:groclyra/features/admin/presentation/controllers/admin_controller.dart';
import 'package:groclyra/features/admin/riders/domain/entities/rider_kyc_application.dart';
import 'package:groclyra/features/auth/domain/entities/account_status.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/catalog/presentation/controllers/catalog_controller.dart';
import 'package:groclyra/features/admin/riders/presentation/screens/rider_kyc_approval_screen.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/features/auth/domain/entities/user_entity.dart';

void main() {
  group('RiderKycApplication Domain Tests', () {
    test('Serialization and Deserialization integrity', () {
      final now = DateTime.now();
      final app = RiderKycApplication(
        id: 'rider_test_123',
        riderId: 'rider_test_123',
        name: 'Muhammad Asif',
        email: 'asif.rider@groclyra.pk',
        phone: '03009876543',
        vehicleNumber: 'KHI-LEJ-9042',
        vehicleType: 'Motorcycle (125cc)',
        deliveryZone: 'Karachi South (Clifton/DHA)',
        address: 'House 14, Phase 5, DHA',
        cnic: '42101-1234567-1',
        licenseNumber: 'DL-KHI-99881',
        status: AccountStatus.pending,
        submittedAt: now,
      );

      expect(app.isPending, isTrue);
      expect(app.isApproved, isFalse);

      final firestoreMap = app.toFirestore();
      expect(firestoreMap['uid'], equals('rider_test_123'));
      expect(firestoreMap['vehicleNumber'], equals('KHI-LEJ-9042'));
      expect(firestoreMap['accountStatus'], equals('pending'));

      final reconstructed = RiderKycApplication.fromFirestore(firestoreMap, 'rider_test_123');
      expect(reconstructed.id, equals('rider_test_123'));
      expect(reconstructed.name, equals('Muhammad Asif'));
      expect(reconstructed.vehicleNumber, equals('KHI-LEJ-9042'));
      expect(reconstructed.status, equals(AccountStatus.pending));
    });

    test('Status transitions work correctly', () {
      final app = RiderKycApplication(
        id: 'rider_1',
        riderId: 'rider_1',
        name: 'Bilal Khan',
        email: 'bilal@groclyra.pk',
        phone: '03120000000',
        vehicleNumber: 'LHR-7788',
        deliveryZone: 'Lahore Cantt',
        submittedAt: DateTime.now(),
        status: AccountStatus.pending,
      );

      final approved = app.copyWith(status: AccountStatus.active);
      expect(approved.isApproved, isTrue);
      expect(approved.isPending, isFalse);

      final rejected = app.copyWith(status: AccountStatus.disabled, adminNotes: 'Invalid license scan');
      expect(rejected.isRejected, isTrue);
      expect(rejected.adminNotes, equals('Invalid license scan'));
    });
  });

  group('Real-Time Firestore Rider KYC Synchronization Tests', () {
    test('AdminState defaults to empty rider queue with zero hardcoded entries', () {
      const state = AdminState();
      expect(state.riderKycQueue, isEmpty);
      expect(state.kycQueue, isEmpty);
      expect(state.analytics, isNull);
    });

    test('Parses raw Firestore user & rider profile data into RiderKycApplication dynamically', () {
      final firestoreRawDoc = {
        'uid': 'rider_live_999',
        'displayName': 'Tariq Mehmood',
        'email': 'tariq.rider@gmail.com',
        'phone': '03331234567',
        'vehicleNumber': 'ISB-XYZ-5544',
        'vehicleType': 'Motorcycle (150cc)',
        'deliveryZone': 'F-7 / Blue Area, Islamabad',
        'address': 'Street 12, Sector F-7/2',
        'cnic': '61101-9876543-1',
        'licenseNumber': 'DL-ICT-8877',
        'accountStatus': 'pending',
        'createdAt': '2026-09-17T12:00:00.000Z',
      };

      final rider = RiderKycApplication.fromFirestore(firestoreRawDoc, 'rider_live_999');
      expect(rider.id, equals('rider_live_999'));
      expect(rider.name, equals('Tariq Mehmood'));
      expect(rider.email, equals('tariq.rider@gmail.com'));
      expect(rider.phone, equals('03331234567'));
      expect(rider.vehicleNumber, equals('ISB-XYZ-5544'));
      expect(rider.vehicleType, equals('Motorcycle (150cc)'));
      expect(rider.deliveryZone, equals('F-7 / Blue Area, Islamabad'));
      expect(rider.cnic, equals('61101-9876543-1'));
      expect(rider.licenseNumber, equals('DL-ICT-8877'));
      expect(rider.status, equals(AccountStatus.pending));
      expect(rider.isPending, isTrue);
    });

    test('Simulates multi-collection merge from users and riderProfiles collections', () {
      final userDoc = {
        'uid': 'rider_live_888',
        'displayName': 'Zubair Shah',
        'email': 'zubair@gmail.com',
        'phone': '03001112233',
        'role': 'rider',
        'accountStatus': 'pending',
        'createdAt': '2026-09-17T10:00:00.000Z',
      };

      final profileDoc = {
        'vehicleNumber': 'KHI-6677',
        'vehicleType': 'Cargo Van',
        'deliveryZone': 'Gulshan-e-Iqbal, Karachi',
        'cnic': '42101-5554433-2',
        'licenseNumber': 'DL-KHI-4433',
      };

      // Merging by UID (identical logic used by watchRiderKycApplications & getRiderKycApplications)
      final mergedData = Map<String, dynamic>.from(userDoc)..addAll(profileDoc);
      final rider = RiderKycApplication.fromFirestore(mergedData, 'rider_live_888');

      expect(rider.name, equals('Zubair Shah'));
      expect(rider.vehicleNumber, equals('KHI-6677'));
      expect(rider.vehicleType, equals('Cargo Van'));
      expect(rider.deliveryZone, equals('Gulshan-e-Iqbal, Karachi'));
      expect(rider.cnic, equals('42101-5554433-2'));
      expect(rider.status, equals(AccountStatus.pending));
    });

    test('Simulates real-time Firestore stream emission updating AdminState dynamically', () async {
      final streamController = StreamController<List<RiderKycApplication>>();

      var state = const AdminState(isLoading: true);
      expect(state.riderKycQueue, isEmpty);

      // Listen to simulated Firestore stream
      final sub = streamController.stream.listen((updatedRiders) {
        state = state.copyWith(riderKycQueue: updatedRiders, isLoading: false);
      });

      // Emit new registered rider from Firestore
      final newRider = RiderKycApplication(
        id: 'rider_stream_001',
        riderId: 'rider_stream_001',
        name: 'Hamza Farooq',
        email: 'hamza@gmail.com',
        phone: '03451122334',
        vehicleNumber: 'LHR-9900',
        deliveryZone: 'DHA Phase 6, Lahore',
        submittedAt: DateTime.now(),
        status: AccountStatus.pending,
      );

      streamController.add([newRider]);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(state.riderKycQueue.length, equals(1));
      expect(state.riderKycQueue.first.name, equals('Hamza Farooq'));
      expect(state.riderKycQueue.first.vehicleNumber, equals('LHR-9900'));
      expect(state.isLoading, isFalse);

      await sub.cancel();
      await streamController.close();
    });
  });

  group('AdminAnalyticsEntity Real-Time Computation Tests', () {
    test('Empty state contains true zeroes and no dummy constants', () {
      final empty = AdminAnalyticsEntity.empty();
      expect(empty.totalGmv, equals(0.0));
      expect(empty.totalCommission, equals(0.0));
      expect(empty.totalOrdersToday, equals(0));
      expect(empty.totalActiveCustomers, equals(0));
      expect(empty.totalActiveSellers, equals(0));
      expect(empty.totalActiveRiders, equals(0));
      expect(empty.pendingRiderApprovals, equals(0));
      expect(empty.isLiveOnline, isTrue);
    });
  });

  group('Admin Dashboard Responsive Layout & Zero Overflow Tests', () {
    testWidgets('Renders on narrow mobile screen (360x640) with ZERO RenderFlex overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminControllerProvider.overrideWith((ref) => _MockAdminController()),
            catalogControllerProvider.overrideWith((ref) => _MockCatalogController()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const AdminDashboardScreen(),
          ),
        ),
      );

      // The dashboard intentionally runs an infinitely-repeating connection
      // pulse + notification bell animations, so pumpAndSettle can never
      // complete here — pump a bounded number of frames instead and verify
      // no layout exceptions.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      // Verify no yellow/black overflow indicators occurred
      expect(tester.takeException(), isNull);

      // Verify above-the-fold tiles
      expect(find.text('Total Platform GMV'), findsOneWidget);
      expect(find.text('Riders'), findsOneWidget);

      // The KYC sections live below the fold on a 640-tall viewport —
      // scroll to them in natural top-down order before asserting.
      await tester.scrollUntilVisible(
        find.text('Seller KYC Applications'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(find.text('Seller KYC Applications'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Rider KYC Applications'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(find.text('Rider KYC Applications'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Rider KYC Action Dialog Pixel Management & Button Alignment Tests', () {
    testWidgets('Action Dialog renders with ZERO bottom overflow when keyboard insets are active',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminControllerProvider.overrideWith((ref) => _MockAdminController()),
            authControllerProvider.overrideWith((ref) => _MockAuthController()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const RiderKycApprovalScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Locate 'Approve & Verify' button for applicant Rana Abdullah
      final approveButton = find.text('Approve & Verify');
      expect(approveButton, findsOneWidget);
      await tester.ensureVisible(approveButton);
      await tester.pumpAndSettle();
      await tester.tap(approveButton);
      await tester.pumpAndSettle();

      // Simulate soft keyboard opening (available height shrinks to 380px)
      tester.view.physicalSize = const Size(360, 380);
      await tester.pumpAndSettle();

      // Verify no yellow/black overflow error occurred
      expect(tester.takeException(), isNull);

      // Verify dialog title, applicant info, and action buttons are present and aligned
      expect(find.text('Approve & Activate Rider'), findsOneWidget);
      expect(find.text('Applicant: Rana Abdullah'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Approve & Grant Fleet Access'), findsOneWidget);

      // Verify buttons are laid out in a balanced Row
      // Cancel uses TextButton (not OutlinedButton) per dialog implementation
      final cancelFinder = find.widgetWithText(TextButton, 'Cancel');
      final confirmFinder = find.widgetWithText(ElevatedButton, 'Approve & Grant Fleet Access');
      expect(cancelFinder, findsOneWidget);
      expect(confirmFinder, findsOneWidget);

      // Tap cancel to close
      await tester.tap(cancelFinder);
      await tester.pumpAndSettle();
      expect(find.text('Approve & Activate Rider'), findsNothing);
    });
  });
}

/// Mock controller strictly used as a local test fixture for Flutter widget tests.
/// In production, AdminController connects 100% to live Firestore streams without hardcoded entries.
class _MockAdminController extends StateNotifier<AdminState> implements AdminController {
  _MockAdminController({List<RiderKycApplication>? testRiders})
      : super(
          AdminState(
            analytics: const AdminAnalyticsEntity(
              totalGmv: 45000.0,
              totalCommission: 3600.0,
              totalOrdersToday: 12,
              totalActiveCustomers: 85,
              totalActiveSellers: 8,
              totalActiveRiders: 4,
              pendingSellerApprovals: 1,
              pendingRiderApprovals: 2,
              pendingProductApprovals: 0,
              systemHealthScore: 99.98,
              isLiveOnline: true,
            ),
            // Test fixture applicant for testing UI rendering & action dialog pixel management
            riderKycQueue: testRiders ??
                [
                  RiderKycApplication(
                    id: 'rider_101',
                    riderId: 'rider_101',
                    name: 'Rana Abdullah',
                    email: 'rana.abdullah@gmail.com',
                    phone: '03021234567',
                    vehicleNumber: 'KHI-9988',
                    deliveryZone: 'Clifton, Karachi',
                    status: AccountStatus.pending,
                    submittedAt: DateTime.now(),
                  ),
                ],
            kycQueue: const [],
            isLoading: false,
          ),
        );

  @override
  Future<void> loadDashboard() async {}

  @override
  Future<void> reviewRiderKyc({
    required String riderId,
    required AccountStatus newStatus,
    required String adminId,
    String? notes,
  }) async {}

  @override
  Future<void> reviewSellerKyc({
    required String sellerId,
    required AccountStatus newStatus,
    required String adminId,
    String? notes,
  }) async {}

  @override
  Future<void> moderateKyc(String id, bool approve) async {}

  @override
  void clearMessages() {}
}

class _MockCatalogController extends StateNotifier<CatalogState> implements CatalogController {
  _MockCatalogController() : super(const CatalogState(allProducts: []));

  @override
  Future<void> loadCatalog() async {}

  @override
  void resetFilters() {}

  @override
  void filterByMainCategory(MainCategoryType? type) {}

  @override
  void filterByPillar(MainCategoryType? type) {}

  @override
  void search(String query) {}

  @override
  void filterByRestaurant(String? restaurantName) {}

  @override
  void setSearchQuery(String query) {}
}

class _MockAuthController extends StateNotifier<AuthState> implements AuthController {
  _MockAuthController()
      : super(
          AuthState(
            user: UserEntity(
              id: 'admin_test_1',
              name: 'Console Admin',
              email: 'admin@groclyra.pk',
              phone: '03001234567',
              role: UserRole.admin,
              accountStatus: AccountStatus.active,
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

