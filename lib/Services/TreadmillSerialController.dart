import 'dart:typed_data';
import 'package:libserialport/libserialport.dart';

class TreadmillSerialController {
  SerialPort? _port;

  bool get isOpen => _port?.isOpen ?? false;

  /// Open the treadmill port with TrackMaster settings
  bool open(String portName) {
    _port = SerialPort(portName);
    if (!_port!.openReadWrite()) {
      print("❌ Failed to open treadmill port: $portName");
      return false;
    }
    final config = _port!.config;
    config.baudRate = 4800;
    config.bits = 8;
    config.parity = SerialPortParity.none;
    config.stopBits = 1;
    _port!.config = config;
    print("✅ Treadmill port opened: $portName");
    return true;
  }

  void close() {
    _port?.close();
    print("ℹ️ Treadmill port closed.");
  }

  /// Send a command (as bytes)
  void sendCommand(List<int> bytes) {
    if (_port == null || !_port!.isOpen) {
      print("❌ Port not open.");
      return;
    }
    _port!.write(Uint8List.fromList(bytes));
    print("[TREADMILL CMD] Sent: $bytes");
  }
}
