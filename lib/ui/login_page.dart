import 'package:flutter/material.dart';
import '../data/settings_controller.dart';
import '../data/ucas_client.dart';
import 'home_shell.dart';
import 'widget/bouncing_button.dart';
import 'captcha_dialog.dart';

class LoginPage extends StatefulWidget {
  final SettingsController settings;
  const LoginPage({super.key, required this.settings});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill if exists (e.g. if user logged out but data persisted, though usually we clear)
    if (widget.settings.username.isNotEmpty) {
      _usernameController.text = widget.settings.username;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login({String? captchaCode}) async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入账号和密码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await UcasClient().login(username, password, captchaCode: captchaCode);
      
      // Save credentials
      widget.settings.updateUsername(username);
      widget.settings.updatePassword(password);

      // Navigate to Home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeShell(settings: widget.settings)),
        );
      }
    } on CaptchaRequiredException catch (e) {
      if (mounted) {
        final code = await showCaptchaDialog(context, e.image);
        if (code != null) {
           _login(captchaCode: code);
           return;
        } else {
           setState(() => _error = '验证码取消');
        }
      }
    } on AuthException catch (e) {
       setState(() => _error = e.message);
    } catch (e) {
       setState(() => _error = '登录失败: $e');
    } finally {
       if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo / Title
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.school, size: 60, color: Colors.indigo.shade600),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'UCAS 课程表',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '请使用 SEP 账号登录',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              // Inputs
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: '邮箱 / 账号',
                  hintText: 'user@mails.ucas.ac.cn',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onSubmitted: (_) => _login(),
              ),
              
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                       Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
                       const SizedBox(width: 8),
                       Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Login Button
              BouncingButton(
                onTap: _loading ? () {} : () => _login(),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: _loading ? Colors.indigo.shade300 : const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _loading 
                      ? const SizedBox(
                          width: 24, height: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text(
                          '登录',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Center(
                 child: Text(
                   'Technical Support: Traintime PDA Group',
                   style: TextStyle(fontSize: 10, color: Colors.grey),
                 ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
