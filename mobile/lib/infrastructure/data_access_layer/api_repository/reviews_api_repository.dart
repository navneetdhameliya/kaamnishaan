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

  /// M45: every review, with the average and the chips. [filter] is all, needs_reply or low.
  Future<ApiResult<ReviewsPageModel>> company(String filter);

  /// M45: send (or change) the one reply.
  Future<ApiResult<ReplyOutModel>> reply(String id, String text);

  /// M45 "Suggest a reply".
  Future<ApiResult<String>> suggestion(String id);

  /// M45 Low rating: the private note and "Mark as resolved".
  Future<ApiResult<FollowupOutModel>> followUp(String id, FollowupInModel body);

  /// M45 Review requests. [status] is waiting, rated or opted_out.
  Future<ApiResult<RequestsPageModel>> requests(String status);

  /// M46: the company's review settings and follow-ups.
  Future<ApiResult<ReviewSettingsOutModel>> settings();

  Future<ApiResult<ReviewSettingsOutModel>> saveSettings(ReviewSettingsInModel body);
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

  @override
  Future<ApiResult<ReviewsPageModel>> company(String filter) =>
      guard(() async => ReviewsPageModel.fromJson(_map(await provider.getCompanyReviews(filter))));

  @override
  Future<ApiResult<ReplyOutModel>> reply(String id, String text) =>
      guard(() async => ReplyOutModel.fromJson(_map(await provider.postReply(id, ReplyInModel(text: text).toJson()))));

  @override
  Future<ApiResult<String>> suggestion(String id) =>
      guard(() async => SuggestionOutModel.fromJson(_map(await provider.postSuggestion(id))).text);

  @override
  Future<ApiResult<FollowupOutModel>> followUp(String id, FollowupInModel body) =>
      guard(() async => FollowupOutModel.fromJson(_map(await provider.patchFollowup(id, body.toJson()..removeWhere((_, v) => v == null)))));

  @override
  Future<ApiResult<RequestsPageModel>> requests(String status) =>
      guard(() async => RequestsPageModel.fromJson(_map(await provider.getRequests(status))));

  @override
  Future<ApiResult<ReviewSettingsOutModel>> settings() =>
      guard(() async => ReviewSettingsOutModel.fromJson(_map(await provider.getSettings())));

  @override
  Future<ApiResult<ReviewSettingsOutModel>> saveSettings(ReviewSettingsInModel body) =>
      guard(() async => ReviewSettingsOutModel.fromJson(_map(await provider.patchSettings(body.toJson()..removeWhere((_, v) => v == null)))));
}
