import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CurrentCo2Display extends StatefulWidget {
  final ValueListenable<double> notifier;
  final int windowSize;
  final double divisor; // raw / divisor => %
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const CurrentCo2Display({
    super.key,
    required this.notifier,
    this.windowSize = 20,
    this.divisor = 100.0,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
  });

  @override
  State<CurrentCo2Display> createState() => _CurrentCo2DisplayState();
}

class _CurrentCo2DisplayState extends State<CurrentCo2Display> {
  final List<double> _buffer = [];
  double _sum = 0;
  double _smoothed = 0;

  void _onValue() {
    final v = widget.notifier.value;
    _buffer.add(v);
    _sum += v;
    if (_buffer.length > widget.windowSize) {
      _sum -= _buffer.removeAt(0);
    }
    _smoothed = _sum / _buffer.length;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onValue);
  }

  @override
  void didUpdateWidget(covariant CurrentCo2Display oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifier != widget.notifier) {
      oldWidget.notifier.removeListener(_onValue);
      _buffer.clear();
      _sum = 0;
      _smoothed = 0;
      widget.notifier.addListener(_onValue);
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade700, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade100.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bubble_chart, color: Colors.red.shade700, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Current CO₂",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.red.shade700,
                ),
              ),
              Text(
                "${(_smoothed / widget.divisor).toStringAsFixed(3)} %",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              // Optional: tiny caption showing samples averaged
              // Text("n=${_buffer.length}", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
