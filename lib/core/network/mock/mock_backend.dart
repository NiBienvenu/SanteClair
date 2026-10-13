import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class MockResult {
  MockResult(this.data, {this.statusCode = 200});

  final dynamic data;
  final int statusCode;
}

class MockHttpError implements Exception {
  MockHttpError(this.statusCode, this.message, {this.errors});

  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;
}

typedef _Json = Map<String, dynamic>;

class _Request {
  _Request(this.params, this.query, this.body, this.headers);

  final List<String> params;
  final Map<String, dynamic> query;
  final _Json body;
  final Map<String, dynamic> headers;
}

class _Route {
  _Route(this.method, String pattern, this.handler)
    : regex = RegExp('^$pattern\$');

  final String method;
  final RegExp regex;
  final FutureOr<dynamic> Function(_Request r) handler;
}

/// Faux backend en mémoire, initialisé depuis `assets/mock/*.json`.
/// Les écritures (POST/PUT/PATCH/DELETE) modifient l'état en mémoire pour
/// que les lectures suivantes reflètent les changements.
class MockBackend {
  MockBackend() {
    _registerRoutes();
  }

  static const _files = [
    'auth_users',
    'referentials',
    'doctors',
    'doctor_slots',
    'patient_home',
    'appointments',
    'payment_methods',
    'profile',
    'medical_record',
    'doctor_dashboard',
    'doctor_availabilities',
  ];

  final Map<String, dynamic> _db = {};
  final List<_Route> _routes = [];
  Future<void>? _loading;
  int _seq = 100;

  Future<MockResult> handle({
    required String method,
    required String path,
    required Map<String, dynamic> query,
    required Object? body,
    required Map<String, dynamic> headers,
  }) async {
    await (_loading ??= _load());
    for (final route in _routes) {
      if (route.method != method.toUpperCase()) continue;
      final match = route.regex.firstMatch(path);
      if (match == null) continue;
      final params = [
        for (var i = 1; i <= match.groupCount; i++) match.group(i)!,
      ];
      final data = await route.handler(
        _Request(params, query, _normalizeBody(body), headers),
      );
      return data is MockResult ? data : MockResult(data);
    }
    throw MockHttpError(404, 'Ressource introuvable : $method $path');
  }

  Future<void> _load() async {
    for (final name in _files) {
      final raw = await rootBundle.loadString('assets/mock/$name.json');
      _db[name] = jsonDecode(raw);
    }
  }

  _Json _normalizeBody(Object? body) {
    if (body is Map) return Map<String, dynamic>.from(body);
    if (body is FormData) {
      return {
        for (final f in body.fields) f.key: f.value,
        for (final f in body.files) f.key: f.value.filename,
      };
    }
    if (body is String && body.isNotEmpty) {
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    }
    return {};
  }

  // ---------------------------------------------------------------- helpers

  List<dynamic> _list(String name) => _db[name] as List<dynamic>;
  _Json _obj(String name) => _db[name] as _Json;

  dynamic _copy(dynamic value) => jsonDecode(jsonEncode(value));

  String _nextId(String prefix) => '${prefix}_${_seq++}';

  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  _Json? _findById(List<dynamic> list, String id) {
    for (final item in list) {
      if (item is Map && item['id'] == id) return item as _Json;
    }
    return null;
  }

  _Json _currentUser(_Request r) {
    final auth = (r.headers['Authorization'] ?? '').toString();
    const prefix = 'Bearer mock-token-';
    if (!auth.startsWith(prefix)) {
      throw MockHttpError(401, 'Session expirée. Veuillez vous reconnecter.');
    }
    final id = auth.substring(prefix.length);
    for (final entry in _list('auth_users')) {
      final user = entry['user'] as _Json;
      if (user['id'] == id) return user;
    }
    throw MockHttpError(401, 'Session expirée. Veuillez vous reconnecter.');
  }

  _Json _authResponse(_Json user) => {
    'token': 'mock-token-${user['id']}',
    'user': _copy(user),
  };

  void _require(_Json body, List<String> fields) {
    final errors = <String, dynamic>{
      for (final f in fields)
        if (body[f] == null || body[f].toString().trim().isEmpty)
          f: 'Champ obligatoire',
    };
    if (errors.isNotEmpty) {
      throw MockHttpError(
        422,
        'Veuillez renseigner tous les champs obligatoires.',
        errors: errors,
      );
    }
  }

