class RampProtocol {
  static const String protocolName = "Ramp Protocol";
  static const String protocolDescription =
      "A protocol for ramping up the pressure during a test.";
  static const String protocolVersion = "1.0.0";

  // Ramp Protocol (Most Common)
  // Increases workload continuously or every 10–20 seconds in small increments.
  // Phase	Description
  // Resting	2–3 minutes sitting quietly on ergometer
  // Unloaded Pedalling	2–3 minutes at 0 watts (warm-up)
  // Ramp Phase	Increase by 10–30 watts/min until exhaustion
  // Recovery	4–6 minutes unloaded pedaling and rest

  // phase configuration array
  static const List<Map<String, dynamic>> phases = [
    {
      "name": "Resting Phase",
      // "duration": 180, // seconds
      "duration": 180, // seconds
      "description": "2–3 minutes sitting quietly on the ergometer.",
    },
    {
      "name": "Unloaded Pedalling Phase",
      "duration": 180, // seconds
      "description": "2–3 minutes at 0 watts (warm-up).",
    },
    {
      "name": "Ramp Phase",
      "duration": 600, // seconds
      "description":
          "Increase workload by 10–30 watts per minute until exhaustion.",
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
      "id": "ramp_protocol",
      "name": protocolName,
      "description": protocolDescription,
      "version": protocolVersion,
      "phases": phases,
    };
  }
}
