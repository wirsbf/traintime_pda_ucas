import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../course_reviews/utils/submission_utils.dart';
import '../course_reviews/utils/normalize.dart';
import '../../data/ucas_client.dart';
import 'webview_page.dart';

// Match TypeScript DraftReview type
class DraftReview {
  final ParsedCourseRow raw;
  String instructors;
  double value;
  double passDifficulty;
  double highScoreDifficulty;
  String remark;
  bool collapsed;

  DraftReview(this.raw)
    : instructors = raw.instructors, // Initialize from parsed data
      value = 4,
      passDifficulty = 3,
      highScoreDifficulty = 3,
      remark = "",
      collapsed = false;

  // ID for keys
  String get id =>
      '${raw.courseCode ?? "noCode"}__${raw.courseName}__${raw.term}';
}

class SubmitReviewPage extends StatefulWidget {
  const SubmitReviewPage({super.key});

  @override
  State<SubmitReviewPage> createState() => _SubmitReviewPageState();
}

class _SubmitReviewPageState extends State<SubmitReviewPage> {
  final TextEditingController _tsvController = TextEditingController();
  List<DraftReview> _drafts = [];
  List<String> _warnings = [];

  static const String _reviewSubmitUrl = "https://wj.qq.com/s2/25421061/5c9b/";

  @override
  void initState() {
    super.initState();
    // Listen to text changes to enable/disable parse button
    _tsvController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tsvController.dispose();
    super.dispose();
  }

  void _parse() {
    final tsv = _tsvController.text;
    if (tsv.trim().isEmpty) return;

    final result = parseSelectedCoursesTSV(tsv);

    setState(() {
      _warnings = result.warnings;
      _drafts = result.rows.map((r) => DraftReview(r)).toList();
    });
  }

  void _clear() {
    setState(() {
      _tsvController.clear();
      _drafts = [];
      _warnings = [];
    });
  }

  bool get _allComplete {
    return _drafts.isNotEmpty &&
        _drafts.every(
          (d) =>
              normalizeText(d.instructors).isNotEmpty &&
              normalizeText(d.remark).isNotEmpty,
        );
  }

  String _generateExportTSV() {
    final header = [
      "课程编码",
      "课程名称",
      "任课老师",
      "学分",
      "学位课",
      "学期",
      "价值(1-5)",
      "及格难度(1-5,低=易)",
      "高分难度(1-5,低=易)",
      "备注",
    ];
    final lines = [header.join('\t')];

    for (final d in _drafts) {
      lines.add(
        [
          d.raw.courseCode ?? "",
          d.raw.courseName,
          normalizeText(d.instructors),
          d.raw.credits.toString(),
          d.raw.isDegreeCourse ? "是" : "否",
          d.raw.term,
          d.value.toInt().toString(),
          d.passDifficulty.toInt().toString(),
          d.highScoreDifficulty.toInt().toString(),
          (d.remark).replaceAll(RegExp(r'\r?\n'), '\\n'),
        ].join('\t'),
      );
    }
    return lines.join('\n');
  }

  Future<void> _copyAndOpenSurvey() async {
    final text = _generateExportTSV();
    await Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制提交内容。正在打开问卷...')));
    }

