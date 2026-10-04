/// Splits USDA descriptions into a title and comma-separated qualifiers.
/// Product and custom-meal names continue to use their full text.
library;

/// Index in [name] of the comma that ends the title, or -1 when the name
/// is not split at all: no comma, or nothing before it.
int _titleEnd(String name) {
  final comma = name.indexOf(',');
  if (comma < 0 || name.substring(0, comma).trim().isEmpty) return -1;
  return comma;
}

/// [name] up to its first comma, trimmed — "Egg" for "Egg, whole, raw".
///
/// A name with no comma is its own title, and a name with nothing before
/// the comma is too, rather than an empty string.
String deriveTitle(String name) {
  final end = _titleEnd(name);
  return end < 0 ? name : name.substring(0, end).trim();
}

/// What follows the title in [name] — "whole, raw" for "Egg, whole, raw"
/// — or null when the name is not split, or nothing follows the comma.
String? deriveQualifiers(String name) {
  final end = _titleEnd(name);
  if (end < 0) return null;
  final rest = name.substring(end + 1).trim();
  return rest.isEmpty ? null : rest;
}
