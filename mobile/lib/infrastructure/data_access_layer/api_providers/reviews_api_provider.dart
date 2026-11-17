import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// Customer reviews: ask (M31, M15), cancel, My reviews (M44), one review. Returns raw JSON.
abstract class IReviewsApiProvider {
  Future<dynamic> postRequest(String jobId);
  Future<dynamic> deleteRequest(String requestId);
  Future<dynamic> getMine();
  Future<dynamic> getReview(String id);
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
}
