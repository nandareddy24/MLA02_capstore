import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/errors/failure.dart';
import '../models/diagnosis_result_model.dart';
import '../models/fault_report_model.dart';
import '../services/diagnosis_api_service.dart';
import '../services/local_database_service.dart';
import '../services/preferences_service.dart';

enum HistoryDateRange {
  all('All'),
  lastWeek('1W'),
  lastMonth('1M'),
  lastThreeMonths('3M'),
  lastYear('1Y');

  const HistoryDateRange(this.label);

  final String label;

  DateTime? cutoffFrom(DateTime now) => switch (this) {
        HistoryDateRange.all => null,
        HistoryDateRange.lastWeek => now.subtract(const Duration(days: 7)),
        HistoryDateRange.lastMonth => now.subtract(const Duration(days: 30)),
        HistoryDateRange.lastThreeMonths =>
          now.subtract(const Duration(days: 90)),
        HistoryDateRange.lastYear => now.subtract(const Duration(days: 365)),
      };
}

enum HistorySortOrder {
  newest('Newest'),
  oldest('Oldest');

  const HistorySortOrder(this.label);

  final String label;
}

class HistoryQuery {
  const HistoryQuery({
    this.search = '',
    this.severity,
    this.dateRange = HistoryDateRange.all,
    this.sortOrder = HistorySortOrder.newest,
    this.page = 1,
    this.pageSize = AppConstants.historyPageSize,
  });

  final String search;
  final FaultSeverity? severity;
  final HistoryDateRange dateRange;
  final HistorySortOrder sortOrder;
  final int page;
  final int pageSize;

