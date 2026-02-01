import 'package:flutter/material.dart';
import '../course_reviews/models/review_model.dart';

class CourseDetailPage extends StatelessWidget {
  final CourseGroup group;

  const CourseDetailPage({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('课程详情'), centerTitle: true),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _CourseHeader(group: group)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final review = group.reviews[index];
                return _ReviewCard(review: review);
              }, childCount: group.reviews.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseHeader extends StatelessWidget {
  final CourseGroup group;

  const _CourseHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            group.courseName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            group.instructorsCanonical,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Display College and Course Code
          if (group.colleges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                group.colleges.join(' / '),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          if (group.reviews.isNotEmpty &&
              group.reviews.first.courseCode != null)
            Text(
              '课程编码: ${group.reviews.first.courseCode}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          const SizedBox(height: 16),
          _DetailedStatItem(
            label: '推荐指数',
            value: group.valueAvg.toStringAsFixed(1),
            percentile: group.valuePercentile,
            barValue: group.valuePercentile,
            description: '超过 ${group.valuePercentile.toStringAsFixed(0)}% 的课程',
            color: Colors.green,
            isStar: true,
          ),
          const SizedBox(height: 12),
          _DetailedStatItem(
            label: 'Pass难度',
            value: group.passDifficultyAvg.toStringAsFixed(1),
            percentile: 100 - group.passDifficultyAvg/5.0*100, // This is just for bar visual, but we use calculated percentile
            // real percentile from aggregator
            barValue: group.passPercentile, 
            description: '比 ${group.passPercentile.toStringAsFixed(0)}% 的课程更容易及格',
            color: Colors.orange,
            isStar: true,
          ),
          const SizedBox(height: 12),
          _DetailedStatItem(
            label: '高分难度',
            value: group.highScoreDifficultyAvg.toStringAsFixed(1),
            percentile: group.highScoreDifficultyAvg, // Visual
            barValue: group.highScorePercentile,
            description: '比 ${group.highScorePercentile.toStringAsFixed(0)}% 的课程更容易拿高分',
            color: Colors.red,
            isStar: true,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              _InfoChip(label: '${group.reviewCount}条评价'),
              _InfoChip(label: '${group.creditsMin}-${group.creditsMax}学分'),
              if (group.isDegreeCourseAny) const _InfoChip(label: '学位课'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailedStatItem extends StatelessWidget {
  final String label;
  final String value;
  final double barValue; // 0-100
  final double? percentile; // unused in build but kept for compat
  final String description;
  final Color color;
  final bool isStar;

  const _DetailedStatItem({
    required this.label,
    required this.value,
    required this.barValue,
    this.percentile,
    required this.description,
    required this.color,
    this.isStar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (isStar) ...[
              const SizedBox(width: 4),
              Icon(Icons.star, size: 16, color: color),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: barValue / 100,
            backgroundColor: color.withOpacity(0.1),
            color: color,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: const [
             Text('0%', style: TextStyle(fontSize: 10, color: Colors.grey)),
             Text('25%', style: TextStyle(fontSize: 10, color: Colors.grey)),
             Text('50%', style: TextStyle(fontSize: 10, color: Colors.grey)),
             Text('75%', style: TextStyle(fontSize: 10, color: Colors.grey)),
             Text('100%', style: TextStyle(fontSize: 10, color: Colors.grey)),
           ],
        )
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewRow review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    review.term,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (review.credits > 0)
                  Text(
                    '${review.credits}学分',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MiniStat(
                  label: '推荐',
                  value: review.value,
                  color: Colors.green,
                ),
                const SizedBox(width: 16),
                _MiniStat(
                  label: 'Pass',
                  value: review.passDifficulty,
                  color: Colors.orange,
                ),
                const SizedBox(width: 16),
                _MiniStat(
                  label: '高分',
                  value: review.highScoreDifficulty,
                  color: Colors.red,
                ),
              ],
            ),
            if (review.remark != null && review.remark!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  review.remark!.replaceAll(
                    '\\n',
                    '\n',
                  ), // Handle escaped newlines
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Icon(Icons.star, size: 12, color: color),
      ],
    );
  }
}
