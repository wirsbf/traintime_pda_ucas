import '../model/schedule.dart';
import '../model/exam.dart';

bool courseMatchesWeek(Course course, int week) {
  final weeksText = course.weeks.trim();
  if (weeksText.isEmpty || weeksText.contains('未')) {
    return true;
  }
  final parsed = parseWeeks(weeksText);
  if (parsed.isEmpty) {
    // If the text contains digits but parsed is empty, it means parsing failed
    // or it's a specific non-matching format. In this case, don't show it.
    if (weeksText.contains(RegExp(r'\d'))) {
      return false;
    }
    return true;
  }
  return parsed.contains(week);
}

Set<int> parseWeeks(String text) {
  var cleaned = text
      .replaceAll('周', '')
      .replaceAll('第', '')
      .replaceAll('，', ',')
      .replaceAll('、', ',')
      .trim();

  final oddOnly = cleaned.contains('单');
  final evenOnly = cleaned.contains('双');
  cleaned = cleaned.replaceAll(RegExp(r'[^0-9,\-]'), '');
  if (cleaned.isEmpty) {
    return {};
  }

  final weeks = <int>{};
  for (final part in cleaned.split(',')) {
    if (part.isEmpty) {
      continue;
    }

    // Handle range like "1-10"
    // Note: Use split('-') but check that it's not a single negative number
    final rangeParts = part.split('-');
    
    // A standard range "A-B" where A and B are positive
    if (rangeParts.length == 2 && rangeParts[0].isNotEmpty && rangeParts[1].isNotEmpty) {
      final start = int.tryParse(rangeParts[0]);
      final end = int.tryParse(rangeParts[1]);
      if (start != null && end != null && start <= end) {
        for (var i = start; i <= end; i++) {
          weeks.add(i);
        }
        continue;
      }
    }

    // If not a valid range, try as a single number (handles negative like "-1")
    final value = int.tryParse(part);
    if (value != null) {
      weeks.add(value);
    }
  }

  if (oddOnly || evenOnly) {
    weeks.removeWhere((week) {
      if (oddOnly) {
        return week % 2 == 0;
      }
      return week % 2 == 1; // evenOnly
    });
  }

  return weeks;
}

