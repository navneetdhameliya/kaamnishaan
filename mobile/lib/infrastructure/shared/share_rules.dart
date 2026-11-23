import '../services/session_service.dart';

/// Who may send proof outside the app (D-141): owners and managers always; technicians when the owner
/// turned on "Technicians can share" in Company settings (the same switch as for reports).
class ShareRules {
  const ShareRules._();

  static bool maySharePhotos(SessionService session) {
    final me = session.me.value;
    if (me == null) return false;
    if (me.role == 'owner' || me.role == 'manager') return true;
    return me.company?.settings.techniciansCanShare ?? false;
  }
}
