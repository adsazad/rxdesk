class IncrementalStepProtocol {
  static const String protocolName = "Incremental Step Protocol";
  static const String protocolDescription =
      "This protocol is designed to assess the incremental step exercise capacity of an individual. It involves a series of steps with increasing intensity, allowing for the evaluation of cardiovascular and muscular endurance.";

  static const String protocolVersion = "1.0.0";

  // Increase workload in steps every 1–3 minutes.
  // Example:
  // Time (min)	Workload (W)
  // 0–3	0 (unloaded)
  // 3–6	50
  // 6–9	75
  // 9–12	100

  // phase configuration array
  static const List<Map<String, dynamic>> phases = [
    {
      "name": "Resting Phase",
      "duration": 180, // seconds
      "description": "2–3 minutes sitting quietly on the ergometer.",
    },
    {
      "name": "Unloaded Pedalling Phase",
      "duration": 180, // seconds
      "description": "2–3 minutes at 0 watts (warm-up).",
    },
    {
      "name": "Incremental Step Phase",
      "duration": 720, // seconds
      "description":
          "Increase workload in steps every 3 minutes: 50W, 75W, 100W until exhaustion.",
    },
    {
      "name": "Recovery Phase",
      "duration": 360, // seconds
      "description": "4–6 minutes of unloaded pedalling and rest.",
    },
  ];

  // Function to get the protocol details
  Map<String, dynamic> getProtocolDetails() {
    return {
      "id": "incremental_step_protocol",
      "name": protocolName,
      "description": protocolDescription,
      "version": protocolVersion,
      "phases": phases,
    };
  }
}
