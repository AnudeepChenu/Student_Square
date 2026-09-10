class Validators {
  static bool validateHallTicket(String input) {
    String trimmed = input.trim();
    // Validates formats starting with 23, 24, 25, 26, or 27 followed by alphanumeric chars (e.g., 2403a52377)
    final regex = RegExp(r'^(23|24|25|26|27)[a-zA-Z0-9]{7,10}$');
    return regex.hasMatch(trimmed);
  }

  static bool validateName(String name) {
    String trimmed = name.trim();
    final regex = RegExp(r'^[a-zA-Z\s]{3,50}$');
    return regex.hasMatch(trimmed);
  }
}