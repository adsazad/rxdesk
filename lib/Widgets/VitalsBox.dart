import 'package:flutter/material.dart';

class VitalsBox extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData? icon;

  const VitalsBox({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      // color: color.withOpacity(0.1), // Soft tint background
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.9),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(icon, color: color, size: 24),
                  ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: color.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
