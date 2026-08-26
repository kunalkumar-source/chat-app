import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary & Secondary (WhatsApp-inspired Teal & Green Palette)
  static const Color primary = Color(0xFF008069);       // WhatsApp Teal Green
  static const Color primaryDark = Color(0xFF075E54);   // Dark Teal Green
  static const Color secondary = Color(0xFF128C7E);     // WhatsApp Secondary Teal
  static const Color accent = Color(0xFF25D366);        // WhatsApp Bright Green

  // AppBar Colors
  static const Color appBarColor = Color(0xFF008069);
  static const Color appBarTitleColor = Colors.white;
  static const Color appBarIconColor = Colors.white;

  // Background Colors
  static const Color background = Color(0xFFF0F2F5);       // App background
  static const Color chatBackground = Color(0xFFE5DDD5);   // WhatsApp Chat wallpaper tone
  static const Color cardColor = Colors.white;

  // Message Bubbles
  static const Color myMessageBubble = Color(0xFFE7FFDB);   // Light green sent bubble
  static const Color otherMessageBubble = Colors.white;    // White received bubble
  static const Color myMessageText = Color(0xFF111B21);
  static const Color otherMessageText = Color(0xFF111B21);

  // Status & Ticks
  static const Color onlineGreen = Color(0xFF25D366);
  static const Color offlineGrey = Color(0xFF8696A0);
  static const Color readTickBlue = Color(0xFF53BDEB);
  static const Color unreadBadgeGreen = Color(0xFF25D366);

  // Text Colors
  static const Color textPrimary = Color(0xFF111B21);
  static const Color textSecondary = Color(0xFF667781);
  static const Color textSubtle = Color(0xFF8696A0);

  // Borders & Inputs
  static const Color border = Color(0xFFE9EDEF);
  static const Color inputBackground = Color(0xFFF0F2F5);
  static const Color iconColor = Color(0xFF54656F);
}
