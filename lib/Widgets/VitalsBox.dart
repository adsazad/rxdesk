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
      width: 140, // 🔒 Fixed width
      height: 110, // 🔒 Fixed height
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (icon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(icon, color: color, size: 22),
                    ),
                  Expanded(
                    child: AutoSizeText(
                      value,
                      maxLines: 1,
                      minFontSize: 12,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 15,
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
      ),
    );
  }
}
