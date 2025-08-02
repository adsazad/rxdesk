import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spirobtvo/ProtocolManifests/BruceProtocol.dart';
import 'package:spirobtvo/ProtocolManifests/IncrementalStepProtocol.dart';
import 'package:spirobtvo/ProtocolManifests/ModifiedBruceProtocol.dart';
import 'package:spirobtvo/ProtocolManifests/RampProtocol.dart';
import 'package:spirobtvo/ProviderModals/GlobalSettingsModal.dart';

class ProtocolManifest {
  static final Map<String, dynamic> _ergoProtocols = {
    "ramp_protocol": () => RampProtocol().getProtocolDetails(),
    "incremental_step_protocol":
        () => IncrementalStepProtocol().getProtocolDetails(),
  };

  static final Map<String, dynamic> _treadmillProtocols = {
    "Bruce": () => BruceProtocol().getProtocolDetails(),
    "Modified Bruce": () => ModifiedBruceProtocol().getProtocolDetails(),
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