// Maps arbitrary time range "HH:mm"-"HH:mm" to standard section range (startSection, endSection)
(int, int) mapTimeToSections(String startTime, String endTime) {
  int? parseTime(String t) {
    final parts = t.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  final startMin = parseTime(startTime);
  final endMin = parseTime(endTime);

  if (startMin == null || endMin == null) return (13, 13); // Fallback to bottom

  // Logic:
  // Find start section: standardStart <= customStart < standardEnd (approx)
  // Find end section: standardStart < customEnd <= standardEnd

  int startSec = 13;
  int endSec = 13;

  // Find matching start section
  // Priority: if it starts exactly or within a section's range
  // Check precise cover first

  for (int i = 0; i < sectionMinutes.length; i++) {
    // sectionMinutes[i] = [start, end]
    final sStart = sectionMinutes[i][0];
    final sEnd = sectionMinutes[i][1];

    // Relaxed matching: if custom start is within [start-10, end]
    if (startMin >= sStart - 15 && startMin < sEnd) {
      startSec = i + 1;
      break;
    }
  }

  // If no start found, maybe it starts before 1st section?
  if (startSec == 13 && startMin < sectionMinutes[0][0]) {
    startSec = 1;
  }

  // If still not found, find the first section that starts AFTER custom start?
  // No, user said "19:00-21:00" -> 10-12 (18:30-21:00)
  // 19:00 is > 18:30 (section 10 start) and < 19:15 (section 10 end). So it catches section 10.
  // My loop above: 19:00 (1140) >= 1110 - 15 (1095) && 1140 < 1155. Yes. Matches Sec 10.

  // Find end section
  for (int i = 0; i < sectionMinutes.length; i++) {
    final sStart = sectionMinutes[i][0];
    final sEnd = sectionMinutes[i][1];

    // 21:00 (1260) should match section 12 (20:15 - 21:00) [1215, 1260]
    // customEnd <= sEnd + buffer && customEnd > sStart
    if (endMin <= sEnd + 5 && endMin > sStart) {
      endSec = i + 1;
    }
  }

  // Fix range
  if (startSec > endSec) endSec = startSec;

  // Special handling for evening exams if standard logic fails or is too narrow?
  // 19:00-21:00. Start=10. End=12 (21:00 is exactly end of sec 12).
  // result 10-12. Correct.

  // 13:30-15:30. 13:30=810. Sec 5 is [810, 855]. Matches Sec 5.
  // 15:30=930. Sec 6 is [860, 905]. Sec 7 is [925, 970].
  // 930 is inside Sec 7.
  // So result would be 5-7. User asked for 5-6 (13:30-15:05).
  // 15:30 is 25 mins into Sec 7.
  // Maybe user meant 13:30-15:30 usually covers 2 hours, which is 2 classes + break?
  // Sec 5+6 = 45+45 = 90 mins. + break 5 mins = 95 mins. finishes 15:05.
  // 15:30 is significantly later.
  // But user stated: "13:30-15:30应该被加在5-6节课".
  // Wait, if it extends into Sec 7, why cut it off?
  // Maybe because 15:30 is just "end of exam" and exams are 2 hours.
  // If I map to 5-7, it shows 3 slots.
  // If I map to 5-6, it shows 2 slots.
  // User wants 5-6.
  // Maybe I should aggressively fit into "Shortest course segment covering exam"?
  // "选取能覆盖考试时间段的最短课程段" -> "Select the shortest course segment that COVERS the exam".
  // 13:30-15:30 is 120 mins. Sec 5-6 is 95 mins. It DOES Not cover it.
  // Sec 5-7 is 95 + 20 + 45 = 160 mins. Covers it.
  // So strictly speaking, 5-7 is correct for "Covering".
  // BUT User said "13:30-15:30 should be 5-6". That contradicts "Covering".
  // "19:00-21:00 should be 10-12". 19:00-21:00 is 120 mins.
  // Sec 10-12 (18:30-21:00) is 150 mins. Covers it.
  // Maybe 13:30-15:30 meant "Exam is 2 hours", typically occupying the slot of 2 classes.
  // Currently my logic would give 5-7.
  // Let's refine end logic:
  // Match end section if customEnd consumes > 50% of the section?
  // Or match end section if customEnd > start of section.

  // Let's stick to my logic first, but maybe tune "End".
  // If 15:30 (930). Sec 7 starts 925. 930 is 5 mins in.
  // It barely touches Sec 7.
  // Maybe threshold: must overlap at least 15 mins?
  // 15:30 vs Sec 7 (925-970). overlap 5 mins. Ignore.
  // 21:00 vs Sec 12 (1215-1260). overlap 45 mins. Include.
  // 19:00-21:00 -> Start 19:00 vs Sec 10 (18:30-19:15). Overlap 15 mins. Include.

  // New End Logic:
  // Iterate sections. If (min(customEnd, sEnd) - max(customStart, sStart)) > 10 mins -> Include.

  int first = -1;
  int last = -1;

  for (int i = 0; i < sectionMinutes.length; i++) {
    final sStart = sectionMinutes[i][0];
    final sEnd = sectionMinutes[i][1];

    // Overlap = max(0, min(end, sEnd) - max(start, sStart))
    final overlap =
        (endMin < sEnd ? endMin : sEnd) -
        (startMin > sStart ? startMin : sStart);

    if (overlap >= 10) {
      // Require at least 10 mins overlap to count as occupying that section
      if (first == -1) first = i + 1;
      last = i + 1;
    }
  }

  if (first != -1 && last != -1) {
    return (first, last);
  }

  return (13, 13);
}

const List<List<String>> sectionLabels = [
  ['08:30', '09:15'],
  ['09:20', '10:05'],
  ['10:25', '11:10'],
  ['11:15', '12:00'],
  [
    '13:30',
    '14:15',
  ], // Note: Afternoon start might differ, ensuring standard UCAS time
  ['14:20', '15:05'],
  ['15:25', '16:10'],
  ['16:15', '17:00'],
  ['17:05', '17:50'], // 9
  ['18:30', '19:15'], // 10
  ['19:20', '20:05'],
  ['20:15', '21:00'],
  ['21:05', '21:50'],
];

// Standard minutes for overlap calculation
// Updating to match UCAS standard timetable generally.
// The image shows: 1(08:30-09:15), 2(09:20-10:05), 3(10:25-11:10), 4(11:15-12:00)
// 5(13:30-14:15), 6(14:20-15:05), 7(15:25-16:10), 8(16:15-17:00), 9(17:05-17:50)
// 10(18:30-19:15), 11(19:20-20:05), 12(20:15-21:00), 13(21:05-21:50)

// I will update sectionLabels to MATCH the user image exactly.
const List<List<int>> sectionMinutes = [
  [510, 555], // 1
  [560, 605], // 2
  [625, 670], // 3
  [675, 720], // 4
  [810, 855], // 5 13:30
  [860, 905], // 6
  [925, 970], // 7
  [975, 1020], // 8
  [1025, 1070], // 9
  [1110, 1155], // 10 18:30
  [1160, 1205], // 11
  [1215, 1260], // 12
  [1265, 1310], // 13
];

String getTimeStringFromSection(int startSection, int endSection) {
  if (startSection < 1 || startSection > sectionLabels.length) return '';
  if (endSection < 1 || endSection > sectionLabels.length) return '';

  final startStr = sectionLabels[startSection - 1][0];
  final endStr = sectionLabels[endSection - 1][1];
  return '$startStr-$endStr';
}

Course? examToCourse(Exam exam, DateTime termStartDate, int weekOffset) {
  if (exam.date.isEmpty) return null;
  final date = DateTime.tryParse(exam.date);
  if (date == null) return null;

  final mondayOfStart = termStartDate.subtract(
    Duration(days: termStartDate.weekday - 1),
  );
  final daysFromMonday = date.difference(mondayOfStart).inDays;
  final weekNum = (daysFromMonday / 7).floor() + 1 + weekOffset;

  // Parse time and map to sections
  String startT = '00:00';
  String endT = '00:00';

  final parts = exam.time.split('-');
  if (parts.length == 2) {
    startT = parts[0].trim();
    endT = parts[1].trim();
  } else {
    // Try regex if format varies
    final matches = RegExp(r'(\d{1,2}:\d{2})').allMatches(exam.time).toList();
    if (matches.length >= 2) {
      startT = matches[0].group(1)!;
      endT = matches.last.group(1)!;
    }
  }

  final sections = mapTimeToSections(startT, endT);
  final finalStartT = '第${sections.$1}节';
  final finalEndT = '第${sections.$2}节';

  // Weekday mapping
  final wds = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  return Course(
    id: 'E_${exam.courseName}_${exam.date}',
    name: '[考试] ${exam.courseName}',
    teacher: '',
    classroom: '${exam.location} ${exam.seat}',
    weekday: wds[date.weekday - 1],
    timeSlot: TimeSlot(startTime: finalStartT, endTime: finalEndT),
    weeks: weekNum.toString(),
    notes: '考试 ${exam.time}',
    displayTime: exam.time, // Use original time
  );
}
