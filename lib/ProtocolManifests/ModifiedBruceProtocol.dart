class ModifiedBruceProtocol {
  static const String protocolName = "Modified Bruce Protocol";
  static const String protocolDescription =
      "A treadmill protocol with gentler initial stages, suitable for patients with lower exercise capacity.";
  static const String protocolVersion = "1.0.0";
  static const String type = "treadmil";

  // Modified Bruce Protocol Phases (based on your screenshot)
  static const List<Map<String, dynamic>> phases = [
    {
      "id": "stage_1",
      "name": "Stage 1",
      "duration": 180, // 3 min
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
      "speed_mph": 6.0,
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

  // Function to get the protocol details
  Map<String, dynamic> getProtocolDetails() {
    return {
      "id": "modified_bruce_protocol",
      "name": protocolName,
      "description": protocolDescription,
      "version": protocolVersion,
      "type": type,
      "phases": phases,
    };
  }
}
