import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/cache_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  String? _notice;
  String? _pendingVerificationEmail;

  final _auth = Supabase.instance.client.auth;

  UserModel? get user    => _user;
  bool get isLoading     => _isLoading;
  String? get error      => _error;
  String? get notice     => _notice;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  bool get isLoggedIn    => _user != null;

  static const _mobileRedirectUrl = 'studygen://login-callback/';

  String _verificationRedirectUrl() {
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return _mobileRedirectUrl;
  }

  bool _isExistingEmailResponse(AuthResponse res) {
    final identities = res.user?.identities;
    return res.session == null && identities != null && identities.isEmpty;
  }

  String _mapLoginError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Email atau password salah. Jika email pernah daftar lewat Google, silakan login dengan Google.';
    }
    if (msg.contains('email not confirmed') || msg.contains('not confirmed')) {
      return 'Email belum diverifikasi. Cek inbox lalu coba login lagi.';
    }
    return e.message;
  }

  String _mapEmailDeliveryError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit') || msg.contains('email rate limit exceeded')) {
      return 'Pengiriman email dibatasi sementara (rate limit). Coba lagi beberapa menit lagi.';
    }
    if (msg.contains('error sending confirmation email') ||
        msg.contains('unexpected_failure')) {
      return 'Supabase gagal mengirim email verifikasi. Cek konfigurasi Email/Auth di dashboard Supabase.';
    }
    return e.message;
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final safeEmail = email.trim().toLowerCase();
      final safePassword = password.trim();
      final res = await _auth.signInWithPassword(
        email: safeEmail,
        password: safePassword,
      );
      final sbUser = res.user;
      if (sbUser == null) {
        _error = 'Login gagal';
        notifyListeners();
        return false;
      }

      // Ambil status user terbaru dari Supabase untuk memastikan verifikasi email up-to-date.
      final freshUserRes = await _auth.getUser();
      final effectiveUser = freshUserRes.user ?? sbUser;

      final provider = effectiveUser.appMetadata['provider']?.toString();
      final isVerified = effectiveUser.emailConfirmedAt != null || provider == 'google';
      if (!isVerified) {
        _error = 'Email belum diverifikasi. Cek inbox kamu terlebih dahulu.';
        _notice = 'Belum menerima email? Gunakan kirim ulang verifikasi.';
        _pendingVerificationEmail = effectiveUser.email ?? safeEmail;
        await _auth.signOut();
        notifyListeners();
        return false;
      }

      _pendingVerificationEmail = null;
      await _saveSessionFromSupabase(effectiveUser);
      return true;
    } on AuthException catch (e) {
      _error = _mapLoginError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Login gagal: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _setLoading(true);
    try {
      final safeEmail = email.trim().toLowerCase();
      final safePassword = password.trim();
      final res = await _auth.signUp(
        email: safeEmail,
        password: safePassword,
        data: {'name': name},
        emailRedirectTo: _verificationRedirectUrl(),
      );

      if (_isExistingEmailResponse(res)) {
        _error =
            'Email sudah terdaftar. Jika sebelumnya menggunakan Google, silakan login dengan Google.';
        _pendingVerificationEmail = null;
        notifyListeners();
        return false;
      }

      if (res.session == null) {
        _notice = 'Akun berhasil dibuat. Silakan verifikasi email dulu sebelum login.';
        _pendingVerificationEmail = safeEmail;
        notifyListeners();
        return true;
      }

      if (res.user != null) {
        _pendingVerificationEmail = null;
        await _saveSessionFromSupabase(res.user!);
      }
      return true;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        _error =
            'Email sudah terdaftar. Jika sebelumnya menggunakan Google, silakan login dengan Google.';
      } else {
        _error = _mapEmailDeliveryError(e);
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Gagal mendaftar: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    try {
      final redirectUrl = kIsWeb
          ? Uri.base.origin
          : _mobileRedirectUrl;

      await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
      _notice = 'Melanjutkan login Google...';
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _mapEmailDeliveryError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Login Google gagal: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await StorageService().clearAll();
    await CacheService().clearAll();
    _user = null;
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final sbUser = _auth.currentUser;
    if (sbUser == null) return false;

    final provider = sbUser.appMetadata['provider']?.toString();
    final isVerified = sbUser.emailConfirmedAt != null || provider == 'google';
    if (!isVerified) return false;

    await _saveSessionFromSupabase(sbUser);
    return true;
  }

  Future<bool> resendVerificationEmail({String? email}) async {
    final target = (email ?? _pendingVerificationEmail ?? '').trim().toLowerCase();
    if (target.isEmpty) {
      _error = 'Email verifikasi tidak ditemukan.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      await _auth.resend(
        type: OtpType.signup,
        email: target,
        emailRedirectTo: _verificationRedirectUrl(),
      );
      _pendingVerificationEmail = target;
      _notice = 'Email verifikasi sudah dikirim ulang ke $target';
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Gagal kirim ulang verifikasi: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    final target = email.trim().toLowerCase();
    if (target.isEmpty) {
      _error = 'Isi email terlebih dahulu.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      await _auth.resetPasswordForEmail(
        target,
        redirectTo: _verificationRedirectUrl(),
      );
      _notice = 'Link reset password sudah dikirim ke $target';
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Gagal kirim reset password: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _saveSessionFromSupabase(User sbUser) async {
    final userName =
        (sbUser.userMetadata?['name'] ??
                sbUser.userMetadata?['full_name'] ??
                sbUser.email?.split('@').first ??
                'User')
            .toString();

    _user = UserModel(
      id: sbUser.id,
      name: userName,
      email: sbUser.email ?? '-',
    );

    final token = _auth.currentSession?.accessToken;
    if (token != null && token.isNotEmpty) {
      await StorageService().saveToken(token);
    }

    await StorageService().saveUser(
      id:    _user!.id,
      name:  _user!.name,
      email: _user!.email,
    );
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    if (val) {
      _error = null;
    }
    notifyListeners();
  }
}