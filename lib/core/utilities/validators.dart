/// Password strength criteria assessment for live feedback during registration & reset.
class PasswordStrength {
  const PasswordStrength({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialChar,
  });

  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialChar;

  int get score => [
        hasMinLength,
        hasUppercase,
        hasLowercase,
        hasNumber,
        hasSpecialChar,
      ].where((passed) => passed).length;

  bool get isStrong =>
      hasMinLength &&
      hasUppercase &&
      hasLowercase &&
      hasNumber &&
      hasSpecialChar;

  String get label => switch (score) {
        0 || 1 || 2 => 'Weak',
        3 || 4 => 'Fair',
        _ => 'Strong',
      };
}

/// Reusable form field validators across authentication, devices, fault reports, and settings.
abstract final class Validators {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _uppercaseRegex = RegExp(r'[A-Z]');
  static final RegExp _lowercaseRegex = RegExp(r'[a-z]');
  static final RegExp _digitRegex = RegExp(r'[0-9]');
  static final RegExp _specialCharRegex = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]');
  static final RegExp _sixDigitOtpRegex = RegExp(r'^\d{6}$');

  static String? requiredField(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = requiredField(value, fieldName: 'Email address');
    if (requiredError != null) return requiredError;
    if (!_emailRegex.hasMatch(value!.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Basic login password check (does not leak strength rules to login attempts).
  static String? password(String? value, {int minLength = 8}) {
    final requiredError = requiredField(value, fieldName: 'Password');
    if (requiredError != null) return requiredError;
    if (value!.length < minLength) {
      return 'Password must be at least $minLength characters.';
    }
    return null;
  }

  /// Evaluates password strength rules for registration and password reset.
  static PasswordStrength evaluatePasswordStrength(String password) {
    return PasswordStrength(
      hasMinLength: password.length >= 8,
      hasUppercase: _uppercaseRegex.hasMatch(password),
      hasLowercase: _lowercaseRegex.hasMatch(password),
      hasNumber: _digitRegex.hasMatch(password),
      hasSpecialChar: _specialCharRegex.hasMatch(password),
    );
  }

  /// Enforces full enterprise password strength during registration and password reset.
  static String? strongPassword(String? value) {
    final requiredError = requiredField(value, fieldName: 'Password');
    if (requiredError != null) return requiredError;
    final strength = evaluatePasswordStrength(value!);
    if (!strength.hasMinLength) {
      return 'Password must be at least 8 characters.';
    }
    if (!strength.hasUppercase) {
      return 'Include at least one uppercase letter.';
    }
    if (!strength.hasLowercase) {
      return 'Include at least one lowercase letter.';
    }
    if (!strength.hasNumber) {
      return 'Include at least one number.';
    }
    if (!strength.hasSpecialChar) {
      return 'Include at least one special character (e.g., !@#\$%).';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    final requiredError = requiredField(value, fieldName: 'Confirm password');
    if (requiredError != null) return requiredError;
    if (value != original) {
      return 'Passwords do not match.';
    }
    return null;
  }

  static String? otpCode(String? value) {
    final requiredError = requiredField(value, fieldName: 'Verification code');
    if (requiredError != null) return requiredError;
    if (!_sixDigitOtpRegex.hasMatch(value!.trim())) {
      return 'Enter the complete 6-digit verification code.';
    }
    return null;
  }

  static String? minLength(
    String? value,
    int min, {
    String fieldName = 'This field',
  }) {
    final requiredError = requiredField(value, fieldName: fieldName);
    if (requiredError != null) return requiredError;
    if (value!.trim().length < min) {
      return '$fieldName must be at least $min characters.';
    }
    return null;
  }

  static final RegExp _errorCodeRegex = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/\- ]{0,63}$');

  static String? optionalErrorCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.length > 64) {
      return 'Error code must be 64 characters or fewer.';
    }
    if (!_errorCodeRegex.hasMatch(trimmed)) {
      return 'Use only letters, numbers, spaces, or - _ . : / in error codes.';
    }
    return null;
  }

  static String? optionalUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return 'Enter a valid http:// or https:// URL.';
    }
    return null;
  }
}
