import 'package:flutter/material.dart';

/// Associe les clés d'icône envoyées par l'API aux icônes Material.
IconData iconFor(String? key) => switch (key) {
  'heart' => Icons.favorite_border,
  'stethoscope' => Icons.medical_services_outlined,
  'tooth' => Icons.sentiment_satisfied_alt_outlined,
  'child' => Icons.child_care_outlined,
  'video' => Icons.videocam_outlined,
  'clipboard' => Icons.assignment_outlined,
  'person_add' => Icons.person_add_alt_1_outlined,
  'refresh' => Icons.autorenew,
  'emergency' => Icons.emergency_outlined,
  'hospital' => Icons.local_hospital_outlined,
  'swap' => Icons.swap_horiz,
  'wallet' => Icons.account_balance_wallet_outlined,
  'money' => Icons.payments_outlined,
  'phone' => Icons.phone_iphone,
  _ => Icons.circle_outlined,
};
