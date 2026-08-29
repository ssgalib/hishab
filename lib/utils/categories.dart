import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Metadata for the 8 categories the model is trained to output.
class CategoryInfo {
  final String name;
  final String label;
  final IconData icon;
  final Color color;
  final Color ink;

  const CategoryInfo(this.name, this.label, this.icon, this.color, this.ink);
}

const categories = <CategoryInfo>[
  CategoryInfo('food', 'Food', Icons.restaurant, CategoryPalette.food,
      CategoryPalette.foodInk),
  CategoryInfo('transport', 'Transport', Icons.directions_car,
      CategoryPalette.transport, CategoryPalette.transportInk),
  CategoryInfo('utilities', 'Utilities', Icons.bolt, CategoryPalette.utilities,
      CategoryPalette.utilitiesInk),
  CategoryInfo('rent', 'Rent', Icons.home, CategoryPalette.rent,
      CategoryPalette.rentInk),
  CategoryInfo('medicine', 'Medicine', Icons.medical_services,
      CategoryPalette.medicine, CategoryPalette.medicineInk),
  CategoryInfo('education', 'Education', Icons.school,
      CategoryPalette.education, CategoryPalette.educationInk),
  CategoryInfo('entertainment', 'Entertainment', Icons.movie,
      CategoryPalette.entertainment, CategoryPalette.entertainmentInk),
  CategoryInfo('mobile', 'Mobile', Icons.phone_android, CategoryPalette.mobile,
      CategoryPalette.mobileInk),
];

const fallbackCategory = CategoryInfo(
    'other', 'Other', Icons.attach_money, Colors.blueGrey, Color(0xFF37474F));

CategoryInfo categoryInfo(String name) =>
    categories.firstWhere((c) => c.name == name, orElse: () => fallbackCategory);
