import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import 'video_repository.dart';

/// Polls while the physician's authenticated space is open, including future urgent appointments.
class IncomingCallsBanner extends ConsumerWidget {
  const IncomingCallsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calls = ref.watch(incomingCallsProvider);
    return calls.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => SafeArea(
        bottom: false,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.sync_problem),
          title: const Text('Réception des appels interrompue'),
          trailing: TextButton(
            onPressed: () => ref.invalidate(incomingCallsProvider),
            child: const Text('Réessayer'),
          ),
        ),
      ),
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : SafeArea(
              bottom: false,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final call in list)
                        Material(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) => Row(
                                children: [
                                  const Icon(Icons.video_call),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${call.urgent ? 'Appel urgent' : 'Téléconsultation'} · ${call.patientName}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          call.amountDue > 0
                                              ? '${call.amountDue} FBU à encaisser au cabinet'
                                              : 'Le patient vous attend',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: (constraints.maxWidth * .34)
                                          .clamp(88.0, 160.0),
                                    ),
                                    child: FilledButton(
                                      // The shared button theme requests full width.
                                      // A call action must leave room for the patient's name.
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 44),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      onPressed: () => context.push(
                                        Routes.videoCall(
                                          call.appointmentId,
                                          doctor: true,
                                        ),
                                      ),
                                      child: const Text(
                                        'Rejoindre',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
