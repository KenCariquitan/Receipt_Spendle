import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final confirmPassC = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool loading = false;
  String? error;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _rememberMe = false;
  bool _isSignUpMode = false; // Toggle between login and signup

  @override
  void dispose() {
    emailC.dispose();
    passC.dispose();
    confirmPassC.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_validateForm()) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final resp = await Supabase.instance.client.auth.signInWithPassword(
        email: emailC.text.trim(),
        password: passC.text,
      );

      // Check if we got a session and token
      final session = resp.session;
      final user = resp.user;
      debugPrint("Supabase signIn response: user=${user?.id}");
      debugPrint("Access token: ${session?.accessToken}");

      if (session == null || session.accessToken.isEmpty) {
        throw Exception("Login failed: no session returned");
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_validateForm()) return;

    // Validate password confirmation
    if (passC.text != confirmPassC.text) {
      setState(() => error = 'Passwords do not match');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: emailC.text.trim(),
        password: passC.text,
      );

      // Check if user was created or if email already exists
      if (response.user == null) {
        throw Exception('Sign up failed. Please try again.');
      }

      // Check if email confirmation is required
      if (response.user!.identities == null ||
          response.user!.identities!.isEmpty) {
        // This typically means the email is already registered
        throw Exception(
            'An account with this email already exists. Please sign in instead.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Check your email to confirm.'),
            duration: Duration(seconds: 5),
          ),
        );
        // Switch back to login mode after successful signup
        setState(() {
          _isSignUpMode = false;
          confirmPassC.clear();
        });
      }
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _validateForm() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors to continue.')),
      );
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF050814),
              Color(0xFF111827),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      color: Colors.white.withOpacity(0.06),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF44E4FF),
                                Color(0xFFB151FF),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF44E4FF).withOpacity(0.45),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Spendle',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Track and manage your receipts with ease.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB0B6C8),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: emailC,
                                enabled: !loading,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(
                                  label: 'Email',
                                  hint: 'you@example.com',
                                  icon: Icons.email_outlined,
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  final emailRegex = RegExp(
                                      r'^[\w\.\-+]+@[a-zA-Z0-9\-]+\.[a-zA-Z]+$');
                                  if (!emailRegex.hasMatch(text)) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: passC,
                                enabled: !loading,
                                obscureText: !_isPasswordVisible,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(
                                  label: 'Password',
                                  hint: 'Enter your password',
                                  icon: Icons.lock_outline,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white70,
                                    ),
                                    onPressed: () => setState(
                                      () => _isPasswordVisible =
                                          !_isPasswordVisible,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              // Confirm password field (only in signup mode)
                              if (_isSignUpMode) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: confirmPassC,
                                  enabled: !loading,
                                  obscureText: !_isConfirmPasswordVisible,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                    label: 'Confirm Password',
                                    hint: 'Re-enter your password',
                                    icon: Icons.lock_outline,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isConfirmPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.white70,
                                      ),
                                      onPressed: () => setState(
                                        () => _isConfirmPasswordVisible =
                                            !_isConfirmPasswordVisible,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != passC.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 12),
                              // Remember me / Forgot password (only in login mode)
                              if (!_isSignUpMode)
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: loading
                                          ? null
                                          : (v) => setState(
                                              () => _rememberMe = v ?? false),
                                      side: const BorderSide(
                                        color: Color(0xFF4B5563),
                                      ),
                                      checkColor: Colors.black,
                                      activeColor:
                                          scheme.primary.withOpacity(0.9),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Remember me',
                                      style: TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: loading ? null : () {},
                                      child: const Text(
                                        'Forgot password?',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3FF),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (error != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  error!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: loading
                                      ? null
                                      : (_isSignUpMode ? _signUp : _signIn),
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    elevation: 0,
                                    backgroundColor: Colors.transparent,
                                  ),
                                  child: Ink(
                                    decoration: const BoxDecoration(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(26)),
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFF00E0FF),
                                          Color(0xFFB151FF),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: loading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                  Colors.white,
                                                ),
                                              ),
                                            )
                                          : Text(
                                              _isSignUpMode
                                                  ? 'Create Account'
                                                  : 'Login',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isSignUpMode
                                        ? "Already have an account? "
                                        : "Don't have an account? ",
                                    style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 13,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: loading
                                        ? null
                                        : () {
                                            setState(() {
                                              _isSignUpMode = !_isSignUpMode;
                                              error = null;
                                              confirmPassC.clear();
                                            });
                                          },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        _isSignUpMode ? 'Login' : 'Signup',
                                        style: const TextStyle(
                                          color: Color(0xFFBF5CFF),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF6B7280),
      ),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF1F2933),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF60A5FA),
          width: 1.3,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.3,
        ),
      ),
    );
  }
}
