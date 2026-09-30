import 'package:flutter/material.dart';

const _icons = <String, IconData>{
  'food': Icons.restaurant,
  'groceries': Icons.shopping_cart,
  'coffee': Icons.local_cafe,
  'transport': Icons.directions_bus,
  'car': Icons.directions_car,
  'fuel': Icons.local_gas_station,
  'home': Icons.home,
  'utilities': Icons.bolt,
  'phone': Icons.smartphone,
  'internet': Icons.wifi,
  'health': Icons.favorite,
  'pharmacy': Icons.local_pharmacy,
  'fitness': Icons.fitness_center,
  'entertainment': Icons.movie,
  'games': Icons.sports_esports,
  'music': Icons.music_note,
  'shopping': Icons.shopping_bag,
  'clothes': Icons.checkroom,
  'education': Icons.school,
  'books': Icons.menu_book,
  'travel': Icons.flight,
  'pets': Icons.pets,
  'gifts': Icons.card_giftcard,
  'kids': Icons.child_care,
  'beauty': Icons.spa,
  'subscriptions': Icons.subscriptions,
  'salary': Icons.work,
  'freelance': Icons.laptop,
  'investments': Icons.trending_up,
  'other': Icons.category,
};

/// Unknown keys fall back to [Icons.category].
IconData categoryIcon(String key) => _icons[key] ?? Icons.category;
