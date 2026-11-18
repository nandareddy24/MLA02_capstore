import 'package:sqflite/sqflite.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/errors/failure.dart';
import '../models/device_model.dart';
import '../services/local_database_service.dart';

/// Contract for offline-first device inventory management.
abstract interface class DeviceRepository {
  Future<Result<List<DeviceModel>>> getAllDevices();
  Future<Result<DeviceModel?>> getDeviceById(String id);
  Future<Result<DeviceModel>> createDevice(DeviceModel device);
  Future<Result<void>> deleteDevice(String id);
}

class DeviceRepositoryImpl implements DeviceRepository {
  DeviceRepositoryImpl(this._databaseService);

  final LocalDatabaseService _databaseService;

  @override
  Future<Result<List<DeviceModel>>> getAllDevices() async {
    try {
      final db = await _databaseService.database;
      final rows = await db.query(
        LocalDatabaseService.tableDevices,
        orderBy: 'created_at DESC',
      );
      return Success(rows.map(DeviceModel.fromMap).toList());
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<DeviceModel?>> getDeviceById(String id) async {
    try {
      final db = await _databaseService.database;
      final rows = await db.query(
        LocalDatabaseService.tableDevices,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Success(null);
      }
      return Success(DeviceModel.fromMap(rows.first));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<DeviceModel>> createDevice(DeviceModel device) async {
    try {
      final db = await _databaseService.database;
      await db.insert(
        LocalDatabaseService.tableDevices,
        device.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return Success(device);
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<void>> deleteDevice(String id) async {
    try {
      final db = await _databaseService.database;
      await db.delete(
        LocalDatabaseService.tableDevices,
        where: 'id = ?',
        whereArgs: [id],
      );
      return const Success(null);
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }
}
