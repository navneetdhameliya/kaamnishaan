import 'package:get/get.dart';

import '../models/api_models.g.dart';

/// The before/after pair to show (D-60): the pair saved for the report, else the same checklist shot
/// before and after, else the latest before and the latest after.
class ChosenPair {
  const ChosenPair({this.before, this.after, this.saved});

  final EvidenceOutModel? before;
  final EvidenceOutModel? after;

  /// Set when the pair was already chosen for the report.
  final PairOutModel? saved;

  bool get ready => before != null && after != null;

  static ChosenPair pick(EvidenceListModel list) {
    final pair = list.pairs.firstOrNull;
    if (pair != null) return ChosenPair(before: pair.before, after: pair.after, saved: pair);
    List<EvidenceOutModel> newest(String stage) =>
        list.data.where((e) => e.stage == stage).toList()..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final befores = newest('before');
    final afters = newest('after');
    for (final a in afters) {
      final match = befores.firstWhereOrNull((b) => a.shotSlot != null && b.shotSlot == a.shotSlot);
      if (match != null) return ChosenPair(before: match, after: a);
    }
    return ChosenPair(before: befores.firstOrNull, after: afters.firstOrNull);
  }
}
