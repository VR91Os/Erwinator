import 'package:flutter/material.dart';

import '../utils/light_surface_colors.dart';

Widget projectCard({
  required String name,
  required String address,
  required String update,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: lightSurfaceTextColor,
          ),
        ),
        Text(address, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 10),
        Text(update, style: const TextStyle(color: lightSurfaceTextColor)),
      ],
    ),
  );
}
