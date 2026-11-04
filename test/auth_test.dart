import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/core/theme/gradient_palette.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:groclyra/features/auth/presentation/widgets/auth_header.dart';
import 'package:groclyra/features/auth/presentation/widgets/role_selector_card.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/features/auth/domain/entities/account_status.dart';
import 'package:groclyra/features/auth/domain/entities/auth_result.dart';
import 'package:groclyra/features/auth/domain/entities/password_strength.dart';
import 'package:groclyra/features/auth/domain/entities/user_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:groclyra/core/utils/validator_utils.dart';
import 'package:groclyra/features/auth/data/auth_error_mapper.dart';

void main() {
  group('PasswordStrength Tests', () {
    test('Empty password returns empty level', () {
      final strength = PasswordStrength.evaluate('');
      expect(strength.level, PasswordStrengthLevel.empty);
      expect(strength.isValid, false);
    });

    test('Weak short password', () {
      final strength = PasswordStrength.evaluate('abc');
      expect(strength.level, PasswordStrengthLevel.weak);
      expect(strength.isValid, false);
    });

    test('Strong password with letters, numbers, and special characters', () {
      final strength = PasswordStrength.evaluate('P@ssword123!');
      expect(strength.hasMinLength, true);
      expect(strength.hasUppercase, true);
      expect(strength.hasLowercase, true);
      expect(strength.hasNumber, true);
      expect(strength.hasSpecialChar, true);
      expect(strength.level, PasswordStrengthLevel.strong);
      expect(strength.isValid, true);
    });
  });

  group('UserEntity & AccountStatus Tests', () {
    test('UserEntity serialization and deserialization', () {
      final user = UserEntity(
        id: 'user_123',
        name: 'Jane Doe',
        email: 'jane@example.com',
        phone: '1234567890',
        role: UserRole.customer,
        accountStatus: AccountStatus.active,
        createdAt: DateTime(2026, 1, 1),
      );

      final json = user.toJson();
      final restored = UserEntity.fromJson(json);

      expect(restored.id, 'user_123');
      expect(restored.name, 'Jane Doe');
      expect(restored.role, UserRole.customer);
      expect(restored.accountStatus, AccountStatus.active);
      expect(restored.isActive, true);
      expect(restored.isPending, false);
    });

    test('Role identification getters', () {
      final seller = UserEntity(
        id: 'seller_1',
        name: 'Seller Store',
        email: 'seller@test.com',
        phone: '000000000',
        role: UserRole.seller,
        accountStatus: AccountStatus.pending,
        createdAt: DateTime.now(),
        storeName: 'My Store',
      );

      expect(seller.isSeller, true);
      expect(seller.isCustomer, false);
      expect(seller.isPending, true);
      expect(seller.storeName, 'My Store');
    });
  });

  group('AuthResult Tests', () {
    test('Role mismatch result creation', () {
      final result = AuthResult.roleMismatch(
        expectedRole: UserRole.customer,
        actualRole: UserRole.seller,
      );

      expect(result.isRoleMismatch, true);
      expect(result.isSuccess, false);
      expect(result.actualRole, UserRole.seller);
      expect(result.expectedRole, UserRole.customer);
      expect(result.message, contains('Seller'));
    });

    test('Pending approval result creation', () {
      final user = UserEntity(
        id: 'rider_1',
        name: 'Rider Partner',
        email: 'rider@test.com',
        phone: '111222333',
        role: UserRole.rider,
        accountStatus: AccountStatus.pending,
        createdAt: DateTime.now(),
      );

      final result = AuthResult.pendingApproval(user);
      expect(result.isPendingApproval, true);
      expect(result.isSuccess, false);
      expect(result.user?.id, 'rider_1');
    });
  });

  group('AuthErrorMapper Tests', () {
    test('General network error mapping', () {
      final msg = AuthErrorMapper.mapGeneralException(
        Exception('SocketException: Failed host lookup'),
      );
      expect(msg, contains('internet connection'));
    });
  });

  group('ThemeState Tests', () {
    test('ThemeMode.dark reports isDark true', () {
      const state = ThemeState(
        palette: AppThemePalette.synthDusk,
        mode: ThemeMode.dark,
      );
      expect(state.isDark, true);
    });

    test('ThemeMode.light reports isDark false', () {
      const state = ThemeState(
        palette: AppThemePalette.synthDusk,
        mode: ThemeMode.light,
      );
      expect(state.isDark, false);
    });
  });

  group('AuthTextField Focus Node Isolation Tests', () {
    testWidgets('Independent FocusNodes maintain focus isolation', (tester) async {
      final focusNodeA = FocusNode();
      final focusNodeB = FocusNode();
      final controllerA = TextEditingController();
      final controllerB = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AuthTextField(
                  key: const ValueKey('field_a'),
                  label: 'Field A',
                  controller: controllerA,
                  focusNode: focusNodeA,
                  palette: AppThemePalette.synthDusk,
                  isDark: false,
                ),
                AuthTextField(
                  key: const ValueKey('field_b'),
                  label: 'Field B',
                  controller: controllerB,
                  focusNode: focusNodeB,
                  palette: AppThemePalette.synthDusk,
                  isDark: false,
                ),
              ],
            ),
          ),
        ),
      );

      // Request focus on Field A
      focusNodeA.requestFocus();
      await tester.pumpAndSettle();

      expect(focusNodeA.hasFocus, true);
      expect(focusNodeB.hasFocus, false);

      // Request focus on Field B
      focusNodeB.requestFocus();
      await tester.pumpAndSettle();

      expect(focusNodeA.hasFocus, false);
      expect(focusNodeB.hasFocus, true);

      focusNodeA.dispose();
      focusNodeB.dispose();
      controllerA.dispose();
      controllerB.dispose();
    });

    testWidgets('AuthTextField applies correct contrast in Light and Dark themes', (tester) async {
      final controllerLight = TextEditingController(text: 'Light Mode Input');
      final controllerDark = TextEditingController(text: 'Dark Mode Input');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: AuthTextField(
              key: const ValueKey('light_field'),
              label: 'Light Field',
              controller: controllerLight,
              palette: AppThemePalette.synthDusk,
              isDark: false,
            ),
          ),
        ),
      );

      final textFieldLight = tester.widget<TextField>(find.byType(TextField));
      expect(textFieldLight.style?.color, const Color(0xFF0F172A));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: AuthTextField(
              key: const ValueKey('dark_field'),
              label: 'Dark Field',
              controller: controllerDark,
              palette: AppThemePalette.synthDusk,
              isDark: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldDark = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('dark_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(textFieldDark.style?.color, Colors.white);

      controllerLight.dispose();
      controllerDark.dispose();
    });

    testWidgets('Business Category and Phone Number inputs are strictly isolated during typing', (tester) async {
      final categoryController = TextEditingController();
      final phoneController = TextEditingController();
      final categoryFocusNode = FocusNode();
      final phoneFocusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AuthTextField(
                  key: const ValueKey('reg_seller_category'),
                  label: 'Business Category',
                  controller: categoryController,
                  focusNode: categoryFocusNode,
                  palette: AppThemePalette.synthDusk,
                  isDark: false,
                ),
                AuthTextField(
                  key: const ValueKey('reg_phone'),
                  label: 'Phone Number',
                  controller: phoneController,
                  focusNode: phoneFocusNode,
                  palette: AppThemePalette.synthDusk,
                  isDark: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter text into Business Category
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('reg_seller_category')),
          matching: find.byType(TextField),
        ),
        'Groceries & Crockery',
      );
      await tester.pumpAndSettle();

      expect(categoryController.text, 'Groceries & Crockery');
      expect(phoneController.text, '');
      expect(categoryFocusNode.hasFocus, true);
      expect(phoneFocusNode.hasFocus, false);

      // Enter text into Phone Number
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('reg_phone')),
          matching: find.byType(TextField),
        ),
        '03001234567',
      );
      await tester.pumpAndSettle();

      expect(categoryController.text, 'Groceries & Crockery');
      expect(phoneController.text, '03001234567');
      expect(phoneFocusNode.hasFocus, true);

      categoryController.dispose();
      phoneController.dispose();
      categoryFocusNode.dispose();
      phoneFocusNode.dispose();
    });
  });

  group('AuthHeader & RoleSelectorCard Systematic Layout Tests', () {
    testWidgets('AuthHeader renders Back Button, GL Logo, and Portal badge in one Row', (tester) async {
      bool backPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthHeader(
              title: 'Join Groclyra',
              subtitle: 'Test Subtitle',
              role: UserRole.customer,
              palette: AppThemePalette.synthDusk,
              isDark: true,
              onBackPressed: () => backPressed = true,
            ),
          ),
        ),
      );

      // Verify GL logo exists
      expect(find.text('GL'), findsOneWidget);

      // Verify role badge exists
      expect(find.text('Customer Portal'), findsOneWidget);

      // Verify back button exists and responds to tap
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      // SpringTouchScale fires the callback after its spring animation +
      // navigation delay (~160 ms) — let the frames run before asserting.
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 200));
      expect(backPressed, true);

      // Verify Back button, GL text, and Customer Portal are in the same horizontal row
      final backButtonRender = tester.getTopLeft(backButton);
      final glRender = tester.getTopLeft(find.text('GL'));
      final portalRender = tester.getTopLeft(find.text('Customer Portal'));

      expect((backButtonRender.dy - glRender.dy).abs(), lessThan(20));
      expect((glRender.dy - portalRender.dy).abs(), lessThan(20));
    });

    testWidgets('RoleSelectorCard renders all 4 role boxes with strictly equal heights and widths', (tester) async {
      UserRole selected = UserRole.customer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SizedBox(
                  width: 400,
                  child: RoleSelectorCard(
                    selectedRole: selected,
                    palette: AppThemePalette.synthDusk,
                    isDark: true,
                    disableAdmin: true,
                    onRoleSelected: (r) => setState(() => selected = r),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verify all 4 roles are rendered
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Seller'), findsOneWidget);
      expect(find.text('Rider'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);

      // Verify "Provisioned Only" chip on Admin is visible
      expect(find.text('Provisioned Only'), findsOneWidget);

      // Verify "Selected" badge on Customer is visible
      expect(find.text('Selected'), findsOneWidget);

      // Find the sizes of the 4 role cards (SpringTouchScale widgets)
      final springFinder = find.byType(SpringTouchScale);
      expect(springFinder, findsNWidgets(4));

      final customerSize = tester.getSize(springFinder.at(0));
      final sellerSize = tester.getSize(springFinder.at(1));
      final riderSize = tester.getSize(springFinder.at(2));
      final adminSize = tester.getSize(springFinder.at(3));

      // Assert equal heights across all 4 role boxes
      expect(customerSize.height, equals(sellerSize.height));
      expect(riderSize.height, equals(adminSize.height));
      expect(customerSize.height, equals(adminSize.height));

      // Assert equal widths across columns
      expect(customerSize.width, equals(sellerSize.width));
      expect(riderSize.width, equals(adminSize.width));
      expect(customerSize.width, equals(riderSize.width));
    });

    testWidgets('RoleSelectorCard invokes onLockedAdminTap when locked admin is tapped', (tester) async {
      int lockedTaps = 0;
      UserRole selected = UserRole.customer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: RoleSelectorCard(
                selectedRole: selected,
                palette: AppThemePalette.synthDusk,
                isDark: true,
                disableAdmin: true,
                onLockedAdminTap: () => lockedTaps++,
                onRoleSelected: (r) => selected = r,
              ),
            ),
          ),
        ),
      );

      // Tap Admin card 5 times.
      // SpringTouchScale dispatches the callback after the spring settle
      // (~160 ms per gesture); each tap must be pumped past that window so
      // every press actually registers.
      final adminCard = find.text('Admin');
      for (int i = 0; i < 5; i++) {
        await tester.tap(adminCard);
        await tester.pump(const Duration(milliseconds: 220));
      }

      expect(lockedTaps, equals(5));
      // Since it was disabled, onRoleSelected should NOT have changed selected role directly
      expect(selected, equals(UserRole.customer));
    });

    test('UserEntity preserves adminId and adminDepartment across toJson and fromJson', () {
      final admin = UserEntity(
        id: 'admin_uid_999',
        name: 'Root Administrator',
        email: 'admin@groclyra.com',
        phone: '03001234567',
        role: UserRole.admin,
        accountStatus: AccountStatus.active,
        createdAt: DateTime(2026, 3, 1),
        adminId: 'ADM-HQ-849201',
        adminDepartment: 'Executive Operations & Audit',
      );

      expect(admin.isAdmin, true);
      expect(admin.adminId, 'ADM-HQ-849201');
      expect(admin.adminDepartment, 'Executive Operations & Audit');

      final json = admin.toJson();
      expect(json['adminId'], 'ADM-HQ-849201');
      expect(json['adminDepartment'], 'Executive Operations & Audit');

      final restored = UserEntity.fromJson(json);
      expect(restored.adminId, 'ADM-HQ-849201');
      expect(restored.adminDepartment, 'Executive Operations & Audit');
      expect(restored.isAdmin, true);
    });
  });

  group('Google & Phone Authentication Diagnostic Tests', () {
    test('ValidatorUtils.formatToE164 formats local Pakistani numbers accurately', () {
      expect(ValidatorUtils.formatToE164('03001234567'), equals('+923001234567'));
      expect(ValidatorUtils.formatToE164('0302 1234567'), equals('+923021234567'));
      expect(ValidatorUtils.formatToE164('+92 300 1234567'), equals('+923001234567'));
      expect(ValidatorUtils.formatToE164('00923001234567'), equals('+923001234567'));
      expect(ValidatorUtils.formatToE164('3001234567'), equals('+923001234567'));
    });

    test('AuthErrorMapper maps Google Sign-In 12500 ApiException to actionable message', () {
      const rawError =
          'PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 12500: , null, null)';
      final mapped = AuthErrorMapper.mapGeneralException(rawError);

      expect(mapped, contains('Google Sign-In failed (Error 12500)'));
      expect(mapped, contains('SHA-1'));
    });

    test('AuthErrorMapper maps operation-not-allowed with SMS region notice accurately', () {
      final exc = FirebaseAuthException(
        code: 'operation-not-allowed',
        message:
            'This operation is not allowed. This may be because the given sign-in provider is disabled for this Firebase project. Enable it in the Firebase console, under the sign-in method tab of the Auth section. [ SMS unable to be sent until this region enabled by the app developer. ]',
      );
      final mapped = AuthErrorMapper.mapFirebaseAuthException(exc);

      expect(mapped, contains('SMS Region Policy'));
      expect(mapped, contains('Pakistan +92'));
    });
  });
}

