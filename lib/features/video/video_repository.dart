import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../data/providers.dart';

class CallAccess {
  CallAccess.fromJson(Map<String, dynamic> json)
    : appointmentId = json['appointmentId'] as String,
      appId = (json['appId'] as num?)?.toInt() ?? 0,
      canJoin = json['canJoin'] == true,
      canJoinUrgent = json['canJoinUrgent'] == true,
      requiresConfirmation = json['requiresConfirmation'] == true,
      tokenAvailable = json['tokenAvailable'] == true,
      appSignAllowed = json['appSignAllowed'] == true,
      scheduledAt = DateTime.parse(json['scheduledAt'] as String),
      serverNow = DateTime.tryParse(json['serverNow'] as String? ?? ''),
      urgentCharge = json['urgentCharge'] as Map<String, dynamic>?;

  final String appointmentId;
  final int appId;
  final bool canJoin, canJoinUrgent, requiresConfirmation;
  final bool tokenAvailable, appSignAllowed;
  final DateTime scheduledAt;
  final DateTime? serverNow;
  final Map<String, dynamic>? urgentCharge;

  // Visibility is separate from permission to enter the room: a future
  // appointment awaiting confirmation still needs to explain the urgent option.
  bool get showUrgentJoin =>
      canJoinUrgent ||
      (!canJoin &&
          requiresConfirmation &&
          (serverNow == null || scheduledAt.isAfter(serverNow!)));
}

class CallCredentials {
  CallCredentials.fromJson(Map<String, dynamic> json)
    : appointmentId = json['appointmentId'] as String,
      appId = json['appId'] as int,
      roomId = json['roomId'] as String,
      userId = json['userId'] as String,
      userName = json['userName'] as String,
      peerName = json['peerName'] as String,
      peerUserId = json['peerUserId'] as String,
      streamId = json['streamId'] as String,
      token = json['token'] as String?,
      expiresAt = DateTime.parse(json['expiresAt'] as String),
      validForSeconds = json['validForSeconds'] as int;

  final int appId;
  final int validForSeconds;
  final String appointmentId,
      roomId,
      userId,
      userName,
      peerName,
      peerUserId,
      streamId;
  final String? token;
  final DateTime expiresAt;
}

class IncomingCall {
  IncomingCall.fromJson(Map<String, dynamic> json)
    : appointmentId = json['appointmentId'] as String,
      patientName = json['patientName'] as String,
      urgent = json['urgent'] == true,
      amountDue = (json['amountDue'] as num?)?.toInt() ?? 0;

  final String appointmentId, patientName;
  final bool urgent;
  final int amountDue;
}

class VideoRepository {
  VideoRepository(this.api);
  final ApiClient api;

  Future<CallAccess> access(String id) async => CallAccess.fromJson(
    Map<String, dynamic>.from(await api.get('/appointments/$id/video') as Map),
  );

  Future<CallCredentials> join(
    String id, {
    required bool web,
    bool urgent = false,
  }) async => CallCredentials.fromJson(
    Map<String, dynamic>.from(
      await api.post(
        '/appointments/$id/video',
        data: {
          'platform': web ? 'web' : 'native',
          'urgent': urgent,
          'acceptUrgentFee': urgent,
        },
      ) as Map,
    ),
  );

  Future<void> presence(CallCredentials call, {bool leave = false}) async {
    await api.post(
      '/appointments/${call.appointmentId}/video/presence',
      data: {'roomId': call.roomId, 'action': leave ? 'leave' : 'heartbeat'},
    );
  }

  Future<List<IncomingCall>> incoming() async =>
      (await api.get('/doctor/incoming-calls') as List)
          .map(
            (e) => IncomingCall.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
}

final videoRepositoryProvider = Provider((ref) {
  ref.watch(authControllerProvider.select((s) => (s.user?.id, s.user?.role)));
  return VideoRepository(ref.watch(apiClientProvider));
});

final incomingCallsProvider = StreamProvider.autoDispose<List<IncomingCall>>((
  ref,
) {
  final repo = ref.watch(videoRepositoryProvider);
  final controller = StreamController<List<IncomingCall>>();
  var busy = false;
  Future<void> poll() async {
    if (busy || controller.isClosed) return;
    busy = true;
    try {
      final calls = await repo.incoming();
      if (!controller.isClosed) controller.add(calls);
    } catch (error, stack) {
      if (!controller.isClosed) controller.addError(error, stack);
    } finally {
      busy = false;
    }
  }

  final timer = Timer.periodic(const Duration(seconds: 5), (_) => poll());
  unawaited(poll());
  ref.onDispose(() {
    timer.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});