  HistoryQuery copyWith({
    String? search,
    FaultSeverity? severity,
    bool clearSeverity = false,
    HistoryDateRange? dateRange,
    HistorySortOrder? sortOrder,
    int? page,
    int? pageSize,
  }) {
    return HistoryQuery(
      search: search ?? this.search,
      severity: clearSeverity ? null : (severity ?? this.severity),
      dateRange: dateRange ?? this.dateRange,
      sortOrder: sortOrder ?? this.sortOrder,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

/// Summary row displayed in the paginated Diagnosis History screen.
class HistoryListItem {
  const HistoryListItem({
    required this.reportId,
    this.diagnosisId,
    required this.deviceCategory,
    required this.deviceName,
    required this.predictedFault,
    required this.severity,
    required this.status,
    required this.diagnosedAt,
    this.hasFeedback = false,
  });

  final String reportId;
  final String? diagnosisId;
  final String deviceCategory;
  final String deviceName;
  final String predictedFault;
  final FaultSeverity severity;
  final FaultReportStatus status;
  final DateTime diagnosedAt;
  final bool hasFeedback;

  factory HistoryListItem.fromJoinMap(Map<String, Object?> map) {
    final predicted = (map['primary_fault'] as String?)?.trim();
    final title = (map['report_title'] as String?)?.trim() ?? 'Pending diagnosis';
    final category = (map['device_category'] as String?)?.trim();
    final rawDate =
        (map['analyzed_at'] as String?) ?? (map['created_at'] as String);

    return HistoryListItem(
      reportId: map['report_id'] as String,
      diagnosisId: map['diagnosis_id'] as String?,
      deviceCategory: (category != null && category.isNotEmpty)
          ? category.replaceAll('_', ' ')
          : 'Device',
      deviceName: map['device_name'] as String,
      predictedFault:
          (predicted != null && predicted.isNotEmpty) ? predicted : title,
      severity: FaultSeverity.fromName(
        (map['diagnosis_severity'] as String?) ??
            (map['report_severity'] as String?) ??
            'medium',
      ),
      status: FaultReportStatus.fromName(
        (map['report_status'] as String?) ?? 'diagnosed',
      ),
      diagnosedAt: DateTime.parse(rawDate),
      hasFeedback: ((map['feedback_count'] as num?)?.toInt() ?? 0) > 0,
    );
  }
}

class PaginatedHistoryResult {
  const PaginatedHistoryResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  final List<HistoryListItem> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasMore;
}

/// Read-only summary joining a completed [DiagnosisResultModel] with its
/// originating [FaultReportModel] for display on the Home Dashboard.
class RecentDiagnosisRecord {
  const RecentDiagnosisRecord({
    required this.diagnosisId,
    required this.reportId,
    required this.deviceName,
    required this.predictedFault,
    required this.severity,
    this.confidence,
    required this.diagnosedAt,
  });

  final String diagnosisId;
  final String reportId;
  final String deviceName;
  final String predictedFault;
  final FaultSeverity severity;
  final double? confidence;
  final DateTime diagnosedAt;

  factory RecentDiagnosisRecord.fromJoinMap(Map<String, Object?> map) {
    return RecentDiagnosisRecord(
      diagnosisId: map['diagnosis_id'] as String,
      reportId: map['report_id'] as String,
      deviceName: map['device_name'] as String,
      predictedFault: map['primary_fault'] as String,
      severity: FaultSeverity.fromName(
        (map['diagnosis_severity'] as String?) ??
            (map['report_severity'] as String?) ??
            'medium',
      ),
      confidence: (map['confidence'] as num?)?.toDouble(),
      diagnosedAt: DateTime.parse(map['analyzed_at'] as String),
    );
  }
}

/// Contract for AI-assisted fault diagnosis and user-scoped history retrieval.
abstract interface class DiagnosisRepository {
  Future<Result<DiagnosisResultModel?>> getCachedDiagnosis(String reportId);

  Future<Result<List<RecentDiagnosisRecord>>> getRecentDiagnoses({
    int limit = 3,
  });

  Future<Result<PaginatedHistoryResult>> queryHistory(HistoryQuery query);

  Future<Result<DiagnosisResultModel>> runDiagnosis(FaultReportModel report);
}

class DiagnosisRepositoryImpl implements DiagnosisRepository {
  DiagnosisRepositoryImpl({
    required DiagnosisApiService apiService,
    required LocalDatabaseService databaseService,
    required PreferencesService preferencesService,
  })  : _apiService = apiService,
        _databaseService = databaseService,
        _preferencesService = preferencesService;

  final DiagnosisApiService _apiService;
  final LocalDatabaseService _databaseService;
  final PreferencesService _preferencesService;

  String get _currentUserId => _preferencesService.activeUserId ?? '';

  @override
  Future<Result<DiagnosisResultModel?>> getCachedDiagnosis(
    String reportId,
  ) async {
    try {
      final userId = _currentUserId;
      if (userId.isEmpty) return const Success(null);
      final db = await _databaseService.database;
      final rows = await db.query(
        LocalDatabaseService.tableDiagnosisResults,
        where: 'report_id = ? AND user_id = ?',
        whereArgs: [reportId, userId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const Success(null);
      }
      return Success(DiagnosisResultModel.fromMap(rows.first));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<List<RecentDiagnosisRecord>>> getRecentDiagnoses({
    int limit = 3,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId.isEmpty) return const Success([]);
      final db = await _databaseService.database;
      final rows = await db.rawQuery(
        '''
        SELECT
          d.id AS diagnosis_id,
          d.report_id AS report_id,
          d.primary_fault AS primary_fault,
          d.confidence AS confidence,
          d.severity AS diagnosis_severity,
          d.analyzed_at AS analyzed_at,
          r.device_name AS device_name,
          r.severity AS report_severity
        FROM ${LocalDatabaseService.tableDiagnosisResults} d
        INNER JOIN ${LocalDatabaseService.tableFaultReports} r
          ON d.report_id = r.id
        WHERE d.user_id = ? AND r.user_id = ?
        ORDER BY d.analyzed_at DESC
        LIMIT ?
        ''',
        [userId, userId, limit],
      );

      return Success(rows.map(RecentDiagnosisRecord.fromJoinMap).toList());
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<PaginatedHistoryResult>> queryHistory(
    HistoryQuery query,
  ) async {
    try {
      final userId = _currentUserId;
      if (userId.isEmpty) {
        return PaginatedHistoryResult(
          items: const [],
          totalCount: 0,
          page: query.page,
          pageSize: query.pageSize,
          hasMore: false,
        ).toSuccess();
      }

      final db = await _databaseService.database;
      final whereClauses = <String>['r.user_id = ?'];
      final whereArgs = <Object?>[userId];

      final search = query.search.trim().toLowerCase();
      if (search.isNotEmpty) {
        final like = '%$search%';
        whereClauses.add(
          '(LOWER(r.device_name) LIKE ? OR LOWER(COALESCE(r.device_category, \'\')) LIKE ? OR LOWER(COALESCE(d.primary_fault, r.title)) LIKE ?)',
        );
        whereArgs.addAll([like, like, like]);
      }

      if (query.severity != null) {
        whereClauses.add(
          'LOWER(COALESCE(d.severity, r.severity)) = ?',
        );
        whereArgs.add(query.severity!.name);
      }

      final cutoff = query.dateRange.cutoffFrom(DateTime.now());
      if (cutoff != null) {
        whereClauses.add('COALESCE(d.analyzed_at, r.created_at) >= ?');
        whereArgs.add(cutoff.toIso8601String());
      }

      final whereSql = whereClauses.join(' AND ');
      final orderDir =
          query.sortOrder == HistorySortOrder.oldest ? 'ASC' : 'DESC';
      final offset = (query.page - 1) * query.pageSize;

      final countRows = await db.rawQuery(
        '''
        SELECT COUNT(*) AS cnt
        FROM ${LocalDatabaseService.tableFaultReports} r
        LEFT JOIN ${LocalDatabaseService.tableDiagnosisResults} d
          ON d.report_id = r.id AND d.user_id = r.user_id
        WHERE $whereSql
        ''',
        whereArgs,
      );
      final totalCount =
          (countRows.firstOrNull?['cnt'] as num?)?.toInt() ?? 0;

      final rows = await db.rawQuery(
        '''
        SELECT
          r.id AS report_id,
          r.device_name AS device_name,
          r.device_category AS device_category,
          r.title AS report_title,
          r.severity AS report_severity,
          r.status AS report_status,
          r.created_at AS created_at,
          d.id AS diagnosis_id,
          d.primary_fault AS primary_fault,
          d.severity AS diagnosis_severity,
          d.analyzed_at AS analyzed_at,
          (
            SELECT COUNT(*) FROM ${LocalDatabaseService.tableFeedback} f
            WHERE f.report_id = r.id AND f.user_id = r.user_id
          ) AS feedback_count
        FROM ${LocalDatabaseService.tableFaultReports} r
        LEFT JOIN ${LocalDatabaseService.tableDiagnosisResults} d
          ON d.report_id = r.id AND d.user_id = r.user_id
        WHERE $whereSql
        ORDER BY COALESCE(d.analyzed_at, r.created_at) $orderDir
        LIMIT ? OFFSET ?
        ''',
        [...whereArgs, query.pageSize, offset],
      );

      final items = rows.map(HistoryListItem.fromJoinMap).toList();
      final hasMore = (query.page * query.pageSize) < totalCount;

      return Success(
        PaginatedHistoryResult(
          items: items,
          totalCount: totalCount,
          page: query.page,
          pageSize: query.pageSize,
          hasMore: hasMore,
        ),
      );
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<DiagnosisResultModel>> runDiagnosis(
    FaultReportModel report,
  ) async {
    final apiResult = await _apiService.analyzeFault(report);
    return apiResult.when(
      success: (diagnosis) async {
        try {
          final ownerId =
              report.userId.isNotEmpty ? report.userId : _currentUserId;
          final db = await _databaseService.database;
          final map = Map<String, Object?>.from(diagnosis.toMap())
            ..['user_id'] = ownerId;
          await db.insert(
            LocalDatabaseService.tableDiagnosisResults,
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await db.update(
            LocalDatabaseService.tableFaultReports,
            {
              'status': FaultReportStatus.diagnosed.name,
              'severity': diagnosis.severity.name,
            },
            where: 'id = ? AND user_id = ?',
            whereArgs: [report.id, ownerId],
          );
          return Success(diagnosis);
        } catch (error) {
          return ErrorResult(ErrorMapper.mapException(error));
        }
      },
      failure: (err) async => ErrorResult(err),
    );
  }
}

extension _PaginatedSuccessX on PaginatedHistoryResult {
  Result<PaginatedHistoryResult> toSuccess() => Success(this);
}
