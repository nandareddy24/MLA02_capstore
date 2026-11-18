import 'package:flutter/material.dart';

import '../../../fault_reporting/presentation/screens/fault_reporting_screen.dart';

/// Entry screen for the Diagnose tab hosting the guided 4-step Device Selection
/// & Fault Reporting workflow.
class DeviceSelectionScreen extends StatelessWidget {
  const DeviceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FaultReportingScreen();
  }
}
