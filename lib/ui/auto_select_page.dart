import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/course_robber.dart';
import '../data/settings_controller.dart';

class AutoSelectPage extends StatelessWidget {
  final SettingsController settings;

  const AutoSelectPage({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CourseRobber(settings),
      child: const _AutoSelectView(),
    );
  }
}

class _AutoSelectView extends StatefulWidget {
  const _AutoSelectView();

  @override
  State<_AutoSelectView> createState() => _AutoSelectViewState();
}

class _AutoSelectViewState extends State<_AutoSelectView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final ScrollController _logScroll = ScrollController();
  String _searchQuery = '';
  bool _searchByCode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  void _addCourse(BuildContext context) {
    final robber = context.read<CourseRobber>();
    final nameInput = _nameController.text.trim();
    final codeInput = _codeController.text.trim();

    if (nameInput.isEmpty && codeInput.isEmpty) return;
    
    // If name is empty, use code as name
    final name = nameInput.isEmpty ? codeInput : nameInput;

    robber.addTarget(codeInput, name);
    _nameController.clear();
    _codeController.clear();
    
    // Switch to cart tab
    _tabController.animateTo(1);
  }

  void _scrollToBottom() {
    if (_logScroll.hasClients) {
      _logScroll.animateTo(
        _logScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final robber = context.watch<CourseRobber>();

    // Auto scroll logs when on logs tab
    if (_tabController.index == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('自动抢课'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.search),
              text: '搜索课程',
            ),
            Tab(
              icon: Badge(
                label: Text('${robber.targets.length}'),
                isLabelVisible: robber.targets.isNotEmpty,
                child: const Icon(Icons.shopping_cart),
              ),
              text: '待选列表',
            ),
            Tab(
              icon: Badge(
                label: Text('${robber.logs.length}'),
                isLabelVisible: robber.logs.isNotEmpty,
                child: const Icon(Icons.terminal),
              ),
              text: '选课日志',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(robber),
          _buildCartTab(robber),
          _buildLogsTab(robber),
        ],
      ),
    );
  }

  /// Tab 1: Search and add courses
  /// Tab 1: Search and add courses
  Widget _buildSearchTab(CourseRobber robber) {
    return Column(
      children: [
        // Search Bar Area
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: _searchByCode ? '搜索课程编码' : '搜索课程名称',
                        hintText: _searchByCode ? '如: 091M4001H' : '如: 计算机',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (val) =>
                          robber.searchCourses(val, isCode: _searchByCode),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: robber.isSearching
                        ? null
                        : () => robber.searchCourses(_searchController.text,
                            isCode: _searchByCode),
                    child: robber.isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('搜索'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Options Row
              Row(
                children: [
                  FilterChip(
                    label: const Text('搜名称'),
                    selected: !_searchByCode,
                    onSelected: (v) => setState(() => _searchByCode = false),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('搜编码'),
                    selected: _searchByCode,
                    onSelected: (v) => setState(() => _searchByCode = true),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showManualAddDialog,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('手动录入'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Error message
        if (robber.searchError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              robber.searchError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),

        const Divider(height: 1),

        // Results List
        Expanded(
          child: robber.searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.manage_search,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        robber.isSearching ? '正在搜索...' : '请输入关键词搜索',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      if (!robber.isSearching)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            '若搜索不到，请使用"手动录入"直接添加\n或尝试通过课程编码精确搜索',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Colors.grey.withOpacity(0.7)),
                          ),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: robber.searchResults.length,
                  itemBuilder: (context, index) {
                    final course = robber.searchResults[index];
                    final isAdded =
                        robber.targets.any((t) => t.fullCode == course.code);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: InkWell(
                        onTap: () => _showCourseActionDialog(course, isAdded),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Status
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      course.name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (isAdded)
                                    const Icon(Icons.check_circle,
                                        color: Colors.green, size: 20),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Code & Teacher
                              Text(
                                  '${course.code}  ${course.teacher.isNotEmpty ? "|  ${course.teacher}" : ""}'),

                              // Attributes
                              if (course.attribute.isNotEmpty ||
                                  course.level.isNotEmpty ||
                                  course.teachingMethod.isNotEmpty ||
                                  course.examMethod.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (course.attribute.isNotEmpty)
                                        _buildTag(course.attribute, Colors.blue),
                                      if (course.level.isNotEmpty)
                                        _buildTag(course.level, Colors.orange),
                                      if (course.teachingMethod.isNotEmpty)
                                        _buildTag(
                                            course.teachingMethod, Colors.purple),
                                      if (course.examMethod.isNotEmpty)
                                        _buildTag(course.examMethod, Colors.teal),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 6),
                              // Capacity
                              Text(
                                '容量: ${course.enrollmentStatus}',
                                style: TextStyle(
                                  color: course.isFull ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showManualAddDialog() {
    // Ensure controllers are cleared or preset
    _nameController.clear();
    _codeController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动添加课程'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '课程名称',
                hintText: '如: 高级软件工程',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '课程编码/ID (建议填写)',
                hintText: '精确匹配用',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (_nameController.text.trim().isEmpty && _codeController.text.trim().isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写名称或编码')));
                 return;
              }
              _addCourse(context);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已手动添加课程')),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showCourseActionDialog(SearchResult course, bool isAdded) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(course.name),
        content: Text(isAdded ? '已在待选列表中，要移除吗？' : '要添加到抢课待选列表吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final robber = context.read<CourseRobber>();
              if (isAdded) {
                final idx =
                    robber.targets.indexWhere((t) => t.fullCode == course.code);
                if (idx != -1) robber.removeTarget(idx);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已移除: ${course.name}')));
              } else {
                robber.addFromSearch(course);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加: ${course.name}')));
              }
            },
            style: isAdded
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(isAdded ? '移除' : '添加'),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color)),
    );
  }

  /// Tab 2: Cart - courses waiting to be selected
  Widget _buildCartTab(CourseRobber robber) {
    return Column(
      children: [
        // Course list
        Expanded(
          child: robber.targets.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '尚未添加课程',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '在"搜索课程"中添加课程',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: robber.targets.length,
                  itemBuilder: (context, index) {
                    final course = robber.targets[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: InkWell(
                        onTap: robber.status == RobberStatus.running
                            ? null
                            : () {
                                showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                          title: Text(course.name),
                                          content: const Text('确定从待选列表中移除该课程吗？'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: const Text('取消')),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                  backgroundColor: Colors.red),
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                robber.removeTarget(index);
                                              },
                                              child: const Text('移除'),
                                            ),
                                          ],
                                        ));
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Status icon
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      course.name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (course.selected)
                                    const Icon(Icons.check_circle,
                                        color: Colors.green, size: 20)
                                  else if (robber.status == RobberStatus.running)
                                    const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                  else
                                    const Icon(Icons.pending_actions,
                                        color: Colors.orange, size: 20),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Code & Teacher
                              Text(
                                  '${course.fullCode.isNotEmpty ? course.fullCode : "(无编码)"}  ${course.teacher.isNotEmpty ? "|  ${course.teacher}" : ""}'),

                              // Attributes
                              if (course.attribute.isNotEmpty ||
                                  course.level.isNotEmpty ||
                                  course.teachingMethod.isNotEmpty ||
                                  course.examMethod.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (course.attribute.isNotEmpty)
                                        _buildTag(course.attribute, Colors.blue),
                                      if (course.level.isNotEmpty)
                                        _buildTag(course.level, Colors.orange),
                                      if (course.teachingMethod.isNotEmpty)
                                        _buildTag(
                                            course.teachingMethod, Colors.purple),
                                      if (course.examMethod.isNotEmpty)
                                        _buildTag(
                                            course.examMethod, Colors.teal),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        
        // Control panel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: Icon(
                      robber.status == RobberStatus.running
                          ? Icons.stop
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      robber.status == RobberStatus.running
                          ? '停止抢课'
                          : '开始抢课',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: robber.status == RobberStatus.running
                          ? Colors.red
                          : Colors.green,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: robber.targets.isEmpty
                        ? null
                        : () {
                            if (robber.status == RobberStatus.running) {
                              robber.stop();
                            } else {
                              robber.start();
                              // Switch to logs tab when starting
                              _tabController.animateTo(2);
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Tab 3: Logs
  Widget _buildLogsTab(CourseRobber robber) {
    return Column(
      children: [
        // Logs
        Expanded(
          child: Container(
            color: Colors.black87,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            child: robber.logs.isEmpty
                ? const Center(
                    child: Text(
                      '暂无日志',
                      style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                    ),
                  )
                : ListView.builder(
                    controller: _logScroll,
                    itemCount: robber.logs.length,
                    itemBuilder: (context, index) {
                      final log = robber.logs[index];
                      final timeStr = '${log.time.hour.toString().padLeft(2, '0')}:'
                          '${log.time.minute.toString().padLeft(2, '0')}:'
                          '${log.time.second.toString().padLeft(2, '0')}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '[$timeStr] ${log.message}',
                          style: TextStyle(
                            color: log.isError ? Colors.redAccent : Colors.greenAccent,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        
        // Control bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black54,
          child: Row(
            children: [
              Text(
                '状态: ${_statusText(robber.status)}',
                style: TextStyle(
                  color: _statusColor(robber.status),
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.clear_all, color: Colors.white70),
                label: const Text('清空日志', style: TextStyle(color: Colors.white70)),
                onPressed: () => robber.clearLogs(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusText(RobberStatus status) {
    switch (status) {
      case RobberStatus.idle:
        return '待命';
      case RobberStatus.running:
        return '运行中...';
      case RobberStatus.success:
        return '成功';
      case RobberStatus.stopped:
        return '已停止';
      case RobberStatus.error:
        return '错误';
    }
  }

  Color _statusColor(RobberStatus status) {
    switch (status) {
      case RobberStatus.idle:
        return Colors.grey;
      case RobberStatus.running:
        return Colors.yellow;
      case RobberStatus.success:
        return Colors.green;
      case RobberStatus.stopped:
        return Colors.orange;
      case RobberStatus.error:
        return Colors.red;
    }
  }
}
