import 'package:talker_flutter/talker_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/logger.dart';
import 'package:flutter/material.dart';

import '../data/settings_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_handleUpdate);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_handleUpdate);
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickTermStartDate() async {
    final current = widget.settings.termStartDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 2),
      lastDate: DateTime(current.year + 2),
    );
    if (selected != null) {
      widget.settings.updateTermStartDate(selected);
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '设置',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2A44),
          ),
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: '学期开始日期',
          subtitle: _formatDate(widget.settings.termStartDate),
          trailing: TextButton(
            onPressed: _pickTermStartDate,
            child: const Text('选择日期'),
          ),
        ),
        const SizedBox(height: 12),
        _StepperCard(
          title: '周次偏移',
          subtitle: '当前偏移：${widget.settings.weekOffset}',
          value: widget.settings.weekOffset,
          onChanged: widget.settings.updateWeekOffset,
        ),
        const SizedBox(height: 12),
        _StepperCard(
          title: '学期总周数',
          subtitle: '当前周数：${widget.settings.semesterLength}',
          value: widget.settings.semesterLength,
          minValue: 1,
          onChanged: widget.settings.updateSemesterLength,
        ),
        const SizedBox(height: 12),
        _SettingsTextField(
          title: '账号',
          value: widget.settings.username,
          onChanged: widget.settings.updateUsername,
        ),
        const SizedBox(height: 12),
        _SettingsTextField(
          title: '密码',
          value: widget.settings.password,
          obscureText: true,
          onChanged: widget.settings.updatePassword,
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          title: '关于',
          subtitle: 'TraintimePDA UCAS',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AboutPage()),
          ),
        ),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 20),
          const Center(
            child: Icon(Icons.train, size: 80, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'TraintimePDA UCAS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'v1.0.0',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('项目地址'),
            subtitle: const Text('github.com/wirsbf/traintime_pda_ucas'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => launchUrl(Uri.parse('https://github.com/wirsbf/traintime_pda_ucas')),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('作者'),
            subtitle: const Text('wirsbf'),
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: const Text('查看最新版本'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => launchUrl(Uri.parse('https://github.com/wirsbf/traintime_pda_ucas/releases')),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              '基于 TraintimePDA 项目\n感谢 BenderBlog 的开源贡献',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTextField extends StatefulWidget {
  const _SettingsTextField({
    required this.title,
    required this.value,
    required this.onChanged,
    this.obscureText = false,
  });

  final String title;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscureText;

  @override
  State<_SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<_SettingsTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SettingsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2A44),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              obscureText: widget.obscureText,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5EAF2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2A44),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _StepperCard extends StatelessWidget {
  const _StepperCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.minValue = -99,
    this.maxValue = 100,
  });

  final String title;
  final String subtitle;
  final int value;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2A44),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: value > minValue ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Text(
                value.toString(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: value < maxValue ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
