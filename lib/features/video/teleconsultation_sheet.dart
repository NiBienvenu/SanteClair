import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/common.dart';
import '../../router/app_router.dart';
import 'video_repository.dart';

Future<void> showTeleconsultation(
  BuildContext context,
  String appointmentId, {
  String? phone,
  bool joinWhenAvailable = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _TeleconsultationSheet(
    appointmentId: appointmentId,
    phone: phone,
    joinWhenAvailable: joinWhenAvailable,
  ),
);

class _TeleconsultationSheet extends ConsumerStatefulWidget {
  const _TeleconsultationSheet({
    required this.appointmentId,
    this.phone,
    this.joinWhenAvailable = false,
  });
  final String appointmentId;
  final String? phone;
  final bool joinWhenAvailable;

  @override
  ConsumerState<_TeleconsultationSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_TeleconsultationSheet> {
  CallAccess? _access;
  String? _error;
  Timer? _timer;
  bool _loading = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final state = await ref
          .read(videoRepositoryProvider)
          .access(widget.appointmentId);
      final firstLoad = _access == null;
      if (mounted) {
        setState(() {
          _access = state;
          _error = null;
        });
        if (firstLoad && widget.joinWhenAvailable && state.canJoin) {
          await _join();
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      _loading = false;
    }
  }

  Future<void> _join({bool urgent = false}) async {
    if (_joining) return;
    setState(() => _joining = true);
    if (urgent) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          scrollable: true,
          title: const Text(
            'Appel urgent',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Un supplément de 10 000 FBU sera enregistré à régler au cabinet. '
            'Vous entrerez dans la salle vidéo ; la connexion dépend de la disponibilité du médecin.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'Annuler',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Accepter et rejoindre',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (accepted != true) {
        setState(() => _joining = false);
        return;
      }
    }
    if (!mounted) return;
    final router = GoRouter.of(context);
    Navigator.pop(context);
    await router.push(Routes.videoCall(widget.appointmentId, urgent: urgent));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _access;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Téléconsultation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (state == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Réessayer')),
            ],
            if (state != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Salle vidéo du rendez-vous'),
                subtitle: Text(
                  state.requiresConfirmation
                      ? 'Votre rendez-vous doit être confirmé par le médecin.'
                      : state.canJoin
                      ? 'Vous pouvez rejoindre la téléconsultation.'
                      : state.canJoinUrgent
                      ? 'L’accès habituel s’ouvre à l’heure du rendez-vous.'
                      : 'La période d’accès à cet appel est terminée.',
                ),
              ),
              if (state.canJoin)
                FilledButton.icon(
                  onPressed: _joining ? null : _join,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Rejoindre'),
                ),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Contacter le cabinet'),
              subtitle: SelectableText(
                widget.phone?.isNotEmpty == true
                    ? widget.phone!
                    : 'Consultez les coordonnées de votre médecin.',
              ),
            ),
            if (state == null || state.showUrgentJoin) ...[
              FilledButton.icon(
                onPressed:
                    _joining || state?.canJoinUrgent != true || _error != null
                    ? null
                    : () => _join(urgent: true),
                icon: const Icon(Icons.video_call),
                label: const Text('Rejoindre urgent (10 000 FBU)'),
              ),
              if (state?.requiresConfirmation == true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Disponible dès que le médecin aura confirmé votre rendez-vous.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
            if (state?.urgentCharge case final charge?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InfoBanner(
                  icon: Icons.payments_outlined,
                  text: charge['status'] == 'paid'
                      ? 'Supplément urgent : 10 000 FBU encaissés.'
                      : 'Supplément urgent : 10 000 FBU à régler au cabinet. Aucun prélèvement automatique.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
