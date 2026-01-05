import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/settings_controller.dart';
import '../data/ucas_client.dart';
import '../model/exam.dart';
import '../data/cache_manager.dart';
import 'captcha_dialog.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  List<Exam>? _exams;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCache();
    _fetchExams();
  }

  Future<void> _loadCache() async {
    final cached = await CacheManager().getExams();
    if (mounted && cached.isNotEmpty) {
      setState(() => _exams = cached);
    }
  }

  Future<void> _fetchExams({String? captchaCode}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final settings = await SettingsController.load();
      if (settings.username.isEmpty || settings.password.isEmpty) {
        throw Exception('请先在设置中填写账号密码');
      }
      final exams = await UcasClient().fetchExams(settings.username, settings.password, captchaCode: captchaCode);
      
      // Sort exams: Future > Past > TBD
      // Within group: Date Ascending
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      exams.sort((a, b) {
        // Helper to get status
        // 0: Future (Not started or Today)
        // 1: Past (Finished)
        // 2: TBD
        
        int getStatus(Exam e) {
           if (e.time == '未安排' || e.time == '无考试信息' || e.time == '获取失败' || e.date.isEmpty) return 2;
           final d = DateTime.tryParse(e.date);
           if (d == null) return 2;
           final eDate = DateTime(d.year, d.month, d.day);
           
           if (eDate.isBefore(today)) return 1; // Past
           return 0; // Future (Today is considered Future/Active)
        }
        
        final statusA = getStatus(a);
        final statusB = getStatus(b);
        
        if (statusA != statusB) return statusA.compareTo(statusB);
        
        // Secondary sort: Date Ascending
        return a.date.compareTo(b.date);
      });

      setState(() {
        _exams = exams;
      });
      await CacheManager().saveExams(exams);
    } on CaptchaRequiredException catch (e) {
      if (mounted) {
        final code = await showCaptchaDialog(context, e.image);
        if (code != null) {
          if (mounted) setState(() => _loading = false);
          await _fetchExams(captchaCode: code);
          return;
        } else {
           if (mounted) setState(() { _error = '验证码已取消'; });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('考试安排'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchExams,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchExams,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_exams == null || _exams!.isEmpty) {
      return Center(
        child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             const Text('暂无考试安排'),
             const SizedBox(height: 16),
             ElevatedButton( onPressed: _fetchExams, child: const Text('刷新'))
           ]
        )
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _exams!.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _ExamCard(exam: _exams![index]);
      },
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam});

  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final isScheduled = exam.time != '未安排' && exam.time != '无考试信息' && exam.time != '获取失败';
    
    // Determine if finished
    bool isFinished = false;
    if (isScheduled && exam.date.isNotEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final d = DateTime.tryParse(exam.date);
      if (d != null) {
         final examDate = DateTime(d.year, d.month, d.day);
         if (examDate.isBefore(today)) {
            isFinished = true;
         }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isFinished ? Colors.grey.shade50 : Colors.white, // Slightly different bg for finished
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
           BoxShadow(
             color: Colors.black.withOpacity(0.02),
             blurRadius: 4,
             offset: const Offset(0, 2),
           ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Expanded(
                 child: Text(
                   exam.courseName,
                   style: TextStyle(
                     fontSize: 16,
                     fontWeight: FontWeight.bold,
                     color: isFinished ? Colors.grey : const Color(0xFF1F2A44),
                   ),
                 ),
               ),
               if (!isScheduled || isFinished)
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                   decoration: BoxDecoration(
                     color: Colors.grey.shade100,
                     borderRadius: BorderRadius.circular(4),
                   ),
                   child: Text(
                     !isScheduled ? (exam.time.isEmpty ? '未安排' : exam.time) : '已结束',
                     style: TextStyle(
                       fontSize: 12, 
                       color: Colors.grey.shade600,
                     ),
                   ),
                 ),
             ],
           ),
           if (isScheduled) ...[
             const SizedBox(height: 12),
             const Divider(height: 1),
             const SizedBox(height: 12),
             // Date and Time Row
             Row(
               children: [
                 _buildInfoItem(Icons.calendar_today, exam.date, size: 15),
                 const SizedBox(width: 24),
                 _buildInfoItem(Icons.access_time, exam.time, size: 15),
               ],
             ),
             const SizedBox(height: 8),
             // Location and Seat Row
             Row(
               children: [
                 Expanded(child: _buildInfoItem(Icons.location_on, exam.location, size: 15)),
                 if (exam.seat.isNotEmpty) ...[
                   const SizedBox(width: 16),
                   _buildInfoItem(Icons.chair, '${exam.seat}座', size: 15),
                 ],
               ],
             ),
           ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: Colors.blueGrey.shade400),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

  // _showCaptchaDialog removed
