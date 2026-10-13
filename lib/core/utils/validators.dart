class Validators {
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? required(String? v, [String message = 'Champ obligatoire']) =>
      (v == null || v.trim().isEmpty) ? message : null;

  static String? email(String? v) {
    if (required(v) != null) return 'E-mail obligatoire';
    return _email.hasMatch(v!.trim()) ? null : 'E-mail invalide';
  }

  static String? phone(String? v) {
    if (required(v) != null) return 'Téléphone obligatoire';
    final digits = v!.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 8 ? null : 'Numéro invalide';
  }

  static String? emailOrPhone(String? v) {
    if (required(v) != null) return 'Identifiant obligatoire';
    return v!.contains('@') ? email(v) : phone(v);
  }

  static String? password(String? v) {
    if (required(v) != null) return 'Mot de passe obligatoire';
    if (v!.length < 8) return '8 caractères minimum';
    if (!RegExp(r'\d').hasMatch(v)) return 'Au moins 1 chiffre';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) return 'Au moins 1 symbole';
    return null;
  }

  static String? amount(String? v) {
    if (required(v) != null) return 'Tarif obligatoire';
    final n = int.tryParse(v!.replaceAll(RegExp(r'\D'), ''));
    return (n == null || n <= 0) ? 'Montant invalide' : null;
  }
}
