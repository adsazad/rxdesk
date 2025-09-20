import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:holtersync/ProviderModals/GlobalSettingsModal.dart';

class CurrentO2Display extends StatefulWidget {
  final ValueListenable<double> notifier;
  final int windowSize;
  final double adcToVoltFactor;
  final double Function(double voltage)? calibrate;
  final bool? applyConversionOverride;

  const CurrentO2Display({
    super.key,
    required this.notifier,
    this.windowSize = 20,
    this.adcToVoltFactor = 0.000917,
    this.calibrate,
    this.applyConversionOverride,
  });

  @override
  State<CurrentO2Display> createState() => _CurrentO2DisplayState();
}

class _CurrentO2DisplayState extends State<CurrentO2Display> {
  final List<double> _buffer = [];
  double _sum = 0;
  double _smoothedRaw = 0;

  void _onValue() {
    final v = widget.notifier.value;
    _buffer.add(v);
    _sum += v;
    if (_buffer.length > widget.windowSize) {
      _sum -= _buffer.removeAt(0);
    }
    _smoothedRaw = _sum / _buffer.length;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onValue);
  }

  @override
  void didUpdateWidget(covariant CurrentO2Display oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifier != widget.notifier) {
      oldWidget.notifier.removeListener(_onValue);
      _buffer.clear();
      _sum = 0;
      _smoothedRaw = 0;
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
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );
    final applyConversion =
        widget.applyConversionOverride ?? globalSettings.applyConversion;

    final voltage = _smoothedRaw * widget.adcToVoltFactor;
    double displayValue;
    String unit;
    if (applyConversion && widget.calibrate != null) {
      displayValue = widget.calibrate!(voltage);
      unit = "%";
    } else {
      displayValue = voltage;
      unit = "V";
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade700, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bubble_chart, color: Colors.blue.shade700, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Current O₂",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.blue.shade700,
                ),
              ),
              Text(
                "${displayValue.toStringAsFixed(3)} $unit",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              // Optional sample count:
              // Text("n=${_buffer.length}", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
