import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'score_page.dart';
import 'webview_page.dart';
import 'exam_page.dart';

class FunctionPage extends StatelessWidget {
  const FunctionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('功能'),
        centerTitle: true,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _FunctionCard(
             icon: Icons.score, 
             title: '成绩查询',
             color: Colors.blue.shade100,
             iconColor: Colors.blue,
             onTap: () {
               Navigator.of(context).push(
                 MaterialPageRoute(builder: (_) => const ScorePage()),
               );
             },
          ),
          _FunctionCard(
             icon: Icons.event_note, 
             title: '考试安排',
             color: Colors.purple.shade100,
             iconColor: Colors.purple,
             onTap: () {
               Navigator.of(context).push(
                 MaterialPageRoute(builder: (_) => const ExamPage()),
               );
             },
          ),
          _FunctionCard(
             icon: Icons.web, 
             title: '办事大厅',
             color: Colors.orange.shade100,
             iconColor: Colors.orange,
             onTap: () {
               Navigator.of(context).push(
                 MaterialPageRoute(
                   builder: (_) => const WebViewPage(
                     url: 'https://ehall.ucas.ac.cn/v2/site/index',
                     title: '办事大厅',
                   ),
                 ),
               );
             },
          ),
          _FunctionCard(
             icon: Icons.forum, 
             title: '果壳社区',
             color: Colors.green.shade100,
             iconColor: Colors.green,
             onTap: () {
               Navigator.of(context).push(
                 MaterialPageRoute(
                   builder: (_) => const WebViewPage(
                     url: 'https://gkder.ucas.ac.cn/',
                     title: '果壳社区',
                   ),
                 ),
               );
             },
          ),
        ],
      ),
    );
  }
}

class _FunctionCard extends StatelessWidget {
  const _FunctionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: iconColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
