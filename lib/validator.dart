class Validators {
  static bool validateHallTicket(String hallTicket) {
    String trimmed = hallTicket.trim();
    // Checks if it starts with 23, 24, 25, 26, or 27 followed by alphanumeric characters (total length typically 10)
    final regex = RegExp(r'^(23|24|25|26|27)[a-zA-Z0-9]{8}$');
    return regex.hasMatch(trimmed);
  }

  static bool validateName(String name) {
    String trimmed = name.trim();
    // Ensures name contains only letters and spaces, at least 3 characters long
    final regex = RegExp(r'^[a-zA-Z\s]{3,50}$');
    return regex.hasMatch(trimmed);
  }
}