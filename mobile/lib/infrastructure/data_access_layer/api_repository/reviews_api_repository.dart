import '../../models/api_models.g.dart';
import '../api_providers/reviews_api_provider.dart';
import '../networks/api_result.dart';

abstract class IReviewsApiRepository {
  /// Ask the customer for a review. Goes with the report once it is approved (status queued),
  /// or right away when it already is (link_sent). Returns the job's review card.
  Future<ApiResult<JobReviewModel>> request(String jobId);

  /// Cancel while it waits for approval.
  Future<ApiResult<void>> cancel(String requestId);

  /// M44: my reviews this year, with the average and the good tags.
  Future<ApiResult<MyReviewsModel>> mine();

  /// M44: one review.
  Future<ApiResult<ReviewOutModel>> review(String id);
}

class ReviewsApiRepository implements IReviewsApiRepository {
  ReviewsApiRepository({required this.provider});

  final IReviewsApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<JobReviewModel>> request(String jobId) =>
      guard(() async => JobReviewModel.fromJson(_map(await provider.postRequest(jobId))));

  @override
  Future<ApiResult<void>> cancel(String requestId) => guard(() async {
        await provider.deleteRequest(requestId);
      });

  @override
  Future<ApiResult<MyReviewsModel>> mine() => guard(() async => MyReviewsModel.fromJson(_map(await provider.getMine())));

  @override
  Future<ApiResult<ReviewOutModel>> review(String id) =>
      guard(() async => ReviewOutModel.fromJson(_map(await provider.getReview(id))));
}
