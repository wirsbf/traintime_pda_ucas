import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/schedule.dart';

import 'package:traintime_pda_ucas/util/schedule_utils.dart';
import 'widget/bouncing_button.dart';

const double _leftColumnWidth = 36; // Increased width for time text
const double _topRowHeight = 40;
const double _rowHeight = 48; // Increased height for 3 lines of text
const double _cardInset = 2;

const List<String> _weekdayCn = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const List<String> _weekdayEn = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class ScheduleGrid extends StatelessWidget {
  const ScheduleGrid({
    super.key,
    required this.courses,
    required this.startOfWeek,
    this.onCourseTap,
  });

  final List<Course> courses;
  final DateTime startOfWeek;
  final Function(Course)? onCourseTap;

  @override
  Widget build(BuildContext context) {
    bool hasWeekend = courses.any((c) {
      final w = c.weekday;
      return w == 'Saturday' || w == 'Sunday' || w == '周六' || w == '周日';
    });
    final visibleDays = hasWeekend ? 7 : 5;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final colWidth = (totalWidth - _leftColumnWidth) / visibleDays;
        final sectionCount = _sectionCount(courses);
        final gridHeight = _rowHeight * sectionCount;
        final layouts = _buildLayouts(courses, colWidth, sectionCount);

        return Column(
          children: [
            _HeaderRow(
              colWidth: colWidth,
              startOfWeek: startOfWeek,
              visibleDays: visibleDays,
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TimeColumn(sectionCount: sectionCount),
                    SizedBox(
                      width: totalWidth - _leftColumnWidth,
                      height: gridHeight,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(
                              totalWidth - _leftColumnWidth,
                              gridHeight,
                            ),
                            painter: _GridPainter(
                              rows: sectionCount,
                              cols: visibleDays,
                              rowHeight: _rowHeight,
                              colWidth: colWidth,
                            ),
                          ),
                          for (final item in layouts)
                            _CourseCard(
                              courses: item.courses,
                              layout: item.layout,
                              onTap: onCourseTap,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.colWidth,
    required this.startOfWeek,
    required this.visibleDays,
  });

  final double colWidth;
  final DateTime startOfWeek;
  final int visibleDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _topRowHeight,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _leftColumnWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${startOfWeek.month}月',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < visibleDays; i++)
            SizedBox(
              width: colWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayCn[i],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2A44),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 20,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isToday(startOfWeek.add(Duration(days: i)))
                          ? const Color(0xFF2563EB)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${startOfWeek.add(Duration(days: i)).day}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _isToday(startOfWeek.add(Duration(days: i)))
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.sectionCount});

  final int sectionCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _leftColumnWidth,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: List.generate(sectionCount, (index) {
          final section = index + 1;
          String start = '';
          String end = '';
          if (index < sectionLabels.length) {
            start = sectionLabels[index][0];
            end = sectionLabels[index][1];
          }

          return Container(
            height: _rowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$section',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF425466),
                    height: 1.0,
                  ),
                ),
                if (start.isNotEmpty)
                  Text(
                    start,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      height: 1.1,
                    ),
                  ),
                if (end.isNotEmpty)
                  Text(
                    end,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      height: 1.1,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.courses, required this.layout, this.onTap});

  final List<Course> courses;
  final _CourseLayout layout;
  final Function(Course)? onTap;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) return const SizedBox.shrink();

    final course = courses.first;
    // Use scarlet color for exams
    final isExam = course.id.startsWith('E_') || course.name.startsWith('[考试]');
    final palette = isExam ? _examPalette : _paletteForWeekday(course.weekday);
    final count = courses.length;

    return Positioned(
      top: layout.top,
      left: layout.left,
      width: layout.width,
      height: layout.height,
      child: BouncingButton(
        onTap: () {
          if (courses.length == 1 && onTap != null) {
            onTap!(courses.first);
            return;
          }
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(count > 1 ? '课程列表 ($count)' : course.name),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: count,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final c = courses[index];
                    return InkWell(
                      onTap: onTap != null
                          ? () {
                              Navigator.pop(context);
                              onTap!(c);
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 1)
                              Text(
                                c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            Text('教室: ${c.classroom}'),
                            if (c.teacher.isNotEmpty) Text('教师: ${c.teacher}'),
                            Text('时间: ${c.weekday} ${_sectionLabelStr(c)}'),
                            if (c.weeks.isNotEmpty) Text('周次: ${c.weeks}'),
                            if (c.notes.isNotEmpty) Text('备注: ${c.notes}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: palette.border,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.fill,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${course.classroom}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: palette.text),
                    ),
                    Text(
                      _sectionLabelStr(course),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 8,
                        color: palette.text.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (count > 1)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        topRight: Radius.circular(5),
                      ),
                    ),
                    child: Text(
                      '+${count - 1}',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: palette.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _sectionLabelStr(Course course) {
    // Helper to friendly format section part
    // This is a bit ad-hoc, but better than nothing
    return '${course.timeSlot.startTime}-${course.timeSlot.endTime}';
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.rows,
    required this.cols,
    required this.rowHeight,
    required this.colWidth,
  });

  final int rows;
  final int cols;
  final double rowHeight;
  final double colWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEAEFF5)
      ..strokeWidth = 1;

    for (int r = 1; r <= rows; r++) {
      final y = rowHeight * r;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (int c = 1; c <= cols; c++) {
      final x = colWidth * c;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return rows != oldDelegate.rows ||
        cols != oldDelegate.cols ||
        rowHeight != oldDelegate.rowHeight ||
        colWidth != oldDelegate.colWidth;
  }
}

class _CourseLayout {
  final double top;
  final double left;
  final double width;
  final double height;
  final int startSection;
  final int endSection;

  const _CourseLayout({
    required this.top,
    required this.left,
    required this.width,
    required this.height,
    required this.startSection,
    required this.endSection,
  });
}

class _CoursePalette {
  final Color border;
  final Color fill;
  final Color text;

  const _CoursePalette({
    required this.border,
    required this.fill,
    required this.text,
  });
}

// Scarlet palette for exams (#FF2400)
const _examPalette = _CoursePalette(
  border: Color(0xFFFF2400),
  fill: Color(0xFFFFE5E0),
  text: Color(0xFF8B1500),
);

class _LayoutItem {
  _LayoutItem({required this.courses, required this.layout});

  final List<Course> courses;
  final _CourseLayout layout;
}

List<_LayoutItem> _buildLayouts(
  List<Course> courses,
  double colWidth,
  int sectionCount,
) {
  final events = <_LayoutItem>[];

  // Helper to check overlap
  bool isOverlapping(int start1, int end1, int start2, int end2) {
    return (start1 < end2 && end1 > start2);
  }

  // Pre-process courses into temporary items with range
  final items = <_TempItem>[];
  for (final course in courses) {
    final range = _sectionRange(course);
    if (range == null) continue;
    items.add(_TempItem(course, range.$1, range.$2));
  }

  // Sort by start time
  items.sort((a, b) {
    if (a.start != b.start) return a.start.compareTo(b.start);
    return a.end.compareTo(b.end);
  });

  for (final item in items) {
    int? mergeIndex;

    // Find if it overlaps with any existing event
    for (int i = 0; i < events.length; i++) {
      final existing = events[i];
      if (existing.courses.isEmpty) continue;

      // We use the layout range of the existing event
      final exStart = existing.layout.startSection;
      final exEnd = existing.layout.endSection;

      // Check overlap. Note: The existing event might be on a different DAY!
      // Wait, _buildLayouts in previous code handled ALL days.
      // We MUST ensure we only merge courses on the SAME DAY.
      final exDay = existing.courses.first.weekday;
      if (exDay == item.course.weekday) {
        if (isOverlapping(item.start, item.end, exStart, exEnd)) {
          mergeIndex = i;
          break;
        }
      }
    }

    if (mergeIndex != null) {
      // Merge
      final existing = events[mergeIndex];
      final newStart = math.min(existing.layout.startSection, item.start);
      final newEnd = math.max(existing.layout.endSection, item.end);

      final newLayout = _CourseLayout(
        top: _rowHeight * (newStart - 1) + _cardInset,
        left: existing.layout.left, // Keep same left/width
        width: existing.layout.width,
        height: _rowHeight * (newEnd - newStart + 1) - _cardInset * 2,
        startSection: newStart,
        endSection: newEnd,
      );

      existing.courses.add(item.course);
      // Update layout (hacky: we are replacing the layout of the existing item)
      // Since _LayoutItem is final, we replace the item in the list
      events[mergeIndex] = _LayoutItem(
        courses: existing.courses,
        layout: newLayout,
      );
    } else {
      // Add new
      final dayIndex = _weekdayIndex(item.course.weekday);
      if (dayIndex == null) {
        continue; // Should not happen if _sectionRange worked
      }

      final layout = _CourseLayout(
        top: _rowHeight * (item.start - 1) + _cardInset,
        left: colWidth * dayIndex + _cardInset,
        width: colWidth - _cardInset * 2,
        height: _rowHeight * (item.end - item.start + 1) - _cardInset * 2,
        startSection: item.start,
        endSection: item.end,
      );
      events.add(_LayoutItem(courses: [item.course], layout: layout));
    }
  }

  return events;
}

class _TempItem {
  final Course course;
  final int start;
  final int end;
  _TempItem(this.course, this.start, this.end);
}

int _sectionCount(List<Course> courses) {
  int maxSection = sectionLabels.length;
  for (final course in courses) {
    final range = _sectionRange(course);
    if (range != null) {
      maxSection = math.max(maxSection, range.$2);
    }
  }
  return maxSection;
}

(int, int)? _sectionRange(Course course) {
  final start = _parseSectionIndex(course.timeSlot.startTime, true);
  final end = _parseSectionIndex(course.timeSlot.endTime, false);
  if (start == null && end == null) {
    return null;
  }
  if (start != null && end != null) {
    return (start, math.max(start, end));
  }
  final value = start ?? end ?? 1;
  return (value, value);
}

int? _parseSectionIndex(String value, bool isStart) {
  final number = _parseSectionNumber(value);
  if (number != null) {
    return number;
  }
  final minutes = _parseTimeMinutes(value);
  if (minutes == null) {
    return null;
  }

  int? bestIndex;
  int? bestDiff;
  for (int i = 0; i < sectionMinutes.length; i++) {
    final target = isStart ? sectionMinutes[i][0] : sectionMinutes[i][1];
    final diff = (minutes - target).abs();
    if (bestDiff == null || diff < bestDiff) {
      bestDiff = diff;
      bestIndex = i;
    } else if (!isStart && diff == bestDiff && i > (bestIndex ?? 0)) {
      bestIndex = i;
    }
  }
  if (bestDiff != null && bestDiff <= 60) {
    return (bestIndex ?? 0) + 1;
  }
  return null;
}

int? _parseSectionNumber(String value) {
  final match = RegExp(r'(\d+)').firstMatch(value);
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1) ?? '');
}

int? _parseTimeMinutes(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  return hour * 60 + minute;
}

(String, String)? _sectionLabel(int section) {
  if (section < 1 || section > sectionLabels.length) {
    return null;
  }
  return (sectionLabels[section - 1][0], sectionLabels[section - 1][1]);
}

int? _weekdayIndex(String value) {
  final index = _weekdayEn.indexOf(value);
  if (index != -1) {
    return index;
  }
  final cnIndex = _weekdayCn.indexOf(value);
  if (cnIndex != -1) {
    return cnIndex;
  }
  return null;
}

_CoursePalette _paletteForWeekday(String weekday) {
  switch (weekday) {
    case 'Monday':
    case '周一':
      return const _CoursePalette(
        border: Color(0xFFF3B6A6),
        fill: Color(0xFFFDE8E2),
        text: Color(0xFF6B3D2E),
      );
    case 'Tuesday':
    case '周二':
      return const _CoursePalette(
        border: Color(0xFFF2CF8A),
        fill: Color(0xFFFDF2D4),
        text: Color(0xFF6A4A1A),
      );
    case 'Wednesday':
    case '周三':
      return const _CoursePalette(
        border: Color(0xFF9CD9E8),
        fill: Color(0xFFE3F4F8),
        text: Color(0xFF1D4E5C),
      );
    case 'Thursday':
    case '周四':
      return const _CoursePalette(
        border: Color(0xFF9ADBB3),
        fill: Color(0xFFE6F6EE),
        text: Color(0xFF1F5C3A),
      );
    case 'Friday':
    case '周五':
      return const _CoursePalette(
        border: Color(0xFFF5C28B),
        fill: Color(0xFFFEF0D7),
        text: Color(0xFF6A3F14),
      );
    case 'Saturday':
    case '周六':
      return const _CoursePalette(
        border: Color(0xFFB7B2F0),
        fill: Color(0xFFEBE9FD),
        text: Color(0xFF3D3577),
      );
    case 'Sunday':
    case '周日':
      return const _CoursePalette(
        border: Color(0xFFF4B6C2),
        fill: Color(0xFFFDE7ED),
        text: Color(0xFF6B2C3A),
      );
  }
  return const _CoursePalette(
    border: Color(0xFFE2E8F0),
    fill: Color(0xFFF8FAFC),
    text: Color(0xFF334155),
  );
}

bool _isToday(DateTime day) {
  final now = DateTime.now();
  return day.year == now.year && day.month == now.month && day.day == now.day;
}
