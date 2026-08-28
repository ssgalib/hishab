import 'package:flutter/material.dart';

/// Metadata for the 8 categories the model is trained to output.
class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryInfo(this.name, this.icon, this.color);
}

const categories = <CategoryInfo>[
  CategoryInfo('food', Icons.restaurant, Color(0xFFEF6C00)),
  CategoryInfo('transport', Icons.directions_car, Color(0xFF1565C0)),
  CategoryInfo('utilities', Icons.bolt, Color(0xFF8E24AA)),
  CategoryInfo('rent', Icons.home, Color(0xFF00838F)),
  CategoryInfo('medicine', Icons.medical_services, Color(0xFFC62828)),
  CategoryInfo('education', Icons.school, Color(0xFF2E7D32)),
  CategoryInfo('entertainment', Icons.movie, Color(0xFFF9A825)),
  CategoryInfo('mobile', Icons.phone_android, Color(0xFF5D4037)),
];

const fallbackCategory = CategoryInfo('other', Icons.attach_money, Colors.blueGrey);

CategoryInfo categoryInfo(String name) =>
    categories.firstWhere((c) => c.name == name, orElse: () => fallbackCategory);
