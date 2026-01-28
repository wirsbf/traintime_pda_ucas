import '../models/review_model.dart';

class Percentiles {
  final double? Function(double value) valuePctHigherBetter;
  final double? Function(double value) passEasePctHigherBetter;
  final double? Function(double value) highScoreEasePctHigherBetter;

  Percentiles({
    required this.valuePctHigherBetter,
    required this.passEasePctHigherBetter,
    required this.highScoreEasePctHigherBetter,
  });
}

bool _isFiniteNumber(num n) {
  return n.isFinite && !n.isNaN;
}

List<double> _sortNums(Iterable<num> nums) {
  return nums.where(_isFiniteNumber).map((e) => e.toDouble()).toList()..sort();
}

// percentile of "value is high" (higher better):
// p = (# <= x)/N * 100
double? _percentileHigherBetter(List<double> sortedAsc, double x) {
  if (sortedAsc.isEmpty || !_isFiniteNumber(x)) return null;
  // upper_bound: first index with > x
  int lo = 0;
  int hi = sortedAsc.length;
  while (lo < hi) {
    int mid = (lo + hi) >> 1;
    if (sortedAsc[mid] <= x) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return (lo / sortedAsc.length) * 100;
}

// "lower is better" -> convert to "ease" percentile (higher better):
// easePct = (# >= x)/N * 100
double? _percentileLowerBetterAsEase(List<double> sortedAsc, double x) {
  if (sortedAsc.isEmpty || !_isFiniteNumber(x)) return null;
  // lower_bound: first index with >= x
  int lo = 0;
  int hi = sortedAsc.length;
  while (lo < hi) {
    int mid = (lo + hi) >> 1;
    if (sortedAsc[mid] < x) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  final countGE = sortedAsc.length - lo;
  return (countGE / sortedAsc.length) * 100;
}

Percentiles buildPercentiles(List<CourseGroup> groups) {
  final value = _sortNums(groups.map((g) => g.valueAvg));
  final pass = _sortNums(groups.map((g) => g.passDifficultyAvg));
  final high = _sortNums(groups.map((g) => g.highScoreDifficultyAvg));

  return Percentiles(
    valuePctHigherBetter: (x) => _percentileHigherBetter(value, x),
    passEasePctHigherBetter: (x) => _percentileLowerBetterAsEase(pass, x),
    highScoreEasePctHigherBetter: (x) => _percentileLowerBetterAsEase(high, x),
  );
}
