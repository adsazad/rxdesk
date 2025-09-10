class BruceProtocol {
  static const String protocolName = "Bruce Protocol";
  static const String protocolDescription =
      "A standardized treadmill protocol with progressive increases in speed and incline every 3 minutes.";
  static const String protocolVersion = "1.0.0";
  static const String type = "treadmill";

  // Bruce Protocol Phases
  static const List<Map<String, dynamic>> phases = [
    {
      "id": "stage_0",
      "name": "Stage 0 (Rest)",
      "duration": 10,
      "speed": 0.0,
      "incline": 0,
      "description": "Resting phase, treadmill stopped for 10 seconds.",
    },
    {
      "id": "stage_1",
      "name": "Stage 1",
      "duration": 180,
      "speed": 2.7,
      "incline": 10,
      "description": "Treadmill at 2.7 km/h and 10% incline for 3 minutes.",
    },
    {
      "id": "stage_2",
      "name": "Stage 2",
      "duration": 180,
      "speed": 4.0,
      "incline": 12,
      "description": "Treadmill at 4.0 km/h and 12% incline for 3 minutes.",
    },
    {
      "id": "stage_3",
      "name": "Stage 3",
      "duration": 180,
      "speed": 5.4,
      "incline": 14,
      "description": "Treadmill at 5.4 km/h and 14% incline for 3 minutes.",
    },
    {
      "id": "stage_4",
      "name": "Stage 4",
      "duration": 180,
      "speed": 6.7,
      "incline": 16,
      "description": "Treadmill at 6.7 km/h and 16% incline for 3 minutes.",
    },
    {
      "id": "stage_5",
      "name": "Stage 5",
      "duration": 180,
      "speed": 8.0,
      "incline": 18,
      "description": "Treadmill at 8.0 km/h and 18% incline for 3 minutes.",
    },
    {
      "id": "recovery",
      "name": "Recovery",
      "duration": 180,
      "speed": 2.7,
      "incline": 0,
      "description": "Recovery phase at 2.7 km/h and 0% incline for 3 minutes.",
    },
  ];

  // TrackMaster commands for each phase (send both speed and incline)
  static const Map<String, List<List<int>>> commands = {
    "stage_0": [
      [0xA3, 0x30, 0x30, 0x30, 0x30], // Speed 0.0 km/h ("0000")
      [0xA4, 0x30, 0x30, 0x30, 0x30], // Incline 0% ("0000")
    ],
    "stage_1": [
      [0xA3, 0x30, 0x30, 0x32, 0x37], // Set Speed 2.7 km/h ("0027")
      [0xA4, 0x30, 0x30, 0x31, 0x30], // Set Incline 10% ("0010")
    ],
    "stage_2": [
      [0xA3, 0x30, 0x30, 0x34, 0x30], // 4.0 km/h ("0040")
      [0xA4, 0x30, 0x30, 0x31, 0x32], // 12% ("0012")
    ],
    "stage_3": [
      [0xA3, 0x30, 0x30, 0x35, 0x34], // 5.4 km/h ("0054")
      [0xA4, 0x30, 0x30, 0x31, 0x34], // 14% ("0014")
    ],
    "stage_4": [
      [0xA3, 0x30, 0x30, 0x36, 0x37], // 6.7 km/h ("0067")
      [0xA4, 0x30, 0x30, 0x31, 0x36], // 16% ("0016")
    ],
    "stage_5": [
      [0xA3, 0x30, 0x30, 0x38, 0x30], // 8.0 km/h ("0080")
      [0xA4, 0x30, 0x30, 0x31, 0x38], // 18% ("0018")
    ],
    "recovery": [
      [0xA3, 0x30, 0x30, 0x32, 0x37], // 2.7 km/h ("0027")
      [0xA4, 0x30, 0x30, 0x30, 0x30], // 0% ("0000")
    ],
  };

  // Function to get the protocol details
  Map<String, dynamic> getProtocolDetails() {
    return {
      "id": "bruce_protocol",
      "name": protocolName,
      "description": protocolDescription,
      "version": protocolVersion,
      "type": type,
      "phases": phases,
      "commands": commands,
    };
  }
}
