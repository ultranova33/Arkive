import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

class AuthService extends ChangeNotifier with WidgetsBindingObserver {
  AuthService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final AuthService instance = AuthService._internal();

  factory AuthService() => instance;

  final LocalAuthentication _localAuthentication = LocalAuthentication();
  bool _isLocked = true;

  bool get isLocked => _isLocked;

  Future<bool> authenticateWithPasscode() async {
    try {
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Authenticate to unlock your Arkive vault.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      _setLocked(!authenticated);
      return authenticated;
    } on PlatformException {
      _setLocked(true);
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _setLocked(true);
    }
  }

  void _setLocked(bool locked) {
    if (_isLocked == locked) {
      return;
    }

    _isLocked = locked;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
