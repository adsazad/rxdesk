import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spirobtvo/ProtocolManifests/IncrementalStepProtocol.dart';
import 'package:spirobtvo/ProtocolManifests/RampProtocol.dart';
import 'package:spirobtvo/ProviderModals/GlobalSettingsModal.dart';

class ProtocolManifest {
  static final Map<String, dynamic> _ergoProtocols = {
    "Ramp Protocol": () => RampProtocol().getProtocolDetails(),
    "Incremental Step Protocol":
        () => IncrementalStepProtocol().getProtocolDetails(),
  };

  static final Map<String, dynamic> _treadmillProtocols = {
    "Bruce": () => throw Exception("Bruce protocol not implemented yet"),
    "Modified Bruce":
        () => throw Exception("Modified Bruce protocol not implemented yet"),
  };

  dynamic getSelectedProtocol(BuildContext context) {
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );

    switch (globalSettings.deviceType) {
      case "ergoCycle":
        final protocolGetter = _ergoProtocols[globalSettings.ergoProtocol];
        if (protocolGetter != null) {
          return protocolGetter();
        }
        throw Exception(
          "Unknown ergoCycle protocol selected: ${globalSettings.ergoProtocol}",
        );
      case "treadmill":
        final protocolGetter =
            _treadmillProtocols[globalSettings.treadmillProtocol];
        if (protocolGetter != null) {
          return protocolGetter();
        }
        throw Exception(
          "Unknown treadmill protocol selected: ${globalSettings.treadmillProtocol}",
        );
      default:
        throw Exception(
          "Unknown device type selected: ${globalSettings.deviceType}",
        );
    }
  }
}
