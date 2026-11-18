import 'package:sqflite/sqflite.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/fault_report_model.dart';
import '../models/feedback_model.dart';
import '../services/local_database_service.dart';
import '../services/preferences_service.dart';

/// Contract for persisting user-scoped post-diagnosis feedback without duplicates.
abstract interface class FeedbackRepository {
  Future<Result<List<FeedbackModel>>> getFeedbackForReport(String reportId);
  Future<Result<FeedbackModel>> submitFeedback(FeedbackModel feedback);
}

class FeedbackRepositoryImpl implements FeedbackRepository {
  FeedbackRepositoryImpl({
    required LocalDatabaseService databaseService,
    required ApiClient apiClient,
    required PreferencesService preferencesService,
  })  : _databaseService = databaseService,
        _apiClient = apiClient,
        _preferencesService = preferencesService;

  final LocalDatabaseService _databaseService;
  final ApiClient _apiClient;
  final PreferencesService _preferencesService;

  String get _currentUserId => _preferencesService.activeUserId ?? '';

  @override
  Future<Result<List<FeedbackModel>>> getFeedbackForReport(
    String reportId,
  ) async {
    try {
      final userId = _currentUserId;
      if (userId.isEmpty) return const Success([]);
      final db = await _databaseService.database;
      final rows = await db.query(
        LocalDatabaseService.tableFeedback,
        where: 'report_id = ? AND user_id = ?',
        whereArgs: [reportId, userId],
        orderBy: 'submitted_at DESC',
      );
      return Success(rows.map(FeedbackModel.fromMap).toList());
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<FeedbackModel>> submitFeedback(FeedbackModel feedback) async {
    try {
      final ownerId =
          feedback.userId.isNotEmpty ? feedback.userId : _currentUserId;
      final db = await _databaseService.database;

      // Prevent duplicate submissions by reusing existing ID for (user_id, report_id).
      final existing = await db.query(
        LocalDatabaseService.tableFeedback,
        columns: ['id'],
        where: 'report_id = ? AND user_id = ?',
        whereArgs: [feedback.reportId, ownerId],
        limit: 1,
      );
      final effectiveId = existing.isNotEmpty
          ? existing.first['id'] as String
          : feedback.id;
      final isUpdate = existing.isNotEmpty;

      final scoped = FeedbackModel(
        id: effectiveId,
        userId: ownerId,
        diagnosisId: feedback.diagnosisId,
        reportId: feedback.reportId,
        diagnosisRelevance: feedback.diagnosisRelevance,
        resolutionStatus: feedback.resolutionStatus,
        wasHelpful: feedback.wasHelpful,
        wasIssueResolved: feedback.wasIssueResolved,
        stillNeedsProfessionalAssistance:
            feedback.stillNeedsProfessionalAssistance,
        rating: feedback.rating,
        comments: feedback.comments,
        submittedAt: feedback.submittedAt,
      );

      await db.insert(
        LocalDatabaseService.tableFeedback,
        scoped.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (scoped.wasIssueResolved ||
          scoped.resolutionStatus == ResolutionStatus.resolved) {
        await db.update(
          LocalDatabaseService.tableFaultReports,
          {'status': FaultReportStatus.resolved.name},
          where: 'id = ? AND user_id = ?',
          whereArgs: [scoped.reportId, ownerId],
        );
      }

      if (_apiClient.isConfigured) {
        if (isUpdate) {
          await _apiClient.put<void>(
            ApiEndpoints.submitFeedback,
            data: scoped.toJson(),
          );
        } else {
          await _apiClient.post<void>(
            ApiEndpoints.submitFeedback,
            data: scoped.toJson(),
          );
        }
      }

      return Success(scoped);
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }
}
