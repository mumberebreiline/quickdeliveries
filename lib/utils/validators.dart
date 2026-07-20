/// Simple, dependency-free form validators. Each returns null when valid,
/// or an error string to show under the field.
class Validators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty)
      return 'Phone number is required';
    final cleaned = value.trim().replaceAll(' ', '');
    // Accepts 07xxxxxxxx or +2567xxxxxxxx / 2567xxxxxxxx style Ugandan numbers.
    final regex = RegExp(r'^(?:\+?256|0)7\d{8}$');
    if (!regex.hasMatch(cleaned)) {
      return 'Enter a valid phone number (e.g. 07XXXXXXXX)';
    }
    return null;
  }

  static String? notEmpty(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }
}
