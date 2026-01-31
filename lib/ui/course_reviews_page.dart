import 'package:flutter/material.dart';
import '../course_reviews/data/reviews_service.dart';
import '../course_reviews/logic/aggregator.dart';
import '../course_reviews/models/review_model.dart';
import 'widget/swipe_back_route.dart';
import 'package:url_launcher/url_launcher.dart';
import 'submit_review_page.dart';
import 'course_detail_page.dart';

class CourseReviewsPage extends StatefulWidget {
  const CourseReviewsPage({super.key});

  @override
  State<CourseReviewsPage> createState() => _CourseReviewsPageState();
}

class _CourseReviewsPageState extends State<CourseReviewsPage> {
  // Cache the aggregated groups
  List<CourseGroup> _allGroups = [];
  List<CourseGroup> _filteredGroups = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reviews = await ReviewsService.fetchReviews();
      final groups = aggregateCourses(reviews);
      if (mounted) {
        setState(() {
          _allGroups = groups;
          _filteredGroups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredGroups = _allGroups);
      return;
    }

    setState(() {
      _filteredGroups = _allGroups.where((g) {
        return g.courseName.toLowerCase().contains(query) ||
            g.instructorsCanonical.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选课评价'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '关于本项目',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('关于选课评价'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('本项目核心数据与逻辑移植自：'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => launchUrl(
                          Uri.parse(
                            'https://github.com/2654400439/UCAS-Course-Reviews',
                          ),
                        ),
                        child: const Text(
                          '2654400439/UCAS-Course-Reviews',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('感谢社区同学们整理的详尽课程评价！\n本App会实时拉取最新数据。'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SubmitReviewPage()));
        },
        icon: const Icon(Icons.add_comment),
        label: const Text('写评价'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索课程或教师...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadReviews,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : _filteredGroups.isEmpty
                        ? const Center(child: Text('没有找到相关课程'))
                        : ListView.separated(
                            itemCount: _filteredGroups.length,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            separatorBuilder: (c, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final group = _filteredGroups[index];
                              return _CourseGroupCard(group: group);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _CourseGroupCard extends StatelessWidget {
  final CourseGroup group;

  const _CourseGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    // Use rating color
    final rating = group.valueAvg;
    final color = rating >= 4.0
        ? Colors.green
        : (rating >= 3.0 ? Colors.orange : Colors.red);
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(SwipeBackPageRoute(page: CourseDetailPage(group: group)));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    group.courseName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '教师: ${group.instructorsCanonical}',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _Tag(text: '${group.reviewCount}条评价'),
                const SizedBox(width: 8),
                _Tag(text: '易过: ${group.passDifficultyAvg.toStringAsFixed(1)}'),
                const SizedBox(width: 8),
                _Tag(
                  text:
                      '高分: ${group.highScoreDifficultyAvg.toStringAsFixed(1)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }
}
