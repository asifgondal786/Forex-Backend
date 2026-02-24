import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/widgets/app_background.dart';
import '../../services/api_service.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final ApiService _apiService = ApiService();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  firebase_auth.ConfirmationResult? _confirmationResult;
  Timer? _autoRefreshTimer;
  Timer? _emailCooldownTimer;
  int _emailCooldown = 0;
  bool _isSendingEmail = false;
  bool _isRefreshing = false;
  String? _verificationId;
  String? _errorMessage;
  String? _infoMessage;
  static const bool _enablePhoneVerification = bool.fromEnvironment(
    'ENABLE_PHONE_VERIFICATION',
    defaultValue: false,
  );

  firebase_auth.FirebaseAuth? get _auth {
    try {
      if (Firebase.apps.isEmpty) {
        return null;
      }
      return firebase_auth.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  firebase_auth.User? get _user => _auth?.currentUser;

  bool get _emailVerified => _user?.emailVerified ?? false;
  bool get _phoneVerified => (_user?.phoneNumber ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_auth != null) {
      _startAutoRefresh();
    } else {
      _errorMessage = 'Firebase authentication is unavailable in this build.';
    }
  }

  @override
  void dispose() {
    _apiService.dispose();
    _autoRefreshTimer?.cancel();
    _emailCooldownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refreshUser(silent: true),
    );
  }

  void _startEmailCooldown([int seconds = 60]) {
    _emailCooldownTimer?.cancel();
    setState(() => _emailCooldown = seconds);
    _emailCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_emailCooldown <= 1) {
        timer.cancel();
        setState(() => _emailCooldown = 0);
        return;
      }
      setState(() => _emailCooldown -= 1);
    });
  }

  Future<void> _refreshUser({bool silent = false}) async {
    if (_auth == null) {
      if (!silent && mounted) {
        setState(() {
          _errorMessage = 'Firebase authentication is unavailable.';
          _isRefreshing = false;
        });
      }
      return;
    }

    if (!silent) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
        _infoMessage = null;
      });
    }
    try {
      await _user?.reload();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() => _errorMessage = 'Failed to refresh status: $e');
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _sendEmailVerification() async {
    if (_isSendingEmail || _emailCooldown > 0) {
      return;
    }
    final user = _user;
    if (user == null || (user.email ?? '').isEmpty) {
      setState(() {
        _errorMessage = 'No signed-in email user found. Please sign in again.';
        _infoMessage = null;
      });
      return;
    }
    if (user.emailVerified) {
      setState(() {
        _errorMessage = null;
        _infoMessage = 'Email is already verified.';
      });
      return;
    }

    setState(() {
      _isSendingEmail = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final backendResponse = await _apiService.requestEmailVerification(
        email: user.email ?? '',
      );
      final backendMessage = (backendResponse['message'] as String?)?.trim();
      if (mounted) {
        setState(
          () => _infoMessage = backendMessage?.isNotEmpty == true
              ? backendMessage
              : 'Verification email sent to ${user.email}.',
        );
        _startEmailCooldown();
      }
      return;
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      if (errorText.contains('429') || errorText.contains('too many')) {
        if (mounted) {
          setState(
            () => _errorMessage =
                'Too many verification attempts. Please wait a few minutes and try again.',
          );
          _startEmailCooldown(120);
        }
        return;
      }
      if (kDebugMode) {
        debugPrint('Backend verification email failed, falling back: $e');
      }
    }

    try {
      await _sendVerificationEmailWithFallback(user);
      if (mounted) {
        setState(() => _infoMessage = 'Verification email sent to ${user.email}.');
        _startEmailCooldown();
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Failed to send email: ${_friendlyEmailError(e.code)}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to send email: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingEmail = false);
      }
    }
  }

  Future<void> _sendVerificationEmailWithFallback(firebase_auth.User user) async {
    final continueUrl = _resolveEmailContinueUrl();
    try {
      await user.sendEmailVerification(
        firebase_auth.ActionCodeSettings(
          url: continueUrl,
          handleCodeInApp: false,
        ),
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      final code = e.code.toLowerCase().trim();
      if (code == 'invalid-continue-uri' ||
          code == 'unauthorized-continue-uri' ||
          code == 'missing-continue-uri') {
        await user.sendEmailVerification();
        return;
      }
      rethrow;
    }
  }

  String _resolveEmailContinueUrl() {
    const fromDefine =
        String.fromEnvironment('APP_WEB_URL', defaultValue: '');
    String fromEnv = '';
    try {
      fromEnv = (dotenv.env['APP_WEB_URL'] ?? '').trim();
    } catch (_) {}
    final raw = fromDefine.trim().isNotEmpty ? fromDefine.trim() : fromEnv;
    if (raw.isNotEmpty) {
      final normalized = _normalizeBaseUrl(raw);
      if (!normalized.startsWith('https://') && !kDebugMode) {
        throw StateError('APP_WEB_URL must use HTTPS in production.');
      }
      return normalized;
    }
    throw StateError('APP_WEB_URL is not configured.');
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final normalized = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    return 'https://$normalized';
  }

  String _friendlyEmailError(String code) {
    switch (code.toLowerCase().trim()) {
      case 'too-many-requests':
        return 'too many requests. Please wait before retrying.';
      case 'network-request-failed':
        return 'network issue. Check internet and retry.';
      case 'invalid-email':
        return 'invalid email address.';
      case 'unauthorized-continue-uri':
      case 'invalid-continue-uri':
      case 'missing-continue-uri':
        return 'email action link configuration issue.';
      default:
        return code;
    }
  }

  Future<void> _showPhoneVerificationDialog() async {
    _phoneController.clear();
    _codeController.clear();
    _verificationId = null;
    _confirmationResult = null;

    String? dialogError;
    String? dialogInfo;
    bool sending = false;
    bool verifying = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void safeSetModal(VoidCallback fn) {
              if (!context.mounted) return;
              setModalState(fn);
            }

            Future<void> sendCode() async {
              final phone = _phoneController.text.trim();
              if (phone.isEmpty) {
                safeSetModal(
                  () => dialogError = 'Please enter your phone number.',
                );
                return;
              }
              safeSetModal(() {
                sending = true;
                dialogError = null;
                dialogInfo = null;
              });

              try {
                if (kIsWeb) {
                  final result = await _user?.linkWithPhoneNumber(phone);
                  if (result == null) {
                    safeSetModal(
                      () => dialogError = 'No signed-in user found.',
                    );
                  } else {
                    _confirmationResult = result;
                    safeSetModal(
                      () => dialogInfo = 'Code sent. Please enter it below.',
                    );
                  }
                } else {
                  final auth = _auth;
                  if (auth == null) {
                    safeSetModal(
                      () => dialogError = 'Firebase authentication is unavailable.',
                    );
                    return;
                  }
                  await auth.verifyPhoneNumber(
                    phoneNumber: phone,
                    verificationCompleted: (credential) async {
                      try {
                        await _user?.linkWithCredential(credential);
                        await _refreshUser(silent: true);
                        if (mounted) {
                          FocusScope.of(dialogContext).unfocus();
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (e) {
                        if (mounted) {
                          safeSetModal(
                            () => dialogError = 'Auto verification failed: $e',
                          );
                        }
                      }
                    },
                    verificationFailed: (e) {
                      safeSetModal(
                        () => dialogError = 'Phone verification failed: ${e.message}',
                      );
                    },
                    codeSent: (verificationId, forceResendingToken) {
                      safeSetModal(() {
                        _verificationId = verificationId;
                        dialogInfo = 'Code sent. Please enter it below.';
                      });
                    },
                    codeAutoRetrievalTimeout: (verificationId) {
                      safeSetModal(() => _verificationId = verificationId);
                    },
                  );
                }
              } on firebase_auth.FirebaseAuthException catch (e) {
                final code = e.code.toLowerCase().trim();
                if (code == 'operation-not-allowed') {
                  safeSetModal(
                    () => dialogError =
                        'Phone provider is disabled in Firebase. Enable Phone in Authentication > Sign-in method.',
                  );
                } else {
                  safeSetModal(
                    () => dialogError = 'Phone verification error: ${e.message ?? code}',
                  );
                }
              } catch (e) {
                safeSetModal(
                  () => dialogError = 'Phone verification error: $e',
                );
              } finally {
                safeSetModal(() => sending = false);
              }
            }

            Future<void> verifyCode() async {
              final code = _codeController.text.trim();
              if (code.isEmpty) {
                safeSetModal(() => dialogError = 'Enter the SMS code.');
                return;
              }

              safeSetModal(() {
                verifying = true;
                dialogError = null;
                dialogInfo = null;
              });

              try {
                if (kIsWeb) {
                  final confirmation = _confirmationResult;
                  if (confirmation == null) {
                    safeSetModal(
                      () => dialogError = 'Request a verification code first.',
                    );
                    return;
                  }
                  await confirmation.confirm(code);
                } else {
                  if (_verificationId == null) {
                    safeSetModal(
                      () => dialogError = 'Request a verification code first.',
                    );
                    return;
                  }
                  final credential = firebase_auth.PhoneAuthProvider.credential(
                    verificationId: _verificationId!,
                    smsCode: code,
                  );
                  await _user?.linkWithCredential(credential);
                }
                await _refreshUser(silent: true);
                if (mounted) {
                  FocusScope.of(dialogContext).unfocus();
                  Navigator.of(dialogContext).pop();
                }
              } catch (e) {
                safeSetModal(() => dialogError = 'Invalid code: $e');
              } finally {
                safeSetModal(() => verifying = false);
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              title: const Text(
                'Verify phone number',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width < 520 ? double.infinity : 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter your phone number in E.164 format (e.g., +1 555 0100).',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (dialogError != null)
                      _buildMessage(dialogError!, isError: true),
                    if (dialogInfo != null)
                      _buildMessage(dialogInfo!, isError: false),
                    _buildPhoneInput(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: sending ? null : sendCode,
                        child: sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Send Code'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCodeInput(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: verifying ? null : verifyCode,
                        child: verifying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Verify Code'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final userEmail = _user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 20 : 32),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  color: Colors.white.withValues(alpha: 0.05),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 24 : 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verify your account',
                          style: TextStyle(
                            fontSize: isMobile ? 22 : 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _enablePhoneVerification
                              ? 'Complete email and phone verification to continue.'
                              : 'Complete email verification to continue.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_errorMessage != null)
                          _buildMessage(_errorMessage!, isError: true),
                        if (_infoMessage != null)
                          _buildMessage(_infoMessage!, isError: false),

                        _buildStatusRow(
                          title: 'Email',
                          subtitle: userEmail.isEmpty ? 'No email' : userEmail,
                          isVerified: _emailVerified,
                        ),
                        const SizedBox(height: 12),
                        if (!_emailVerified) ...[
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton(
                                onPressed: (_emailCooldown > 0 || _isSendingEmail)
                                    ? null
                                    : _sendEmailVerification,
                                child: _isSendingEmail
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(
                                        _emailCooldown > 0
                                            ? 'Resend ${_emailCooldown}s'
                                            : 'Send Verification',
                                      ),
                              ),
                              OutlinedButton(
                                onPressed: _isRefreshing ? null : _refreshUser,
                                child: _isRefreshing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('I Verified'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Status refreshes automatically. Check your spam folder if needed.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 20),
                        ],

                        if (_enablePhoneVerification) ...[
                          _buildStatusRow(
                            title: 'Phone',
                            subtitle: _phoneVerified
                                ? (_user?.phoneNumber ?? '')
                                : 'Not verified',
                            isVerified: _phoneVerified,
                          ),
                          const SizedBox(height: 12),
                          if (!_phoneVerified) ...[
                            SizedBox(
                              width: isMobile ? double.infinity : 220,
                              child: ElevatedButton.icon(
                                onPressed: _showPhoneVerificationDialog,
                                icon: const Icon(Icons.sms),
                                label: const Text('Verify Phone'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              kIsWeb
                                  ? 'You will complete a reCAPTCHA before receiving the SMS.'
                                  : 'We will send an SMS code to verify your number.',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ] else ...[
                          Text(
                            'Phone verification is currently disabled for this project.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],

                        const SizedBox(height: 24),
                        Text(
                          'After verification, return to the app. It will unlock automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 400))
        .slideY(begin: 0.1);
  }

  Widget _buildStatusRow({
    required String title,
    required String subtitle,
    required bool isVerified,
  }) {
    final color = isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isVerified ? Icons.check_circle : Icons.warning_amber_rounded,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            isVerified ? 'Verified' : 'Pending',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: '+1 555 0100',
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: const Icon(Icons.phone, color: Color(0xFF3B82F6)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF3B82F6),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildCodeInput() {
    return TextField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'SMS code',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF3B82F6),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildMessage(String message, {required bool isError}) {
    final color = isError ? Colors.red : const Color(0xFF10B981);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
