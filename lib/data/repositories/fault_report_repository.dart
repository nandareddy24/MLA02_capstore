import 'package:sqflite/sqflite.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/errors/failure.dart';
import '../models/fault_report_model.dart';
import '../services/local_database_service.dart';
import '../services/preferences_service.dart';

/// Contract for creating, reading, updating, and deleting user-scoped fault reports.
abstract interface class FaultReportRepository {
  Future<Result<List<FaultReportModel>>> getAllReports();
  Future<Result<FaultReportModel?>> getReportById(String id);
  Future<Result<FaultReportModel>> createReport(FaultReportModel report);
  Future<Result<void>> updateReportStatus(
    String reportId,
    FaultReportStatus status,
  );
  Future<Result<void>> deleteReport(String id);
}

class FaultReportRepositoryImpl implements FaultReportRepository {
  FaultReportRepositoryImpl({
    required LocalDatabaseService databaseService,
    required PreferencesService preferencesService,
  })  : _databaseService = databaseService,
        _preferencesService = preferencesService;

  final LocalDatabaseService _databaseService;
  final PreferencesService _preferencesService;

  String get _currentUserId => _preferencesService.activeUserId ?? '';

  @override
  Future<Result<List<FaultReportModel>>> getAllReports() async {
    try {
      final userId = _currentUserId;
      if (userId.isEmpty) {
        return const Success([]);
      }
      final db = await _databaseService.database;
      final rows = await db.query(
        LocalDatabaseService.tableFaultReports,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
      return Success(rows.map(FaultReportModel.fromMap).toList());
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<FaultReportModel?>> getReportById(String id) async {
    try {
      final userId = _currentUserId;
      if (userId.isEmpty) {
        return const Success(null);
      }
      final db = await _databaseService.database;
      final rows = await db.query(
        LocalDatabaseService.tableFaultReports,
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Success(null);
      }
      return Success(FaultReportModel.fromMap(rows.first));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<FaultReportModel>> createReport(FaultReportModel report) async {
    try {
      final ownerId = report.userId.isNotEmpty ? report.userId : _currentUserId;
      final scopedReport = report.copyWith(userId: ownerId);
      final db = await _databaseService.database;
      await db.insert(
        LocalDatabaseService.tableFaultReports,
        scopedReport.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return Success(scopedReport);
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<void>> updateReportStatus(
    String reportId,
    FaultReportStatus status,
  ) async {
    try {
      final userId = _currentUserId;
      if (userId.isEmpty) return const Success(null);
      final db = await _databaseService.database;
      await db.update(
        LocalDatabaseService.tableFaultReports,
        {'status': status.name},
        where: 'id = ? AND user_id = ?',
        whereArgs: [reportId, userId],
      );
      return const Success(null);
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<void>> deleteReport(String id) async {
    try {
      final userId = _currentUserId;
      if (userId.isEmpty) return const Success(null);
      final db = await _databaseService.database;
      await db.delete(
        LocalDatabaseService.tableFaultReports,
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
      return const Success(null);
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }
}
