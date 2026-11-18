import '../../core/errors/error_mapper.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/decision_support_plan_model.dart';
import '../models/diagnosis_result_model.dart';
import '../models/fault_report_model.dart';

/// Dedicated API client for the separate FixWise Decision Support Service.
class DecisionSupportApiService {
  DecisionSupportApiService(this._apiClient);

  final ApiClient _apiClient;

  bool get isConfigured => _apiClient.isConfigured;

  Future<Result<DecisionSupportPlanModel>> fetchRecommendations({
    required DiagnosisResultModel diagnosis,
    required FaultReportModel report,
  }) async {
    if (!_apiClient.isConfigured) {
      return const ErrorResult(ModelNotIntegratedFailure());
    }

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.decisionSupportRecommend,
        data: {
          'diagnosis_id': diagnosis.id,
          'report_id': report.id,
          'device_category': report.deviceCategory ?? 'other',
          'device_name': report.deviceName,
          'predicted_fault': diagnosis.primaryFault,
          'symptoms': report.symptoms,
          if (report.description.isNotEmpty) 'description': report.description,
          if (report.operatingConditions != null)
            'operating_conditions': report.operatingConditions,
        },
      );

      final data = response.data;
      if (data == null || data.isEmpty) {
        return const ErrorResult(
          ServerFailure(
            'Decision support service returned an empty recommendation plan.',
          ),
        );
      }

      return Success(DecisionSupportPlanModel.fromJson(data));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }
}
