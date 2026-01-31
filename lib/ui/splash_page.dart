import 'package:flutter/material.dart';
import '../data/settings_controller.dart';
import '../data/cache_manager.dart';
import '../data/ucas_client.dart';
import '../data/login_helper.dart';
import 'home_shell.dart';
import 'login_page.dart';
import 'captcha_dialog.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _status = '正在启动...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    // 1. Check Login
    if (widget.settings.username.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LoginPage(settings: widget.settings)),
        );
      }
      return;
    }

    // 2. Auto Login & Pre-load
    try {
      setState(() => _status = '正在验证身份...');
      
      // Attempt login
      await LoginHelper().loginWithAutoOcr(
        widget.settings.username,
        widget.settings.password,
        onManualCaptchaNeeded: mounted ? (img) => showCaptchaDialog(context, img) : null,
      );

      setState(() {
        _status = '正在同步数据...';
        _progress = 0.2;
      });

      // 3. Fetch Data in Parallel
      final client = UcasClient();
      
      // We wrap fetches to handle errors individually so one failure doesn't stop others
      // and we can still enter the app.
      
      final fetchSchedule = client.fetchSchedule(
        widget.settings.username, 
        widget.settings.password
      ).then((val) {
        CacheManager().saveSchedule(val);
        return true;
      }).catchError((e) {
        debugPrint('Splash Schedule Error: $e');
        return false;
      });

      final fetchLectures = client.fetchLectures(
        widget.settings.username, 
        widget.settings.password
      ).then((val) {
        CacheManager().saveLectures(val);
        return true;
      }).catchError((e) {
        debugPrint('Splash Lectures Error: $e');
        return false;
      });

      final fetchExams = client.fetchExams(
        widget.settings.username, 
        widget.settings.password
      ).then((val) {
        CacheManager().saveExams(val);
        return true;
      }).catchError((e) {
        debugPrint('Splash Exams Error: $e');
        return false;
      });

      // Wait for all
      final results = await Future.wait([fetchSchedule, fetchLectures, fetchExams]);
      
      // If at least one succeeded, update timestamp
      if (results.any((success) => success)) {
        await CacheManager().saveLastUpdateTime();
      }

    } catch (e) {
      debugPrint('Splash Error: $e');
      // If login fails or crucial error, we usually still go to Home 
      // and let Dashboard show cached or empty state (or let it retry).
      // But if login failed (e.g. wrong password), Dashboard will handle re-login UI if needed?
      // Actually Dashboard will just retry or show error.
      // Better to proceed to HomeShell.
    } finally {
      if (mounted) {
        setState(() => _progress = 1.0);
        // Small delay to let user see "Done"
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => HomeShell(settings: widget.settings),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 600)
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_rounded,
                size: 60,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'UCAS 课程表',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 48),
            // Status & Loading
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _progress > 0 ? null : null, // Indeterminate until progress
                backgroundColor: Colors.grey[200],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
