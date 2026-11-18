import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/device_model.dart';
import '../../../../data/repositories/providers.dart';
import '../../../dashboard/presentation/controllers/dashboard_controller.dart';

/// Manages the offline-first list of registered equipment devices.
class DeviceSelectionController extends AsyncNotifier<List<DeviceModel>> {
  @override
  Future<List<DeviceModel>> build() async {
    final result = await ref.watch(deviceRepositoryProvider).getAllDevices();
    return result.when(
      success: (devices) => devices,
      failure: (err) => throw err,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<String?> addDevice({
    required String name,
    required DeviceCategory category,
    required String manufacturer,
    required String modelNumber,
    String? serialNumber,
    String? location,
  }) async {
    final device = DeviceModel(
      id: 'dev_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      category: category,
      manufacturer: manufacturer.trim(),
      modelNumber: modelNumber.trim(),
      serialNumber:
          serialNumber?.trim().isEmpty == true ? null : serialNumber?.trim(),
      location: location?.trim().isEmpty == true ? null : location?.trim(),
      createdAt: DateTime.now(),
    );

    final result = await ref.read(deviceRepositoryProvider).createDevice(device);
    return result.when(
      success: (_) {
        ref.invalidateSelf();
        ref.invalidate(dashboardControllerProvider);
        return null;
      },
      failure: (err) => err.message,
    );
  }

  Future<String?> deleteDevice(String id) async {
    final result = await ref.read(deviceRepositoryProvider).deleteDevice(id);
    return result.when(
      success: (_) {
        ref.invalidateSelf();
        ref.invalidate(dashboardControllerProvider);
        return null;
      },
      failure: (err) => err.message,
    );
  }
}

final deviceSelectionControllerProvider =
    AsyncNotifierProvider<DeviceSelectionController, List<DeviceModel>>(
  DeviceSelectionController.new,
);
