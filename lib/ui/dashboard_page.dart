import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/settings_controller.dart';
import '../ui/widget/bouncing_button.dart';
import '../data/ucas_client.dart';
import '../model/schedule.dart';
import '../model/lecture.dart';
import '../model/exam.dart';
import 'schedule_page.dart';
import 'lecture_page.dart';
import '../util/schedule_utils.dart';
import 'captcha_dialog.dart';
import '../data/cache_manager.dart';
import 'lecture_detail_dialog.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Schedule? _schedule;
  List<Lecture>? _lectures;
  bool _loadingSchedule = false;
  bool _loadingLectures = false;
  List<Exam>? _exams;
  List<Course> _customCourses = [];
  String? _error;
  
  late AnimationController _animController;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fetchData();
    _animController.forward();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
       _fetchData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadCache() async {
    final cachedSchedule = await CacheManager().getSchedule();
    if (mounted && cachedSchedule != null) {
      setState(() => _schedule = cachedSchedule);
    }
    
    final cachedLectures = await CacheManager().getLectures();
    if (mounted && cachedLectures.isNotEmpty) {
      _processLectures(cachedLectures);
    }

    final cachedExams = await CacheManager().getExams();
    final cachedCustom = await CacheManager().getCustomCourses();
    if (mounted) {
       setState(() {
          _exams = cachedExams;
          _customCourses = cachedCustom;
       });
    }
  }

  Future<void> _fetchData({bool force = false}) async {
    // 1. Always Login Check
    try {
      await UcasClient().login(widget.settings.username, widget.settings.password);
    } on CaptchaRequiredException catch (e) {
       if (mounted) {
         final code = await showCaptchaDialog(context, e.image);
         if (code != null) {
            await UcasClient().login(widget.settings.username, widget.settings.password, captchaCode: code);
         } else {
            return; // Cancelled
         }
       }
    } catch (e) {
       debugPrint('Login failed: $e');
       // Continue if we have cache? But usually we stop or show error.
       // User asked for "Always Login".
    }

    // 2. Check 12h Cache
    if (!force) {
       final lastUpdate = await CacheManager().getLastUpdateTime();
       final now = DateTime.now().millisecondsSinceEpoch;
       if (now - lastUpdate < 12 * 3600 * 1000) {
          if (_schedule != null && _lectures != null) return;
       }
    }

    // 3. Fetch Data
    await _fetchSchedule();
    await _fetchExams(); // New
    await _fetchLectures();
    
    // Refresh custom courses from cache (in case they changed elsewhere)
    final custom = await CacheManager().getCustomCourses();
    if (mounted) {
       setState(() => _customCourses = custom);
       _processWithAddedStatus();
    }

    await CacheManager().saveLastUpdateTime();
  }

  Future<void> _fetchExams() async {
    try {
       final exams = await UcasClient().fetchExams(widget.settings.username, widget.settings.password);
       CacheManager().saveExams(exams);
       if (mounted) setState(() => _exams = exams);
    } catch (e) {
       debugPrint('Exam Fetch Error: $e');
    }
  }

  void _onRefresh() async {
    setState(() {
      _loadingSchedule = true;
      _loadingLectures = true;
    });
    
    // Force refresh means force fetch, but logic inside _fetchData(force: true) handles it.
    // But _onRefresh was calling _fetchSchedule directly.
    // Let's use _fetchData(force: true) for consistency or just call fetches?
    // User wants "Refresh" to always update.
    
    // Re-login just to be sure (though _fetchData does it, _onRefresh is manual).
    // Let's call _fetchData(force: true) to reuse logic?
    // But _fetchData reloads cache first which causes flicker maybe?
    // No, _fetchData sets state.
    // Let's keep _onRefresh explicit but reuse login if possible.
    
    // Actually simpler:
    await _fetchData(force: true);
  }

  Future<void> _fetchSchedule({String? captchaCode}) async {
    setState(() => _loadingSchedule = true);
    try {
      final schedule = await UcasClient().fetchSchedule(widget.settings.username, widget.settings.password, captchaCode: captchaCode);
      if (mounted) {
        setState(() => _schedule = schedule);
        CacheManager().saveSchedule(schedule);
      }
    } on CaptchaRequiredException catch (e) {
      if (mounted) {
        final code = await showCaptchaDialog(context, e.image);
        if (code != null) {
           if (mounted) setState(() => _loadingSchedule = false);
           await _fetchSchedule(captchaCode: code);
           return;
        }
      }
    } catch (e) {
      // Ignore errors for dashboard, just don't show data
      debugPrint('Schedule Fetch Error: $e');
    } finally {
      if (mounted) setState(() => _loadingSchedule = false);
    }
  }

  Future<void> _fetchLectures({String? captchaCode}) async {
    setState(() => _loadingLectures = true);
    try {
      final lectures = await UcasClient().fetchLectures(widget.settings.username, widget.settings.password, captchaCode: captchaCode);
      
      // Filter >= Today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final filtered = lectures.where((l) {
        if (l.date.isEmpty) return true;
        final d = DateTime.tryParse(l.date);
        if (d != null) {
          final lectureDate = DateTime(d.year, d.month, d.day);
          return !lectureDate.isBefore(today);
        }
        return true;
      }).toList();
      filtered.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        _processLectures(filtered);
        CacheManager().saveLectures(lectures); // Save raw or filtered? Saving lectures result (all) is better usually, but here filtered 
        // Logic check: fetchLectures returns full list. Filter happens here.
        // We should save full list from fetch? Yes.
        // But fetchLectures returns list.
      }
    } on CaptchaRequiredException catch (e) {
       if (mounted) {
        final code = await showCaptchaDialog(context, e.image);
        if (code != null) {
           if (mounted) setState(() => _loadingLectures = false);
           await _fetchLectures(captchaCode: code);
           return;
        }
      }
    } catch (e) {
       debugPrint('Lecture Fetch Error: $e');
    } finally {
      if (mounted) setState(() => _loadingLectures = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _buildAnimatedItem(
              0,
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    const Text('今日课程', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: _onRefresh, 
                      icon: const Icon(Icons.refresh, color: Colors.blue),
                      tooltip: '刷新',
                    ),
                 ],
              ),
            ),
            const SizedBox(height: 12),
            _buildAnimatedItem(
              1,
              BouncingButton(
                 onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SchedulePage(settings: widget.settings)),
                    );
                 },
                 child: _buildTodayCourses()
              )
            ),
            const SizedBox(height: 24),
             _buildAnimatedItem(
              2,
              BouncingButton( // Make entire header clickable
                onTap: () {
                   Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => LecturePage(settings: widget.settings)),
                   );
                },
                child: _buildSectionHeader('近期讲座'),
              ),
            ),
            const SizedBox(height: 12),
             _buildAnimatedItem(
              3,
              _buildLecturesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ],
    );
  }

  Widget _buildTodayCourses() {
    if (_loadingSchedule) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }
    if (_schedule == null) {
      return Container(
         width: double.infinity,
         padding: const EdgeInsets.all(24),
         decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
         child: const Center(child: Text('暂无课程数据，请点击“更多”去拉取')),
      );
    }

    // Filter courses for today
    final now = DateTime.now();
    final currentWeek = widget.settings.currentWeek();
    final weekday = now.weekday;

    final allCourses = <Course>[];
    if (_schedule != null) allCourses.addAll(_schedule!.courses);
    if (_exams != null) {
       for (final e in _exams!) {
          final c = examToCourse(e, widget.settings.termStartDate, widget.settings.weekOffset);
          if (c != null) allCourses.add(c);
       }
    }
    allCourses.addAll(_customCourses);

    final todayCourses = allCourses.where((c) {
      // Check week
      if (!courseMatchesWeek(c, currentWeek)) return false;
      // Check day (Course.day returns int)
      return c.day == weekday;
    }).toList();
    
    // Sort by session start (Safe Int Comparison)
    todayCourses.sort((a, b) {
       final startA = _parseTimeInt(a.timeSlot.startTime);
       final startB = _parseTimeInt(b.timeSlot.startTime);
       return startA.compareTo(startB);
    });

    if (todayCourses.isEmpty) {
       return BouncingButton(
           onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SchedulePage(settings: widget.settings)),
              );
           },
           child: Container(
             width: double.infinity,
             padding: const EdgeInsets.all(24),
             decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
             child: Column(
               children: [
                 Icon(Icons.weekend, size: 40, color: Colors.green.shade300),
                 const SizedBox(height: 8),
                 Text('今天没有课哦，好好休息吧~', style: TextStyle(color: Colors.green.shade700)),
               ],
             ),
           )
       );
    }

    return Column(
      children: todayCourses.map((course) {
         return BouncingButton(
           onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => SchedulePage(settings: widget.settings))
              ).then((_) async {
                 final cached = await CacheManager().getSchedule();
                 if (cached != null) setState(() => _schedule = cached);
              });
           },
           child: Card(
             margin: const EdgeInsets.only(bottom: 12),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             child: Padding(
               padding: const EdgeInsets.all(16),
               child: Row(
                 children: [
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: _getColor(course.name), shape: BoxShape.circle),
                     child: const Icon(Icons.class_, color: Colors.white, size: 20),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(course.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                         const SizedBox(height: 4),
                         Row(children:[
                            const Icon(Icons.access_time, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Builder(builder: (context) {
                                if (course.displayTime.isNotEmpty) {
                                  return Text(course.displayTime, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold));
                                }
                                int? start = int.tryParse(course.timeSlot.startTime.replaceAll(RegExp(r'[^0-9]'), ''));
                                int? end = int.tryParse(course.timeSlot.endTime.replaceAll(RegExp(r'[^0-9]'), ''));
                                String timeStr = '${course.timeSlot.startTime}-${course.timeSlot.endTime}';
                                if (start != null && end != null) {
                                   String realTime = getTimeStringFromSection(start, end);
                                   if (realTime.isNotEmpty) timeStr = realTime;
                                }
                                return Text(timeStr, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold));
                            }),
                         ]),
                         const SizedBox(height: 4),
                         Row(children:[
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(child: Text(course.classroom, style: const TextStyle(color: Colors.grey))),
                         ]),
                       ],
                     ),
                   )
                 ],
               ),
             ),
           ),
         );
      }).toList(),
    );
  }

  Color _getColor(String name) {
     final colors = [Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.red, Colors.indigo];
     return colors[name.hashCode.abs() % colors.length];
  }

  Widget _buildLecturesList() {
    if (_loadingLectures) {
       return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }
    if (_lectures == null || _lectures!.isEmpty) {
        return Container(
         width: double.infinity,
         padding: const EdgeInsets.all(24),
         decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
         child: const Center(child: Text('近期暂无讲座')),
      );
    }
    
    // Take top 3
    final display = _lectures!.take(3).toList();

    return Column(
      children: display.map((lecture) {
        return BouncingButton(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => LectureDetailDialog(
                lecture: lecture,
                settings: widget.settings,
              ),
            ).then((_) async {
               // Refresh custom courses and re-sort
               final custom = await CacheManager().getCustomCourses();
               if (mounted) {
                  setState(() => _customCourses = custom);
                  _processWithAddedStatus();
               }
            });
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lecture.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(children: [
                             const Icon(Icons.person, size: 14, color: Colors.grey),
                             const SizedBox(width: 4),
                             Expanded(child: Text(lecture.speaker, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                             Expanded(child: Text('${lecture.date} ${lecture.time.contains(' ') ? lecture.time.split(' ').last : ''}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ]),
                        ],
                      ),
                    ),
                    if (_customCourses.any((c) => c.id == 'L_${lecture.id}'))
                       Container(
                         margin: const EdgeInsets.only(left: 8),
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                         decoration: BoxDecoration(
                           color: Colors.blue.shade50,
                           borderRadius: BorderRadius.circular(4),
                           border: Border.all(color: Colors.blue.shade200),
                         ),
                         child: const Text('已添加', style: TextStyle(fontSize: 10, color: Colors.blue)),
                       )
                    else 
                       const Icon(Icons.chevron_right, color: Colors.grey),
                 ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Copied helper from schedule_page or use util
  // bool _courseMatchesWeek(Course course, int week) { ... } // Removed

  void _processLectures(List<Lecture> list) {
    // Re-filter just in case (e.g. cache loaded)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final filtered = list.where((l) {
        if (l.date.isEmpty) return true; 
        final d = DateTime.tryParse(l.date);
        if (d != null) {
          final lectureDate = DateTime(d.year, d.month, d.day);
          return !lectureDate.isBefore(today);
        }
        return true;
    }).toList();
    filtered.sort((a, b) => a.date.compareTo(b.date));
    setState(() => _lectures = filtered);
    _processWithAddedStatus();
  }

  void _processWithAddedStatus() {
     if (_lectures == null) return;
     // Get Added IDs from custom courses
     final addedIds = _customCourses
         .where((c) => c.id.startsWith('L_'))
         .map((c) => c.id.substring(2))
         .toSet();
     
     _lectures!.sort((a, b) {
        final aAdded = addedIds.contains(a.id);
        final bAdded = addedIds.contains(b.id);
        if (aAdded && !bAdded) return -1;
        if (!aAdded && bAdded) return 1;
        return a.date.compareTo(b.date);
     });
     // Force rebuild if this runs after set state
  }
  int _parseTimeInt(String timeStr) {
     final clean = timeStr.replaceAll(RegExp(r'[^0-9:]'), ''); 
     if (clean.contains(':')) {
        final parts = clean.split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return h * 60 + m;
     }
     return int.tryParse(clean) ?? 0;
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(index * 0.2, 1.0, curve: Curves.easeOutQuad),
        ),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Interval(index * 0.2, 1.0, curve: Curves.easeOutQuad),
          ),
        ),
        child: child,
      ),
    );
  }
}