    // Navigate to WebViewPage instead of external launch
    if (mounted) {
       Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const WebViewPage(
            url: _reviewSubmitUrl, 
            title: '填写问卷',
          ),
        ),
      );
    }
  }

  bool _isLoading = false;

  Future<void> _loadFromSystem() async {
    setState(() => _isLoading = true);
    try {
      final courses = await UcasClient.instance.fetchSelectedCoursesDetails();
      
      if (courses.isEmpty) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未获取到已选课程，请确保已登录选课系统')),
          );
        }
        return;
      }

      setState(() {
        _drafts = courses.map((c) => DraftReview(ParsedCourseRow(
          courseCode: c.code,
          courseName: c.name,
          credits: c.credits,
          isDegreeCourse: c.isDegree,
          term: c.semester,
          instructors: c.instructors,
        ))).toList();
        _warnings = [];
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 ${courses.length} 门课程')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('批量填写课程评价')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Step 1: Input
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '1. 导入已选课程',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_drafts.isNotEmpty)
                        TextButton(onPressed: _clear, child: const Text('清空')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (_isLoading)
                     const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton.icon(
                      onPressed: _loadFromSystem,
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('从教务系统一键导入'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    
                  if (!_isLoading && _drafts.isEmpty) ...[
                     const SizedBox(height: 16),
                     const Divider(),
                     ExpansionTile(
                        title: const Text('手动粘贴 (旧版方式)', style: TextStyle(fontSize: 14)),
                        children: [
                          TextField(
                            controller: _tsvController,
                            maxLines: 4,
                            minLines: 2,
                            decoration: const InputDecoration(
                              hintText: '请从 SEP 选课系统复制“已选课程”表格粘贴到这里...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _tsvController.text.isNotEmpty ? _parse : null,
                            child: const Text('解析 TSV'),
                          ),
                        ],
                     ),
                  ],

                  if (_warnings.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _warnings
                            .map(
                              (w) => Text(
                                '• $w',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              '2. 编辑评价 (${_drafts.length} 门)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Draft List
            ..._drafts.asMap().entries.map((entry) {
              final idx = entry.key;
              final d = entry.value;
              return _DraftCard(
                draft: d,
                index: idx,
                onUpdate: () => setState(() {}),
                onDelete: () => setState(() => _drafts.removeAt(idx)),
              );
            }),

            const SizedBox(height: 24),
            // Step 3: Submit
            Card(
              color: _allComplete ? Colors.green.shade50 : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      '3. 提交',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _allComplete
                          ? '已全部完成！点击下方按钮复制文本并跳转提交。'
                          : '请先补齐所有课程的“任课教师”和“备注”信息。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _allComplete
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _allComplete ? _copyAndOpenSurvey : null,
                      icon: const Icon(Icons.copy),
                      label: const Text('复制并去问卷提交'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '提交方式：复制文本 -> 打开问卷 -> 粘贴 -> 提交',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}

class _DraftCard extends StatefulWidget {
  final DraftReview draft;
  final int index;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  // We use controllers if we want, but simple onChange is fine for this prototype
  // Actually textfields need controllers to avoid cursor jumping if we rebuild whole list.
  late TextEditingController _teacherCtrl;
  late TextEditingController _remarkCtrl;

  @override
  void initState() {
    super.initState();
    _teacherCtrl = TextEditingController(text: widget.draft.instructors);
    _remarkCtrl = TextEditingController(text: widget.draft.remark);
  }

  // Update controllers if draft changes externally (unlikely here but good practice)
  @override
  void didUpdateWidget(_DraftCard oldWidget) {
    if (oldWidget.draft != widget.draft) {
      _teacherCtrl.text = widget.draft.instructors;
      _remarkCtrl.text = widget.draft.remark;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final isCollapsed = d.collapsed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          ListTile(
            title: Text(
              d.raw.courseName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${d.raw.term} · ${d.raw.credits}学分'),
            trailing: IconButton(
              icon: Icon(isCollapsed ? Icons.expand_more : Icons.expand_less),
              onPressed: () {
                d.collapsed = !d.collapsed;
                widget.onUpdate();
              },
            ),
            tileColor: Colors.grey.shade50,
          ),

          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _teacherCtrl,
                    decoration: const InputDecoration(
                      labelText: '任课老师 (必填)',
                      hintText: '多位老师请用顿号分隔',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      d.instructors = v;
                      widget.onUpdate(); // To check completeness
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StarSelector(
                          label: '价值',
                          value: d.value,
                          onChanged: (v) {
                            d.value = v;
                            widget.onUpdate();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StarSelector(
                          label: '及格难度',
                          value: d.passDifficulty,
                          onChanged: (v) {
                            d.passDifficulty = v;
                            widget.onUpdate();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StarSelector(
                          label: '高分难度',
                          value: d.highScoreDifficulty,
                          onChanged: (v) {
                            d.highScoreDifficulty = v;
                            widget.onUpdate();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _remarkCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '备注 (必填, 最重要)',
                      hintText: '课程感受/作业/给分/避坑建议...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      d.remark = v;
                      widget.onUpdate();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: widget.onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('删除此课程'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () {
                          d.collapsed = true;
                          widget.onUpdate();
                        },
                        child: const Text('确认'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // If collapsed, show mini summary
          if (isCollapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      d.instructors.isEmpty ? '未填老师' : d.instructors,
                      style: TextStyle(
                        color: d.instructors.isEmpty
                            ? Colors.red
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (d.remark.isEmpty)
                    const Text(
                      '未填备注',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    )
                  else
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StarSelector extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _StarSelector({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        DropdownButtonFormField<double>(
          initialValue: value,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            border: OutlineInputBorder(),
          ),
          items: [1, 2, 3, 4, 5]
              .map(
                (i) => DropdownMenuItem(
                  value: i.toDouble(),
                  child: Text(i.toString()),
                ),
              )
              .toList(),
          onChanged: (v) => onChanged(v ?? 3),
        ),
      ],
    );
  }
}
