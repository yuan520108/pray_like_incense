import 'package:flutter/material.dart';

const Color appBackground = Color(0xFF2D3656);
const Color appSurface = Color(0xFF414D70);
const Color appDarkSurface = Color(0xFF191A31);
const Color appCard = Color(0xFFFFFEFC);
const Color appCream = Color(0xFFFFF9EC);
const Color appGold = Color(0xFFFFDA82);
const Color appYellow = Color(0xFFFFD000);
const Color appGray = Color(0xFFD8D8D8);
const Color appIconBrown = Color(0xFF76502D);
const Color appCommentBlue = Color(0xFF3498DB);

BoxDecoration appCardDecoration({Color? color}) => BoxDecoration(
  color: color ?? appCard,
  borderRadius: BorderRadius.circular(22),
);
