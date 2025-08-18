class RampProtocol {
  static const String protocolName = "Ramp Protocol";
  static const String protocolDescription =
      "A protocol for ramping up the pressure during a test.";
  static const String protocolVersion = "1.0.0";
  static const String type = "ergoCycle"; // "ergoCycle", "treadmill"

  // Ramp Protocol (Most Common)
  // Increases workload continuously or every 10–20 seconds in small increments.
  // Phase	Description
  // Resting	2–3 minutes sitting quietly on ergometer
  // Unloaded Pedalling	2–3 minutes at 0 watts (warm-up)
  // Ramp Phase	Increase by 10–30 watts/min until exhaustion
  // Recovery	4–6 minutes unloaded pedaling and rest

  // phase configuration array
  // static const List<Map<String, dynamic>> phases = [
  //   {
  //     "id": "resting_phase",
  //     "name": "Resting Phase",
  //     // "duration": 180, // seconds
  //     "duration": 30, // seconds
  //     "description": "2–3 minutes sitting quietly on the ergometer.",
  //   },
  //   {
  //     "id": "unloaded_pedalling_phase",
  //     "name": "Unloaded Pedalling Phase",
  //     "duration": 30, // seconds
  //     "description": "2–3 minutes at 0 watts (warm-up).",
  //   },
  //   {
  //     "id": "ramp_phase",
  //     "name": "Ramp Phase",
  //     "duration": 30, // seconds
  //     "description":
  //         "Increase workload by 10–30 watts per minute until exhaustion.",
  //   },
  //   {
  //     "id": "recovery_phase",
  //     "name": "Recovery Phase",
  //     "duration": 30, // seconds
  //     "description": "3 minutes of unloaded pedalling and rest.",
  //   },
  // ];

  static const List<Map<String, dynamic>> phases = [
    {
      "id": "resting_phase",
      "name": "Resting Phase",
      "duration": 180, // seconds
      "description": "2–3 minutes sitting quietly on the ergometer.",
      "load": 0, // watts
    },
    {
      "id": "unloaded_pedalling_phase",
      "name": "Unloaded Pedalling Phase",
      "duration": 180, // seconds
      "description": "2–3 minutes at 0 watts (warm-up).",
      "load": 0, // watts
    },
    {
      "id": "ramp_phase",
      "name": "Ramp Phase",
      "duration": 300, // seconds
      "description":
          "Increase workload by 10–30 watts per minute until exhaustion.",
      "load": "ramp",
    },
    {
      "id": "recovery_phase",
      "name": "Recovery Phase",
      "duration": 180, // seconds
      "description": "3 minutes of unloaded pedalling and rest.",
      "load": 0, // watts
    },
  ];

  // Function to get the protocol details
  Map<String, dynamic> getProtocolDetails() {
    return {
      "id": "ramp_protocol",
      "name": protocolName,
      "description": protocolDescription,
      "version": protocolVersion,
      "type": type,
      "phases": phases,
    };
  }
}
