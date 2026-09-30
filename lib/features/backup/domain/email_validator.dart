final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _codePattern = RegExp(r'^\d{6}$');

bool isValidEmail(String email) => _emailPattern.hasMatch(email);

/// Exactly six digits.
bool isValidOtpCode(String code) => _codePattern.hasMatch(code);