  _Json _doctorById(String id) {
    final doctor = _findById(_list('doctors'), id);
    if (doctor == null) throw MockHttpError(404, 'Médecin introuvable.');
    return doctor;
  }

  List<_Json> _appointmentsOf(String patientId) {
    final list = _list('appointments')
        .cast<_Json>()
        .where((a) => a['patientId'] == patientId)
        .toList();
    list.sort(
      (a, b) => '${a['date']} ${a['time']}'.compareTo('${b['date']} ${b['time']}'),
    );
    return list;
  }

  _Json _appointmentOf(_Request r) {
    final user = _currentUser(r);
    final apt = _findById(_list('appointments'), r.params[0]);
    if (apt == null || apt['patientId'] != user['id']) {
      throw MockHttpError(404, 'Rendez-vous introuvable.');
    }
    return apt;
  }

  int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  // ----------------------------------------------------------------- routes

  void _registerRoutes() {
    void on(String method, String pattern, FutureOr<dynamic> Function(_Request) h) =>
        _routes.add(_Route(method, pattern, h));

    // ------------------------------------------------------------ auth
    on('POST', '/auth/login', (r) {
      _require(r.body, ['identifier', 'password', 'role']);
      final identifier = r.body['identifier'].toString().trim().toLowerCase();
      final digits = _digits(identifier);
      _Json? match;
      for (final entry in _list('auth_users').cast<_Json>()) {
        final user = entry['user'] as _Json;
        final sameEmail = user['email'].toString().toLowerCase() == identifier;
        final samePhone =
            digits.length >= 8 && _digits(user['phone'].toString()) == digits;
        if ((sameEmail || samePhone) && entry['password'] == r.body['password']) {
          match = user;
          break;
        }
      }
      if (match == null) {
        throw MockHttpError(401, 'Identifiant ou mot de passe incorrect.');
      }
      if (match['role'] != r.body['role']) {
        throw MockHttpError(
          403,
          match['role'] == 'doctor'
              ? 'Ce compte est un compte praticien. Sélectionnez l\'onglet Médecin.'
              : 'Ce compte est un compte patient. Sélectionnez l\'onglet Patient.',
        );
      }
      if (match['accountStatus'] == 'pending_verification') {
        throw MockHttpError(
          403,
          'Votre compte praticien est en cours de vérification par nos équipes.',
        );
      }
      return _authResponse(match);
    });

    on('POST', '/auth/biometric', (r) {
      final role = r.body['role'] ?? 'patient';
      for (final entry in _list('auth_users').cast<_Json>()) {
        final user = entry['user'] as _Json;
        if (user['role'] == role && user['biometricEnabled'] == true) {
          return _authResponse(user);
        }
      }
      throw MockHttpError(401, 'Aucune empreinte enregistrée pour ce profil.');
    });

    on('POST', '/auth/forgot-password', (r) {
      _require(r.body, ['identifier']);
      return {
        'message':
            'Si un compte existe pour ${r.body['identifier']}, un lien de réinitialisation vient d\'être envoyé.',
      };
    });

    on('POST', '/auth/register/patient', (r) {
      _require(r.body, ['firstName', 'lastName', 'phone', 'email', 'password']);
      _ensureEmailFree(r.body['email'].toString());
      if (r.body['acceptTerms'] != true && r.body['acceptTerms'] != 'true') {
        throw MockHttpError(422, 'Vous devez accepter le traitement de vos données de santé.');
      }
      final user = <String, dynamic>{
        'id': _nextId('pat'),
        'role': 'patient',
        'firstName': r.body['firstName'],
        'lastName': r.body['lastName'],
        'email': r.body['email'],
        'phone': r.body['phone'],
        'bloodGroup': r.body['bloodGroup'],
        'verified': false,
        'biometricEnabled': false,
        'accountStatus': 'active',
      };
      _list('auth_users').add({'password': r.body['password'], 'user': user});
      return MockResult(_authResponse(user), statusCode: 201);
    });

    on('POST', '/auth/register/doctor', (r) {
      _require(r.body, [
        'fullName',
        'specialty',
        'licenseNumber',
        'phone',
        'email',
        'fee',
        'password',
        'professionalCard',
      ]);
      _ensureEmailFree(r.body['email'].toString());
      final names = r.body['fullName'].toString().replaceFirst(RegExp(r'^Dr\.?\s*'), '').split(' ');
      final user = <String, dynamic>{
        'id': _nextId('doc'),
        'role': 'doctor',
        'firstName': names.first,
        'lastName': names.skip(1).join(' '),
        'email': r.body['email'],
        'phone': r.body['phone'],
        'specialty': r.body['specialty'],
        'verified': false,
        'biometricEnabled': false,
        'accountStatus': 'pending_verification',
      };
      _list('auth_users').add({'password': r.body['password'], 'user': user});
      return MockResult({
        'status': 'pending_verification',
        'message':
            'Inscription reçue. Votre numéro ${r.body['licenseNumber']} et votre justificatif sont en cours de vérification (48 h ouvrées).',
      }, statusCode: 201);
    });

    on('GET', '/referentials', (r) => _copy(_obj('referentials')));

    // --------------------------------------------------------- patient
    on('GET', '/patient/home', (r) {
      final user = _currentUser(r);
      final home = _copy(_obj('patient_home')) as _Json;
      final upcoming = _appointmentsOf(user['id'] as String)
          .where((a) => const ['confirmed', 'payment_submitted'].contains(a['status']))
          .toList();
      home['firstName'] = user['firstName'];
      home['verified'] = user['verified'];
      home['nextAppointment'] = upcoming.isEmpty ? null : _copy(upcoming.first);
      home['recentDoctors'] = [
        for (final id in (home.remove('recentDoctorIds') as List)) _copy(_doctorById(id as String)),
      ];
      return home;
    });

    on('GET', '/doctors', (r) {
      final q = (r.query['q'] ?? '').toString().trim().toLowerCase();
      final specialty = r.query['specialty']?.toString();
      final teleconsultation = r.query['teleconsultation']?.toString() == 'true';
      return _list('doctors').cast<_Json>().where((d) {
        if (specialty != null && specialty.isNotEmpty && d['specialtyKey'] != specialty) {
          return false;
        }
        if (teleconsultation && d['teleconsultation'] != true) return false;
        if (q.isEmpty) return true;
        final haystack =
            '${d['firstName']} ${d['lastName']} ${d['specialty']} ${d['address']}'.toLowerCase();
        return haystack.contains(q);
      }).map(_copy).toList();
    });

    on('GET', r'/doctors/([\w-]+)', (r) => _copy(_doctorById(r.params[0])));

    on('GET', r'/doctors/([\w-]+)/slots', (r) {
      _doctorById(r.params[0]);
      final schedule = _copy(_obj('doctor_slots')) as _Json;
      final taken = {
        for (final a in _list('appointments').cast<_Json>())
          if ((a['doctor'] as _Json)['id'] == r.params[0] && a['status'] != 'cancelled')
            '${a['date']} ${a['time']}',
      };
      for (final day in (schedule['days'] as List).cast<_Json>()) {
        for (final period in ['morning', 'afternoon']) {
          for (final slot in (day[period] as List).cast<_Json>()) {
            if (taken.contains('${day['date']} ${slot['time']}')) slot['available'] = false;
          }
        }
      }
      return schedule;
    });

    on('GET', '/appointments', (r) {
      final user = _currentUser(r);
      return _appointmentsOf(user['id'] as String).map(_copy).toList();
    });

    on('POST', '/appointments', (r) {
      final user = _currentUser(r);
      _require(r.body, ['doctorId', 'reason', 'date', 'time', 'mode']);
      final doctor = _doctorById(r.body['doctorId'] as String);
      _ensureSlotFree(doctor['id'] as String, r.body['date'], r.body['time']);
      final apt = <String, dynamic>{
        'id': _nextId('apt'),
        'patientId': user['id'],
        'patientName': '${user['firstName']} ${user['lastName']}',
        'doctor': _copy(doctor),
        'date': r.body['date'],
        'time': r.body['time'],
        'mode': r.body['mode'],
        'location': r.body['mode'] == 'video' ? 'Téléconsultation' : doctor['address'],
        'reason': r.body['reason'],
        'status': 'pending_payment',
        'amount': doctor['fee'],
        'currency': doctor['currency'],
        'paymentMethod': null,
        'receiptName': null,
      };
      _list('appointments').add(apt);
      return MockResult(_copy(apt), statusCode: 201);
    });

    on('GET', r'/appointments/([\w-]+)', (r) => _copy(_appointmentOf(r)));

    on('PATCH', r'/appointments/([\w-]+)', (r) {
      final apt = _appointmentOf(r);
      final doctorId = (apt['doctor'] as _Json)['id'] as String;
      final date = r.body['date'] ?? apt['date'];
      final time = r.body['time'] ?? apt['time'];
      if (date != apt['date'] || time != apt['time']) {
        _ensureSlotFree(doctorId, date, time);
      }
      apt
        ..['date'] = date
        ..['time'] = time
        ..['reason'] = r.body['reason'] ?? apt['reason']
        ..['mode'] = r.body['mode'] ?? apt['mode'];
      apt['location'] = apt['mode'] == 'video'
          ? 'Téléconsultation'
          : (apt['doctor'] as _Json)['address'];
      return _copy(apt);
    });

    on('DELETE', r'/appointments/([\w-]+)', (r) {
      final apt = _appointmentOf(r);
      if (apt['status'] == 'pending_payment') {
        _list('appointments').remove(apt);
      } else {
        apt['status'] = 'cancelled';
      }
      return {'message': 'Rendez-vous annulé.'};
    });

    on('POST', r'/appointments/([\w-]+)/payment', (r) {
      final apt = _appointmentOf(r);
      _require(r.body, ['method', 'receipt']);
      apt
        ..['status'] = 'payment_submitted'
        ..['paymentMethod'] = r.body['method']
        ..['receiptName'] = r.body['receipt'];
      final doctor = apt['doctor'] as _Json;
      final dashboard = _obj('doctor_dashboard');
      if ((dashboard['doctor'] as _Json)['id'] == doctor['id']) {
        final now = DateTime.now();
        (dashboard['pendingPayments'] as List).add({
          'id': _nextId('pay'),
          'appointmentId': apt['id'],
          'patientName': apt['patientName'],
          'amount': apt['amount'],
          'currency': apt['currency'],
          'method': _paymentLabel(r.body['method'] as String),
          'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          'receiptName': r.body['receipt'],
        });
      }
      return _copy(apt);
    });

    on('GET', '/payment-methods', (r) => _copy(_list('payment_methods')));

    on('GET', '/profile', (r) {
      final user = _currentUser(r);
      final profile = _obj('profile');
      if (profile['id'] == user['id']) return _copy(profile);
      return {
        ..._copy(profile) as _Json,
        'id': user['id'],
        'firstName': user['firstName'],
        'lastName': user['lastName'],
        'email': user['email'],
        'phone': user['phone'],
        'verified': user['verified'],
        'birthDate': null,
        'socialSecurityNumber': null,
        'emergencyContact': null,
      };
    });

    on('PUT', '/profile', (r) {
      final user = _currentUser(r);
      final profile = _obj('profile');
      if (profile['id'] != user['id']) {
        throw MockHttpError(403, 'Modification indisponible pour ce compte de démonstration.');
      }
      for (final key in ['phone', 'email', 'birthDate', 'emergencyContact']) {
        if (r.body.containsKey(key)) profile[key] = r.body[key];
      }
      user
        ..['phone'] = profile['phone']
        ..['email'] = profile['email'];
      return _copy(profile);
    });

    on('GET', '/medical-record', (r) {
      final user = _currentUser(r);
      final record = _obj('medical_record');
      if (record['patientId'] == user['id']) return _copy(record);
      return {
        ..._copy(record) as _Json,
        'patientId': user['id'],
        'updatedAt': _today(),
        'bloodGroup': user['bloodGroup'],
        'allergies': <String>[],
        'activeTreatments': 0,
        'records': <dynamic>[],
        'consultations': <dynamic>[],
        'documents': <dynamic>[],
      };
    });

    on('POST', '/medical-record/documents', (r) {
      _currentUser(r);
      _require(r.body, ['file']);
      final doc = {
        'id': _nextId('docm'),
        'type': 'document',
        'title': r.body['file'],
        'date': _today(),
        'details': r.body['description'] ?? 'Document importé',
        'fileName': r.body['file'],
      };
      (_obj('medical_record')['documents'] as List).insert(0, doc);
      return MockResult(doc, statusCode: 201);
    });

    // ---------------------------------------------------------- doctor
    on('GET', '/doctor/dashboard', (r) {
      _currentUser(r);
      final dashboard = _copy(_obj('doctor_dashboard')) as _Json;
      final schedule = (dashboard['schedule'] as List).cast<_Json>();
      final active = schedule.where(
        (s) => s['type'] == 'appointment' && s['status'] != 'refused',
      );
      dashboard['stats'] = {
        'today': active.length,
        'toConfirm': active.where((s) => s['status'] == 'pending').length,
        'teleconsultations': active.where((s) => s['mode'] == 'video').length,
      };
      return dashboard;
    });

    on('PATCH', '/doctor/status', (r) {
      _require(r.body, ['status']);
      _obj('doctor_dashboard')['availabilityStatus'] = r.body['status'];
      return {'status': r.body['status']};
    });

    on('PATCH', r'/doctor/appointments/([\w-]+)', (r) {
      _require(r.body, ['action']);
      final item = _findById(_obj('doctor_dashboard')['schedule'] as List, r.params[0]);
      if (item == null) throw MockHttpError(404, 'Créneau introuvable.');
      const transitions = {
        'accept': 'confirmed',
        'refuse': 'refused',
        'block': 'blocked',
        'unblock': 'free',
      };
      final status = transitions[r.body['action']];
      if (status == null) throw MockHttpError(422, 'Action inconnue.');
      item['status'] = status;
      return _copy(item);
    });

    on('POST', r'/doctor/payments/([\w-]+)/validate', (r) {
      final dashboard = _obj('doctor_dashboard');
      final payments = dashboard['pendingPayments'] as List;
      final payment = _findById(payments, r.params[0]);
      if (payment == null) throw MockHttpError(404, 'Paiement introuvable.');
      payments.remove(payment);
      final apt = _findById(_list('appointments'), payment['appointmentId'] as String);
      if (apt != null) apt['status'] = 'confirmed';
      final slot = _findById(dashboard['schedule'] as List, payment['appointmentId'] as String);
      if (slot != null) slot['paid'] = true;
      return {'message': 'Paiement de ${payment['patientName']} validé.'};
    });

    on('GET', '/doctor/availabilities', (r) => _copy(_list('doctor_availabilities')));

    on('POST', '/doctor/availabilities', (r) {
      _require(r.body, ['days', 'start', 'end', 'slotDuration', 'location']);
      final days = (r.body['days'] as List).cast<String>();
      if (days.isEmpty) throw MockHttpError(422, 'Sélectionnez au moins un jour.');
      final start = _minutes(r.body['start'] as String);
      final end = _minutes(r.body['end'] as String);
      if (end <= start) {
        throw MockHttpError(422, 'L\'heure de fin doit être après l\'heure de début.');
      }
      var available = end - start;
      final lunch = Map<String, dynamic>.from(r.body['lunchBreak'] as Map? ?? {});
      if (lunch['enabled'] == true) {
        available -= _minutes(lunch['end'] as String) - _minutes(lunch['start'] as String);
      }
      final perDay = available ~/ (r.body['slotDuration'] as int);
      final availability = {
        'id': _nextId('av'),
        ...r.body,
        'slotsPerDay': perDay,
        'slotsPerWeek': perDay * days.length,
        'createdAt': _today(),
      };
      _list('doctor_availabilities').insert(0, availability);
      return MockResult(_copy(availability), statusCode: 201);
    });

    on('GET', '/doctor/patients', (r) {
      _currentUser(r);
      final schedule = (_obj('doctor_dashboard')['schedule'] as List).cast<_Json>();
      return [
        for (final s in schedule)
          if (s['type'] == 'appointment')
            {..._copy(s['patient']) as _Json, 'lastVisitTime': s['time'], 'mode': s['mode']},
      ];
    });
  }

  void _ensureEmailFree(String email) {
    for (final entry in _list('auth_users').cast<_Json>()) {
      if ((entry['user'] as _Json)['email'].toString().toLowerCase() == email.toLowerCase()) {
        throw MockHttpError(
          422,
          'Un compte existe déjà avec cet e-mail.',
          errors: {'email': 'Déjà utilisé'},
        );
      }
    }
  }

  void _ensureSlotFree(String doctorId, dynamic date, dynamic time) {
    for (final a in _list('appointments').cast<_Json>()) {
      if ((a['doctor'] as _Json)['id'] == doctorId &&
          a['date'] == date &&
          a['time'] == time &&
          a['status'] != 'cancelled') {
        throw MockHttpError(409, 'Ce créneau vient d\'être réservé. Choisissez un autre horaire.');
      }
    }
  }

  String _paymentLabel(String methodId) {
    for (final m in _list('payment_methods').cast<_Json>()) {
      if (m['id'] == methodId) return m['label'] as String;
    }
    return methodId;
  }
}
