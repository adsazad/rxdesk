import 'dart:typed_data';

import 'package:libserialport/libserialport.dart';
import 'package:bluevo2/ProviderModals/GlobalSettingsModal.dart';

import 'package:flutter/material.dart';

class LodeErgometerWidget extends StatefulWidget {
  final GlobalSettingsModal globalSettings;
  final int deviceNumber;
  final Function(String) onLog;

  const LodeErgometerWidget({
    Key? key,
    required this.globalSettings,
    this.deviceNumber = 1,
    required this.onLog,
  }) : super(key: key);

  @override
  _LodeErgometerWidgetState createState() => _LodeErgometerWidgetState();
}

class _LodeErgometerWidgetState extends State<LodeErgometerWidget> {
  late LodeErgometerController _controller;
  bool _connected = false;
  String _response = '';
  String _logMessage = '';
  final TextEditingController _commandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = LodeErgometerController(
      globalSettings: widget.globalSettings,
      deviceNumber: widget.deviceNumber,
      onLog: (msg) {
        setState(() {
          _logMessage = msg;
        });
        widget.onLog(msg);
      },
    );
  }

  @override
  void dispose() {
    _controller.disconnect();
    _commandController.dispose();
    super.dispose();
  }

  void _connect() {
    setState(() {
      _connected = _controller.connect();
    });
  }

  void _disconnect() {
    _controller.disconnect();
    setState(() {
      _connected = false;
    });
  }

  Future<void> _sendCommand() async {
    final cmd = _commandController.text.trim();
    if (cmd.isEmpty) return;
    try {
      final resp = await _controller.sendCommand(cmd);
      setState(() {
        _response = resp;
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 350), // <-- Add this line if needed
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lode Ergometer Controller',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _connected ? null : _connect,
                    child: const Text('Connect'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _connected ? _disconnect : null,
                    child: const Text('Disconnect'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _connected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: _connected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commandController,
                      decoration: const InputDecoration(
                        labelText: 'Command (e.g. SP100)',
                        border: OutlineInputBorder(),
                      ),
                      enabled: _connected,
                    ),
                  ),
                  const SizedBox(width: 2),
                  ElevatedButton(
                    onPressed: _connected ? _sendCommand : null,
                    child: const Text('Send Command'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Response:', style: Theme.of(context).textTheme.bodySmall),
              Text(_response, style: const TextStyle(fontFamily: 'monospace')),
              const SizedBox(height: 16),
              Text('Log:', style: Theme.of(context).textTheme.bodySmall),
              Text(
                _logMessage,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LodeErgometerController {
  SerialPort? _port;
  final GlobalSettingsModal globalSettings;
  final int deviceNumber;
  final Function onLog;

  LodeErgometerController({
    required this.globalSettings,
    this.deviceNumber = 1, // Default device number, can be set from settings
    required this.onLog,
  });

  /// Connect to the ergometer using the COM port from global settings
  bool connect() {
    final comPort = globalSettings.machineCom;
    if (comPort == null || comPort == "none") {
      print("❌ No COM port specified in global settings.");
      onLog("No COM port specified in global settings.");
      return false;
    }
    try {
      _port = SerialPort(comPort);
      final config = _port!.config;
      config.baudRate = 38400;
      config.bits = 8;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;
      _port!.config = config;
      if (!_port!.openReadWrite()) {
        print("❌ Failed to open port: ${SerialPort.lastError}");
        onLog("Failed to open port: ${SerialPort.lastError}");
        return false;
      }
      print("✅ Connected to $comPort");
      onLog("Connected to $comPort");
      return true;
    } catch (e) {
      print("❌ Exception opening port: $e");
      onLog("Exception opening port: $e");
      return false;
    }
  }

  /// Disconnect from the ergometer
  void disconnect() {
    _port?.close();
    print("ℹ️ Disconnected from ergometer.");
    onLog("Disconnected from ergometer.");
  }

  /// Send a command to the ergometer (e.g., "SP100" for 100W)
  Future<String> sendCommand(String command) async {
    if (_port == null || !_port!.isOpen) {
      print("❌ Port not open.");
      throw Exception("Port not open.");
    }
    final cmd = "$deviceNumber,$command\r";
    print("➡️ Sending: $cmd");
    onLog("Sending command: $cmd");
    _port!.write(Uint8List.fromList(cmd.codeUnits));
    await Future.delayed(Duration(milliseconds: 50));
    final response = _port!.read(64, timeout: 100);
    final respStr = String.fromCharCodes(response);
    print("⬅️ Response: $respStr");
    onLog("Response: $respStr");
    return respStr;
  }

  /// Run a protocol: List of commands with delays (e.g., ramp, interval)
  Future<void> runProtocol(List<Map<String, dynamic>> protocolSteps) async {
    for (final step in protocolSteps) {
      final command = step['command'] as String;
      final duration = step['duration'] as int? ?? 0;
      await sendCommand(command);
      print("⏳ Waiting for $duration seconds...");
      onLog("Waiting for $duration seconds after command: $command");
      await Future.delayed(Duration(seconds: duration));
    }
    print("✅ Protocol completed.");
    onLog("Protocol completed.");
  }
}
