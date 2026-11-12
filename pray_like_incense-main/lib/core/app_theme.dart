import 'package:flutter/material.dart';

dynamic findValue(Map<String, dynamic> map, String key) {
  if (map.containsKey(key)) return map[key];
  for (final nestedKey in ['data', 'item']) {
    final nested = map[nestedKey];
    if (nested is Map) {
      final result = findValue(Map<String, dynamic>.from(nested), key);
      if (result != null) return result;
    }
  }
  return null;
}

const Color navy = Color(0xFF142049);
const Color cream = Color(0xFFFFF9EC);
const Color gold = Color(0xFFFFDF9E);
const Color gray = Color(0xFF848484);
const Color appBackground = Color(0xFF2D395D);
const Color appSurface = Color(0xFF414D70);
const Color appDarkSurface = Color(0xFF191A31);
const Color appSelected = Color(0xFFFFDA82);
const Color appIconBrown = Color(0xFF76502D);

BoxDecoration prayerGradient() => const BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy, gray, gold],
  ),
);

ButtonStyle creamButton() => ElevatedButton.styleFrom(
  backgroundColor: cream,
  foregroundColor: navy,
  elevation: 0,
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
);

InputDecoration inputDecoration(String label, {String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: cream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
    );

String cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
