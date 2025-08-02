class BruceProtocol {
  static const String protocolName = "Bruce Protocol";
  static const String protocolDescription =
      "A standardized treadmill protocol with progressive increases in speed and incline every 3 minutes.";
  static const String protocolVersion = "1.0.0";
  static const String type = "treadmil";

  // Bruce Protocol Phases
  // Each phase increases speed and incline every 3 minutes.
  static const List<Map<String, dynamic>> phases = [
    {
      "id": "stage_1",
      "name": "Stage 1",
      "duration": 180, // seconds
      "speed": 2.7, // km/h
      "incline": 10, // percent
      "description": "Treadmill at 2.7 km/h and 10% incline for 3 minutes.",
    },
    {
      "id": "stage_2",
      "name": "Stage 2",
      "duration": 180, // seconds
      "speed": 4.0,
      "incline": 12,
      "description": "Treadmill at 4.0 km/h and 12% incline for 3 minutes.",
    },
    {
      "id": "stage_3",
      "name": "Stage 3",
      "duration": 180, // seconds
      "speed": 5.4,
      "incline": 14,
      "description": "Treadmill at 5.4 km/h and 14% incline for 3 minutes.",
    },
    {
      "id": "stage_4",
      "name": "Stage 4",
      "duration": 180, // seconds
      "speed": 6.7,
      "incline": 16,
      "description": "Treadmill at 6.7 km/h and 16% incline for 3 minutes.",
    },
    {
      "id": "stage_5",
      "name": "Stage 5",
      "duration": 180, // seconds
      "speed": 8.0,
      "incline": 18,
      "description": "Treadmill at 8.0 km/h and 18% incline for 3 minutes.",
    },
    {
      "id": "recovery",
      "name": "Recovery",
      "duration": 180, // seconds
      "speed": 2.7,
      "incline": 0,
      "description": "Recovery phase at 2.7 km/h and 0% incline for 3 minutes.",
    },
  ];

  // Function to get the protocol details
  Map<String, dynamic> getProtocolDetails() {
    return {
      "id": "bruce_protocol",
      "name": protocolName,
      "description": protocolDescription,
      "version": protocolVersion,
      "type": type,
      "phases": phases,
    };
  }
}
