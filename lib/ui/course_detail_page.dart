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
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                label: '推荐指数',
                value: group.valueAvg.toStringAsFixed(1),
                color: Colors.green,
                isStar: true,
              ),
              _StatItem(
                label: 'Pass难度',
                value: group.passDifficultyAvg.toStringAsFixed(1),
                color: Colors.orange,
                isStar: true,
              ),
              _StatItem(
                label: '高分难度',
                value: group.highScoreDifficultyAvg.toStringAsFixed(1),
                color: Colors.red,
                isStar: true,
              ),
            ],
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

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isStar;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    this.isStar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.0,
              ),
            ),
            if (isStar) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.star, size: 16, color: color),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
