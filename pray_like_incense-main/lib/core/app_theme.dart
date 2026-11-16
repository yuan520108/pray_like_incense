import 'package:flutter/material.dart';

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