import 'package:auto_size_text/auto_size_text.dart';
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
    return SizedBox(
      width: 140,
      height: 130,
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
              const Spacer(),
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(icon, color: color, size: 22),
                ),
              AutoSizeText(
                value,
                maxLines: 1,
                minFontSize: 18,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.start,
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
