import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bluevo2/ProtocolManifests/BruceProtocol.dart';
import 'package:bluevo2/ProtocolManifests/IncrementalStepProtocol.dart';
import 'package:bluevo2/ProtocolManifests/ModifiedBruceProtocol.dart';
import 'package:bluevo2/ProtocolManifests/RampProtocol.dart';
import 'package:bluevo2/ProviderModals/GlobalSettingsModal.dart';

class ProtocolManifest {
  static final Map<String, dynamic> _ergoProtocols = {
    "ramp_protocol": () => RampProtocol().getProtocolDetails(),
    "incremental_step_protocol":
        () => IncrementalStepProtocol().getProtocolDetails(),
  };

  static final Map<String, dynamic> _treadmillProtocols = {
    "bruce_protocol": () => BruceProtocol().getProtocolDetails(),
    "modified_bruce_protocol":
        () => ModifiedBruceProtocol().getProtocolDetails(),
  };

  dynamic getSelectedProtocol(GlobalSettingsModal globalSettings) {
    // print("Selected Device Type: ${globalSettings.deviceType}");
    switch (globalSettings.deviceType) {
      case "ergoCycle":
        final protocolGetter = _ergoProtocols[globalSettings.ergoProtocol];
        if (protocolGetter != null) {
          return protocolGetter();
        }
        return null;
      case "treadmill":
        final protocolGetter =
            _treadmillProtocols[globalSettings.treadmillProtocol];
        if (protocolGetter != null) {
          return protocolGetter();
        }
        return null;
      case "none":
      default:
        return null;
    }
  }
}
