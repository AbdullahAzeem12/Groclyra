class ValidatorUtils {
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^((\+92)|(0092)|(03))?[0-9]{9,10}$');
    if (!phoneRegex.hasMatch(value.trim().replaceAll(' ', ''))) {
      return 'Please enter a valid Pakistani phone number (e.g. 03001234567)';
    }
    return null;
  }

  /// Sanitizes and formats phone numbers to standard E.164 international format
  /// as required by Firebase Phone Authentication.
  static String formatToE164(String phone, {String defaultCountryCode = '+92'}) {
    String cleaned = phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    if (cleaned.startsWith('00')) {
      return '+${cleaned.substring(2)}';
    }
    if (cleaned.startsWith('03') && cleaned.length == 11) {
      return '$defaultCountryCode${cleaned.substring(1)}';
    }
    if (cleaned.startsWith('0')) {
      return '$defaultCountryCode${cleaned.substring(1)}';
    }
    if (!cleaned.startsWith('+')) {
      return '$defaultCountryCode$cleaned';
    }
    return cleaned;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  /// NEW (Phase 1.8): stricter password policy for new-account creation and
  /// password changes. The original [validatePassword] is kept untouched —
  /// existing sign-in / legacy flows continue to use it, so nothing breaks.
  static String? validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateCnic(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'CNIC is required';
    }
    final cnicRegex = RegExp(r'^\d{5}-\d{7}-\d{1}$');
    if (!cnicRegex.hasMatch(value.trim())) {
      return 'Please enter a valid CNIC format (e.g. 42101-1234567-1)';
    }
    return null;
  }

  static String? validateDrivingLicense(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Driving license is required';
    }
    if (value.trim().length < 5) {
      return 'Please enter a valid driving license number';
    }
    return null;
  }
}
