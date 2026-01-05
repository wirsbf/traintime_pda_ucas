import 'package:flutter/material.dart';
import '../data/ucas_client.dart';
import '../model/lecture.dart';
import '../data/settings_controller.dart';
import '../model/schedule.dart';
import '../data/cache_manager.dart';
import '../util/schedule_utils.dart';

class LectureDetailDialog extends StatefulWidget {
  final Lecture lecture;
  final SettingsController settings;

  const LectureDetailDialog({super.key, required this.lecture, required this.settings});

  @override
  State<LectureDetailDialog> createState() => _LectureDetailDialogState();
}

class _LectureDetailDialogState extends State<LectureDetailDialog> {
  bool _loading = true;
  String _content = '';
  late String _location;

  @override
  void initState() {
    super.initState();
    _location = widget.lecture.location;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final detail = await UcasClient().fetchLectureDetail(
          widget.lecture.id, 
          username: widget.settings.username, 
          password: widget.settings.password
      );
      if (mounted) {
        setState(() {
          _content = detail['content'] ?? '暂无详情';
          if (detail.containsKey('location') && detail['location']!.isNotEmpty) {
             _location = detail['location']!;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _content = '加载失败: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AlertDialog(
      title: Text(widget.lecture.name),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), // Ensure standard margins but allow width
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      content: SizedBox(
        width: size.width * 0.9, // Make it wider (90% screen width)
        child: ConstrainedBox(
           constraints: BoxConstraints(
             maxHeight: size.height * 0.7, // Limit height
           ),
           child: SingleChildScrollView(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisSize: MainAxisSize.min,
               children: [
                 _buildInfoRow(Icons.person, '主讲人', widget.lecture.speaker),
                 _buildInfoRow(Icons.access_time, '时间', widget.lecture.time),
                 _buildInfoRow(Icons.location_on, '地点', _location), // Use updated location
                 _buildInfoRow(Icons.apartment, '单位', widget.lecture.department),
                 const Divider(height: 24),
                 if (_loading)
                   const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                 else
                   Text(_content, style: const TextStyle(height: 1.5, fontSize: 14)),
               ],
             ),
           ),
        ),
      ),
      actions: [
        TextButton(onPressed: _addToSchedule, child: const Text('加入课表')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Icon(icon, size: 16, color: Colors.blue.shade700),
           const SizedBox(width: 8),
           Expanded(
             child: RichText(
                text: TextSpan(
                   style: const TextStyle(color: Colors.black87, fontSize: 14),
                   children: [
                      TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: value),
                   ],
                ),
             ),
           ),
        ],
      ),
    );
  }

  Future<void> _addToSchedule() async {
    // 1. Parse Date to Weekday and Week Index
    if (widget.lecture.date.isEmpty) {
      _showToast('无法添加：日期无效');
      return;
    }
    final date = DateTime.tryParse(widget.lecture.date);
    if (date == null) {
      _showToast('无法添加：日期格式错误');
      return;
    }
    
    // Calculate Week Number
    // (date - start) / 7 + 1 - offset? 
    // Settings has currentWeek() but that's for NOW.
    // We need week for the specific date.
    final start = widget.settings.termStartDate;
    final diff = date.difference(start).inDays;
    // If before start, maybe -1? 
    // Week 1 starts at day 0 to 6?
    // User Settings has weekOffset?
    
    // Simplified logic: Week 1 is the week containing termStartDate.
    // Monday of termStartDate is Day 0.
    final mondayOfStart = start.subtract(Duration(days: start.weekday - 1));
    final daysFromMonday = date.difference(mondayOfStart).inDays;
    final weekNum = (daysFromMonday / 7).floor() + 1 + widget.settings.weekOffset;
    
    if (weekNum < 1 || weekNum > widget.settings.semesterLength) {
       // Allow adding but warn? Or just add.
    }

    // 2. Parse Time to Section
    String timeStr = widget.lecture.time;
    String startTime = '19:00';
    String endTime = '21:00';
    
    final timeMatch = RegExp(r'(\d{1,2}:\d{2})').firstMatch(timeStr);
    if (timeMatch != null) {
       startTime = timeMatch.group(1)!;
       final matches = RegExp(r'(\d{1,2}:\d{2})').allMatches(timeStr).toList();
       if (matches.length > 1) {
          endTime = matches.last.group(1)!;
       } else {
          final parts = startTime.split(':');
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          endTime = '${h+2}:${m.toString().padLeft(2, '0')}';
       }
    }
    
    // Map to sections using schedule_utils
    final sections = mapTimeToSections(startTime, endTime);
    final finalStartT = '第${sections.$1}节';
    final finalEndT = '第${sections.$2}节';

    // Weekday mapping
    final wds = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    final finalCourse = Course(
       id: 'L_${widget.lecture.id}', 
       name: '讲座: ${widget.lecture.name}',
       teacher: widget.lecture.speaker,
       classroom: _location,
       weekday: wds[date.weekday - 1],
       timeSlot: TimeSlot(startTime: finalStartT, endTime: finalEndT),
       weeks: weekNum.toString(),
       notes: '讲座',
       displayTime: timeStr, // Use original time string
    );
    
    await CacheManager().addCustomCourse(finalCourse);
    _showToast('已添加到课程表 (第$weekNum周)');
    if (mounted) Navigator.pop(context);
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }
} // End of State class

// Extension to add actions
extension _DialogActions on _LectureDetailDialogState {
   List<Widget> get _actions => [
       TextButton(onPressed: _addToSchedule, child: const Text('加入课表')),
       TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
   ];
}
