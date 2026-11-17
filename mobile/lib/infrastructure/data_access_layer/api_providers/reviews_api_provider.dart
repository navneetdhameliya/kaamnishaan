import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// Customer reviews: ask (M31, M15), cancel, My reviews (M44), one review, and the office side (M45, M46).
/// Returns raw JSON.
abstract class IReviewsApiProvider {
  Future<dynamic> postRequest(String jobId);
  Future<dynamic> deleteRequest(String requestId);
  Future<dynamic> getMine();
  Future<dynamic> getReview(String id);
  Future<dynamic> getCompanyReviews(String filter);
  Future<dynamic> postReply(String id, Map<String, dynamic> body);
  Future<dynamic> postSuggestion(String id);
  Future<dynamic> patchFollowup(String id, Map<String, dynamic> body);
  Future<dynamic> getRequests(String status);
  Future<dynamic> getSettings();
  Future<dynamic> patchSettings(Map<String, dynamic> body);
}

class ReviewsApiProvider implements IReviewsApiProvider {
  ReviewsApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> postRequest(String jobId) => _client.post(APIConstant.reviewRequestAPIEP(jobId));

  @override
  Future<dynamic> deleteRequest(String requestId) => _client.delete(APIConstant.cancelReviewRequestAPIEP(requestId));

  @override
  Future<dynamic> getMine() => _client.get(APIConstant.myReviewsAPIEP);

  @override
  Future<dynamic> getReview(String id) => _client.get(APIConstant.reviewAPIEP(id));

  @override
  Future<dynamic> getCompanyReviews(String filter) =>
      _client.get(APIConstant.companyReviewsAPIEP, query: {'filter': filter});

  @override
  Future<dynamic> postReply(String id, Map<String, dynamic> body) => _client.post(APIConstant.reviewReplyAPIEP(id), body: body);

  @override
  Future<dynamic> postSuggestion(String id) => _client.post(APIConstant.reviewSuggestionAPIEP(id));

  @override
  Future<dynamic> patchFollowup(String id, Map<String, dynamic> body) =>
      _client.patch(APIConstant.reviewFollowupAPIEP(id), body: body);

  @override
  Future<dynamic> getRequests(String status) => _client.get(APIConstant.reviewRequestsAPIEP, query: {'status': status});

  @override
  Future<dynamic> getSettings() => _client.get(APIConstant.reviewSettingsAPIEP);

  @override
  Future<dynamic> patchSettings(Map<String, dynamic> body) => _client.patch(APIConstant.reviewSettingsAPIEP, body: body);
}
