class ModifiedBruceProtocol {
  static const String protocolName = "Modified Bruce Protocol";
  static const String protocolDescription =
      "A treadmill protocol with gentler initial stages, suitable for patients with lower exercise capacity.";
  static const String protocolVersion = "1.0.0";
  static const String type = "treadmill";

  // Modified Bruce Protocol Phases
  static const List<Map<String, dynamic>> phases = [
    {
      "id": "stage_1",
      "name": "Stage 1",
      "duration": 180,
      "speed": 2.7,
      "incline": 0,
      "description": "3 min at 1.7 mph (2.7 km/h), 0% grade.",
    },
    {
      "id": "stage_2",
      "name": "Stage 2",
      "duration": 180,
      "speed": 2.7,
      "incline": 5,
      "description": "3 min at 1.7 mph (2.7 km/h), 5% grade.",
    },
    {
      "id": "stage_3",
      "name": "Stage 3",
      "duration": 180,
      "speed": 2.7,
      "incline": 10,
      "description": "3 min at 1.7 mph (2.7 km/h), 10% grade.",
    },
    {
      "id": "stage_4",
      "name": "Stage 4",
      "duration": 180,
      "speed": 4.0,
      "incline": 12,
      "description": "3 min at 2.5 mph (4.0 km/h), 12% grade.",
    },
    {
      "id": "stage_5",
      "name": "Stage 5",
      "duration": 180,
      "speed": 5.5,
      "incline": 14,
      "description": "3 min at 3.4 mph (5.5 km/h), 14% grade.",
    },
    {
      "id": "stage_6",
      "name": "Stage 6",
      "duration": 180,
      "speed": 6.8,
      "incline": 16,
      "description": "3 min at 4.2 mph (6.8 km/h), 16% grade.",
    },
    {
      "id": "stage_7",
      "name": "Stage 7",
      "duration": 180,
      "speed": 8.0,
      "incline": 18,
      "description": "3 min at 5.0 mph (8.0 km/h), 18% grade.",
    },
    {
      "id": "stage_8",
      "name": "Stage 8",
      "duration": 180,
      "speed": 8.9,
      "incline": 20,
      "description": "3 min at 5.5 mph (8.9 km/h), 20% grade.",
    },
    {
      "id": "stage_9",
      "name": "Stage 9",
      "duration": 180,
      "speed": 9.7,
      "incline": 21.9,
      "description": "3 min at 6.0 mph (9.7 km/h), 21.9% grade.",
    },
    {
      "id": "recovery",
      "name": "Recovery",
      "duration": 180,
      "speed": 2.7,
      "incline": 0,
      "description":
          "Recovery phase at 1.7 mph (2.7 km/h), 0% grade for 3 min.",
    },
  ];

  // TrackMaster commands for each phase (send both speed and incline)
  static const Map<String, List<List<int>>> commands = {
    "stage_1": [
      [0xA3, 0x30, 0x30, 0x32, 0x37], // Speed 2.7 km/h ("0027")
      [0xA4, 0x30, 0x30, 0x30, 0x30], // Incline 0% ("0000")
    ],
    "stage_2": [
      [0xA3, 0x30, 0x30, 0x32, 0x37], // 2.7 km/h
      [0xA4, 0x30, 0x30, 0x30, 0x35], // 5% ("0005")
    ],
    "stage_3": [
      [0xA3, 0x30, 0x30, 0x32, 0x37], // 2.7 km/h
      [0xA4, 0x30, 0x30, 0x31, 0x30], // 10% ("0010")
    ],
    "stage_4": [
      [0xA3, 0x30, 0x30, 0x34, 0x30], // 4.0 km/h ("0040")
      [0xA4, 0x30, 0x30, 0x31, 0x32], // 12% ("0012")
    ],
    "stage_5": [
      [0xA3, 0x30, 0x30, 0x35, 0x35], // 5.5 km/h ("0055")
      [0xA4, 0x30, 0x30, 0x31, 0x34], // 14% ("0014")
    ],
    "stage_6": [
      [0xA3, 0x30, 0x30, 0x36, 0x38], // 6.8 km/h ("0068")
      [0xA4, 0x30, 0x30, 0x31, 0x36], // 16% ("0016")
    ],
    "stage_7": [
      [0xA3, 0x30, 0x30, 0x38, 0x30], // 8.0 km/h ("0080")
      [0xA4, 0x30, 0x30, 0x31, 0x38], // 18% ("0018")
    ],
    "stage_8": [
      [0xA3, 0x30, 0x30, 0x38, 0x39], // 8.9 km/h ("0089")
      [0xA4, 0x30, 0x30, 0x32, 0x30], // 20% ("0020")
    ],
    "stage_9": [
      [0xA3, 0x30, 0x30, 0x39, 0x37], // 9.7 km/h ("0097")
      [
        0xA4,
        0x32,
        0x31,
        0x39,
      ], // 21.9% ("219") - Note: 4 ASCII bytes expected, pad as needed
    ],
    "recovery": [
      [0xA3, 0x30, 0x30, 0x32, 0x37], // 2.7 km/h
      [0xA4, 0x30, 0x30, 0x30, 0x30], // 0%
    ],
  };

  // Function to get the protocol details
  Map<String, dynamic> getProtocolDetails() {
    return {
      "id": "modified_bruce_protocol",
      "name": protocolName,
      "description": protocolDescription,
      "version": protocolVersion,
      "type": type,
      "phases": phases,
      "commands": commands,
    };
  }
}
