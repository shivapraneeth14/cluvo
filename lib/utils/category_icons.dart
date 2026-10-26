import 'package:flutter/material.dart';

/// Shared, unified category vocabulary for the mobile app.
///
/// Organizers pick community and event categories from fixed preset lists in
/// the web portals, but the values are stored as free text. Both lists overlap
/// (e.g. "Music" / "Music & Arts", "Wellness" / "Health & Wellness"), so this
/// helper normalises them to a single icon per category and is tolerant of the
/// exact spelling used in the database.
IconData categoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('music') || c.contains('concert')) return Icons.music_note;
  if (c.contains('film') || c.contains('movie') || c.contains('cinema')) {
    return Icons.movie_outlined;
  }
  if (c.contains('comedy')) return Icons.theater_comedy;
  if (c.contains('workshop') || c.contains('class')) {
    return Icons.handyman_outlined;
  }
  if (c.contains('sport') || c.contains('fitness')) {
    return Icons.sports_basketball;
  }
  if (c.contains('food') || c.contains('dine') || c.contains('drink')) {
    return Icons.restaurant;
  }
  if (c.contains('tech') || c.contains('code') || c.contains('startup')) {
    return Icons.memory;
  }
  if (c.contains('art') || c.contains('culture') || c.contains('theatre')) {
    return Icons.palette;
  }
  if (c.contains('business') || c.contains('network') || c.contains('finance')) {
    return Icons.work_outline;
  }
  if (c.contains('education') || c.contains('learn') || c.contains('study')) {
    return Icons.school_outlined;
  }
  if (c.contains('wellness') || c.contains('health') || c.contains('yoga')) {
    return Icons.spa_outlined;
  }
  if (c.contains('social') || c.contains('community') || c.contains('meet')) {
    return Icons.groups_outlined;
  }
  if (c.contains('travel') ||
      c.contains('outdoor') ||
      c.contains('nature') ||
      c.contains('hik')) {
    return Icons.terrain;
  }
  if (c.contains('game') || c.contains('gaming')) return Icons.sports_esports;
  if (c.contains('photo') || c.contains('camera')) {
    return Icons.photo_camera_outlined;
  }
  return Icons.local_activity_outlined;
}

/// Icon shown on the "All" category chip / filter.
const IconData kAllCategoriesIcon = Icons.apps;
