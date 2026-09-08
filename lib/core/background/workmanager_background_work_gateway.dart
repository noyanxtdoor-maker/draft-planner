import 'package:rmplanner/core/background/background_work_gateway.dart';
import 'package:rmplanner/core/notifications/notification_payload.dart';
import 'package:rmplanner/features/notifications/application/reminder_background_runtime.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void nextTransferBackgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    if (task == 'nt.reminder.snooze') {
      const keys = {'profile_id', 'source_kind', 'source_id', 'occurrence_id', 'generation', 'action_utc_ms'};
      if (input == null ||
          input.length != keys.length ||
          input.keys.any((key) => !keys.contains(key))) {
        return false;
      }
      final profile = input['profile_id'];
      final source = input['source_id'];
      final occurrence = input['occurrence_id'];
      final generation = input['generation'];
      final timestamp = input['action_utc_ms'];
      final kind = NotificationSourceKind.values.asNameMap()[input['source_kind']];
      if (profile is! String ||
          source is! String ||
          occurrence is! String ||
          generation is! int ||
          generation < 0 ||
          timestamp is! int ||
          (kind != NotificationSourceKind.calendarEvent &&
              kind != NotificationSourceKind.task)) {
        return false;
      }
      final intent = NotificationResponseIntent(profileId: profile, sourceKind: kind!,
        sourceId: source, occurrenceId: occurrence, generation: generation,
        action: NotificationResponseAction.snooze);
      if (NotificationPayloadCodec.tryDecode(
            NotificationPayloadCodec.encode(intent),
          ) ==
          null) {
        return false;
      }
      return runReminderRuntime(snooze: intent,
        actionAtUtc: DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true));
    }
    if (task == 'nt.reminder.recovery') {
      if (input != null && input.isNotEmpty) return false;
      return runReminderRuntime();
    }
    if (task != 'nt.reminder.delivery' ||
        input == null ||
        input.keys.any(
          (key) => key != 'stable_key' && key != 'scheduled_utc_ms',
        )) {
      return false;
    }
    final key = input['stable_key'];
    final timestamp = input['scheduled_utc_ms'];
    if (key is! String ||
        timestamp is! int ||
        !RegExp(r'^reminder:[A-Za-z0-9_.:-]{1,240}$').hasMatch(key)) {
      return false;
    }
    return runReminderRuntime(
      deliveryKey: key,
      scheduledAtUtc: DateTime.fromMillisecondsSinceEpoch(
        timestamp,
        isUtc: true,
      ),
    );
  });
}

final class WorkmanagerBackgroundWorkGateway implements BackgroundWorkGateway {
  const WorkmanagerBackgroundWorkGateway();

  Workmanager get _workmanager => Workmanager();

  @override
  Future<void> initialize() =>
      _workmanager.initialize(nextTransferBackgroundDispatcher);

  @override
  Future<void> enqueueUnique(BackgroundWorkSpec work) {
    work.validate();
    return _workmanager.registerOneOffTask(
      work.uniqueName,
      work.taskName,
      inputData: Map<String, dynamic>.from(work.inputData),
      initialDelay: work.initialDelay,
      tag: work.tag,
      constraints: Constraints(
        networkType: switch (work.constraints.network) {
          BackgroundNetworkConstraint.notRequired => NetworkType.notRequired,
          BackgroundNetworkConstraint.connected => NetworkType.connected,
          BackgroundNetworkConstraint.unmetered => NetworkType.unmetered,
        },
        requiresCharging: work.constraints.requiresCharging,
        requiresBatteryNotLow: work.constraints.requiresBatteryNotLow,
        requiresStorageNotLow: work.constraints.requiresStorageNotLow,
      ),
      existingWorkPolicy: switch (work.existingPolicy) {
        BackgroundExistingWorkPolicy.keep => ExistingWorkPolicy.keep,
        BackgroundExistingWorkPolicy.replace => ExistingWorkPolicy.replace,
      },
    );
  }

  @override
  Future<void> cancelUnique(String uniqueName) =>
      _workmanager.cancelByUniqueName(uniqueName);

  @override
  Future<BackgroundGatewayWorkState> inspect(String uniqueName) async {
    final info = await _workmanager.getWorkInfo(uniqueName);
    return info == null
        ? BackgroundGatewayWorkState.absent
        : BackgroundGatewayWorkState.scheduled;
  }
}
