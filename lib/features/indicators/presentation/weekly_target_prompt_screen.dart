import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/settings/application/start_of_week_providers.dart';

final class WeeklyTargetPromptScreen extends ConsumerWidget {
  const WeeklyTargetPromptScreen({
    required this.periodStart,
    this.indicatorKey,
    super.key,
  });

  final PlannerDate periodStart;
  final String? indicatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (indicatorKey != null) {
      return _GoalEditorScreen(
        indicatorKey: indicatorKey!,
        periodStart: periodStart,
      );
    }
    final period = IndicatorPeriod(
      start: periodStart,
      end: periodStart.addDays(6),
    );
    final snapshot = ref.watch(indicatorPeriodSnapshotProvider(period));
    return Scaffold(
      appBar: InternalAppBar(title: const Text('Weekly Targets')),
      body: SafeArea(
        child: snapshot.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Weekly targets could not be opened. No data was changed.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (value) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              Text(
                '${period.start.iso8601} — ${period.end.iso8601}',
                style: AppTypography.body,
              ),
              const SizedBox(height: 8),
              const Text(
                'Targets are optional. Not set and explicit zero are '
                'different. Actual is read-only and never changed here.',
              ),
              const SizedBox(height: 18),
              for (final indicator in value.indicators.where(
                (indicator) =>
                    indicatorKey == null || indicator.key == indicatorKey,
              ))
                Card(
                  child: ListTile(
                    key: Key('target-${indicator.key}'),
                    title: Text(indicator.label),
                    subtitle: Text('Target: ${indicator.target.display}'),
                    trailing: Wrap(
                      spacing: 4,
                      children: <Widget>[
                        IconButton(
                          key: Key('target-history-${indicator.key}'),
                          tooltip: 'Target revision history',
                          onPressed: () =>
                              _showHistory(context, ref, indicator, period),
                          icon: const Icon(Icons.history),
                        ),
                        const Icon(Icons.edit_outlined),
                      ],
                    ),
                    onTap: () => _edit(context, ref, indicator, period),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    LifeIndicatorSummary indicator,
    IndicatorPeriod period,
  ) async {
    final controller = TextEditingController(
      text: indicator.target.value?.display ?? '',
    );
    final result = await showDialog<_TargetChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${indicator.label} target'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const Key('weekly-target-value-field'),
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target (${indicator.unit})',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(const _TargetChoice.clear()),
            child: const Text('Set Not set'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_TargetChoice.value(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) {
      return;
    }
    IndicatorAmount? value;
    if (!result.clear) {
      final parsed = _parseTarget(result.rawValue!, indicator.unit);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid non-negative target.')),
        );
        return;
      }
      value = IndicatorAmount(
        scaledValue: parsed.scaledValue,
        scale: parsed.scale,
        unit: parsed.unit,
      );
    }
    try {
      await ref
          .read(homeIndicatorControllerProvider.notifier)
          .setTarget(indicatorKey: indicator.key, period: period, value: value);
      ref.invalidate(indicatorPeriodSnapshotProvider(period));
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Target was not changed. Reviewed weeks are read-only.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showHistory(
    BuildContext context,
    WidgetRef ref,
    LifeIndicatorSummary indicator,
    IndicatorPeriod period,
  ) async {
    final revisions = await ref
        .read(homeIndicatorControllerProvider.notifier)
        .readTargetHistory(
          indicatorKey: indicator.key,
          periodStart: period.start,
        );
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${indicator.label} target history'),
        content: revisions.isEmpty
            ? const Text('No target revisions for this week.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: revisions.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final revision = revisions[index];
                    return ListTile(
                      title: Text('Target ${revision.target.display}'),
                      subtitle: Text(revision.createdAtUtc.toIso8601String()),
                    );
                  },
                ),
              ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IndicatorAmount? _parseTarget(String raw, String unit) {
    final text = raw.trim();
    final allowedScale = unit == 'hours' ? 2 : 0;
    final match = RegExp(r'^([0-9]+)(?:\.([0-9]+))?$').firstMatch(text);
    if (match == null) {
      return null;
    }
    final decimals = match.group(2) ?? '';
    if (decimals.length > allowedScale) {
      return null;
    }
    try {
      var power = 1;
      for (var i = 0; i < allowedScale; i += 1) {
        power *= 10;
      }
      final scaled =
          int.parse(match.group(1)!) * power +
          (allowedScale == 0
              ? 0
              : int.parse(decimals.padRight(allowedScale, '0')));
      if (scaled > 9223372036854775807) {
        return null;
      }
      return IndicatorAmount(
        scaledValue: scaled,
        scale: allowedScale,
        unit: unit,
      );
    } on FormatException {
      return null;
    }
  }
}

final class _TargetChoice {
  const _TargetChoice.value(this.rawValue) : clear = false;
  const _TargetChoice.clear() : rawValue = null, clear = true;

  final String? rawValue;
  final bool clear;
}

final class _GoalEditorScreen extends ConsumerStatefulWidget {
  const _GoalEditorScreen({
    required this.indicatorKey,
    required this.periodStart,
  });

  final String indicatorKey;
  final PlannerDate periodStart;

  @override
  ConsumerState<_GoalEditorScreen> createState() => _GoalEditorScreenState();
}

final class _GoalEditorScreenState extends ConsumerState<_GoalEditorScreen>
    with WidgetsBindingObserver {
  late IndicatorGoalPeriodType _periodType;
  PlannerDate _anchor = const PlannerDate(year: 2026, month: 1, day: 1);
  IndicatorGoalSnapshot? _snapshot;
  List<IndicatorGoalSnapshot> _history = const <IndicatorGoalSnapshot>[];
  String _label = '';
  bool _loading = true;
  bool _targetSet = false;
  int _target = 0;
  bool _disposed = false;
  int _reloadToken = 0;
  Timer? _saveTimer;
  _PendingGoalSave? _pendingSave;

  bool get _hasDaily => widget.indicatorKey == 'job_applications';
  bool get _hasMonthly => widget.indicatorKey == 'temple_visit';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _anchor = widget.periodStart;
    _periodType = IndicatorGoalPeriodType.weekly;
    unawaited(_reload());
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_flushPending());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_flushPending());
    }
  }

  IndicatorGoalPeriod get _period {
    return switch (_periodType) {
      IndicatorGoalPeriodType.daily => IndicatorGoalPeriod.daily(_anchor),
      IndicatorGoalPeriodType.weekly => IndicatorGoalPeriod.weekly(
        _anchor,
        startDay: ref.read(startOfWeekProvider),
      ),
      IndicatorGoalPeriodType.monthly => IndicatorGoalPeriod.monthly(_anchor),
    };
  }

  Future<void> _reload() async {
    final token = ++_reloadToken;
    if (_disposed) {
      return;
    }
    setState(() => _loading = true);
    try {
      final controller = ref.read(homeIndicatorControllerProvider.notifier);
      final week = IndicatorGoalPeriod.weekly(
        _anchor,
        startDay: ref.read(startOfWeekProvider),
      );
      final home = await ref.read(
        indicatorPeriodSnapshotProvider(week.indicatorPeriod).future,
      );
      final snapshot = await controller.readGoal(
        indicatorKey: widget.indicatorKey,
        period: _period,
      );
      final history = await controller.readGoalHistory(
        indicatorKey: widget.indicatorKey,
        periodType: _periodType,
        anchor: _anchor,
      );
      if (!mounted || _disposed || token != _reloadToken) {
        return;
      }
      final definition = home.indicators.where(
        (item) => item.key == widget.indicatorKey,
      );
      setState(() {
        _label = definition.isEmpty
            ? widget.indicatorKey
            : definition.first.label;
        _snapshot = snapshot;
        _history = history;
        _targetSet = snapshot.target.isSet;
        _target = snapshot.target.value?.scaledValue ?? 0;
        _loading = false;
      });
    } on Object {
      if (mounted && !_disposed && token == _reloadToken) {
        setState(() => _loading = false);
      }
    }
  }

  void _selectPeriod(IndicatorGoalPeriodType type) {
    if (_periodType == type) {
      return;
    }
    unawaited(_changePeriod(type));
  }

  Future<void> _changePeriod(IndicatorGoalPeriodType type) async {
    await _flushPending();
    if (!mounted || _disposed) {
      return;
    }
    setState(() => _periodType = type);
    await _reload();
  }

  void _movePeriod(int delta) {
    final next = switch (_periodType) {
      IndicatorGoalPeriodType.daily => _anchor.addDays(delta),
      IndicatorGoalPeriodType.weekly => _anchor.addDays(delta * 7),
      IndicatorGoalPeriodType.monthly => _addMonths(_anchor, delta),
    };
    unawaited(_moveTo(next));
  }

  Future<void> _moveTo(PlannerDate next) async {
    await _flushPending();
    if (!mounted || _disposed) {
      return;
    }
    setState(() => _anchor = next);
    await _reload();
  }

  void _queueSave() {
    final snapshot = _snapshot;
    if (_loading || snapshot == null || _disposed) {
      return;
    }
    _pendingSave = _PendingGoalSave(
      period: _period,
      value: _targetSet
          ? IndicatorAmount(
              scaledValue: _target,
              scale: 0,
              unit: snapshot.actual.unit,
            )
          : null,
    );
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 200), () {
      _saveTimer = null;
      unawaited(_flushPending());
    });
  }

  Future<void> _flushPending() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final pending = _pendingSave;
    _pendingSave = null;
    if (pending == null) {
      return;
    }
    try {
      await ref
          .read(homeIndicatorControllerProvider.notifier)
          .saveGoal(
            indicatorKey: widget.indicatorKey,
            period: pending.period,
            value: pending.value,
          );
      ref.invalidate(
        indicatorPeriodSnapshotProvider(pending.period.indicatorPeriod),
      );
    } on Object {
      if (mounted && !_disposed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Goal was not changed.')));
      }
    }
    if (_pendingSave != null) {
      await _flushPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodLabel = _formatPeriod(context, _period);
    final today = ref.read(plannerDateSourceProvider).today();
    final maxForward = _periodType == IndicatorGoalPeriodType.daily
        ? today
        : _periodType == IndicatorGoalPeriodType.monthly
        ? IndicatorGoalPeriod.monthly(today).start
        : IndicatorGoalPeriod.weekly(
            today,
            startDay: ref.read(startOfWeekProvider),
          ).start;
    final canGoNext = _period.start.compareTo(maxForward) < 0;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_flushAndPop());
        }
      },
      child: Scaffold(
        appBar: InternalAppBar(title: const Text('Edit Goal')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewPaddingOf(context).bottom + 96,
                  ),
                  children: <Widget>[
                    if (_hasDaily || _hasMonthly)
                      _PeriodTabs(
                        periodType: _periodType,
                        hasDaily: _hasDaily,
                        hasMonthly: _hasMonthly,
                        onSelected: _selectPeriod,
                      ),
                    _GoalPeriodNavigation(
                      label: periodLabel,
                      canGoNext: canGoNext,
                      onPrevious: () => _movePeriod(-1),
                      onNext: canGoNext ? () => _movePeriod(1) : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                      child: Text(
                        _label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 28 / 22,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _GoalControls(
                      target: _target,
                      targetSet: _targetSet,
                      icon: _iconForGoal(widget.indicatorKey),
                      onMinus: _targetSet && _target > 0
                          ? () => setState(() {
                              _target -= 1;
                              _queueSave();
                            })
                          : null,
                      onPlus: () => setState(() {
                        _targetSet = true;
                        _target += 1;
                        _queueSave();
                      }),
                    ),
                    const SizedBox(height: 28),
                    const _MajorSeparator(),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 24, 18, 8),
                      child: Text('History', style: AppTypography.sectionTitle),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Divider(height: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      child: _GoalHistoryChart(history: _history),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _flushAndPop() async {
    await _flushPending();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

final class _PendingGoalSave {
  const _PendingGoalSave({required this.period, required this.value});

  final IndicatorGoalPeriod period;
  final IndicatorAmount? value;
}

final class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({
    required this.periodType,
    required this.hasDaily,
    required this.hasMonthly,
    required this.onSelected,
  });

  final IndicatorGoalPeriodType periodType;
  final bool hasDaily;
  final bool hasMonthly;
  final ValueChanged<IndicatorGoalPeriodType> onSelected;

  @override
  Widget build(BuildContext context) {
    final types = <IndicatorGoalPeriodType>[
      if (hasDaily) IndicatorGoalPeriodType.daily,
      IndicatorGoalPeriodType.weekly,
      if (hasMonthly) IndicatorGoalPeriodType.monthly,
    ];
    return SizedBox(
      height: 56,
      child: Row(
        children: <Widget>[
          for (final type in types)
            Expanded(
              child: InkWell(
                key: Key('goal-period-${type.name}'),
                onTap: () => onSelected(type),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _periodTypeLabel(type),
                        style: AppTypography.button,
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 44,
                      height: 3,
                      decoration: BoxDecoration(
                        color: periodType == type
                            ? AppTheme.rose
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _GoalPeriodNavigation extends StatelessWidget {
  const _GoalPeriodNavigation({
    required this.label,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.calendar_month_outlined,
              color: AppTheme.rose,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTypography.body)),
            IconButton(
              onPressed: onPrevious,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.chevron_left, size: 28),
            ),
            IconButton(
              onPressed: onNext,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.chevron_right,
                size: 28,
                color: canGoNext ? null : Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _GoalControls extends StatelessWidget {
  const _GoalControls({
    required this.target,
    required this.targetSet,
    required this.icon,
    required this.onMinus,
    required this.onPlus,
  });

  final int target;
  final bool targetSet;
  final IconData icon;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 140,
                height: 52,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Goal',
                    labelStyle: AppTypography.micro.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                    floatingLabelStyle: AppTypography.micro.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(icon, size: 24, color: Colors.white70),
                      const SizedBox(width: 10),
                      Text(
                        targetSet ? '$target' : '—',
                        style: const TextStyle(
                          fontSize: 24,
                          height: 26 / 24,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _RoundGoalButton(
                key: const Key('goal-minus'),
                icon: Icons.remove,
                onPressed: onMinus,
                filled: false,
              ),
              const SizedBox(width: 8),
              _RoundGoalButton(
                key: const Key('goal-plus'),
                icon: Icons.add,
                onPressed: onPlus,
                filled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _RoundGoalButton extends StatelessWidget {
  const _RoundGoalButton({
    required this.icon,
    required this.onPressed,
    required this.filled,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: Material(
        color: filled ? AppTheme.rose : Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(
            color: filled ? Colors.transparent : AppTheme.outline,
          ),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
          color: filled ? const Color(0xFF400018) : Colors.white70,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

final class _MajorSeparator extends StatelessWidget {
  const _MajorSeparator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 8,
      width: double.infinity,
      child: ColoredBox(color: Color(0xFF4A4E50)),
    );
  }
}

final class _GoalHistoryChart extends StatelessWidget {
  const _GoalHistoryChart({required this.history});

  final List<IndicatorGoalSnapshot> history;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 236,
      width: double.infinity,
      child: CustomPaint(painter: _GoalHistoryPainter(history)),
    );
  }
}

final class _GoalHistoryPainter extends CustomPainter {
  const _GoalHistoryPainter(this.history);

  final List<IndicatorGoalSnapshot> history;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) {
      return;
    }
    final maxValue = history.fold<int>(1, (value, item) {
      return math.max(
        value,
        math.max(item.actual.scaledValue, item.target.value?.scaledValue ?? 0),
      );
    });
    final left = 20.0;
    final right = size.width - 10;
    final top = 12.0;
    final bottom = size.height - 38;
    final chartHeight = bottom - top;
    final step = history.length == 1
        ? 0.0
        : (right - left) / (history.length - 1);
    final baseline = Paint()
      ..color = AppTheme.outline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), baseline);
    final targetPaint = Paint()..color = const Color(0xFF3D4144);
    final linePaint = Paint()
      ..color = const Color(0xFFF1C94F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final pointFill = Paint()..color = AppTheme.background;
    final pointStroke = Paint()
      ..color = const Color(0xFFF1C94F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path();
    for (var index = 0; index < history.length; index += 1) {
      final item = history[index];
      final x = left + step * index;
      final target = item.target.value?.scaledValue ?? 0;
      final actual = item.actual.scaledValue;
      final targetHeight = chartHeight * target / maxValue;
      final actualY = bottom - chartHeight * actual / maxValue;
      if (target > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x - 12, bottom - targetHeight, 24, targetHeight),
          targetPaint,
        );
      }
      final point = Offset(x, actualY);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(point, 8, pointFill);
      canvas.drawCircle(point, 8, pointStroke);
      _drawText(
        canvas,
        item.actual.display,
        Offset(x, math.max(top, actualY - 24)),
        const TextStyle(fontSize: 12, color: Color(0xFFF1C94F)),
        alignCenter: true,
      );
      _drawText(
        canvas,
        _historyLabel(item.period),
        Offset(x, bottom + 10),
        const TextStyle(fontSize: 12, color: Colors.white70),
        alignCenter: true,
      );
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _GoalHistoryPainter oldDelegate) {
    return oldDelegate.history != history;
  }
}

void _drawText(
  Canvas canvas,
  String text,
  Offset offset,
  TextStyle style, {
  bool alignCenter = false,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final point = alignCenter
      ? Offset(offset.dx - painter.width / 2, offset.dy)
      : offset;
  painter.paint(canvas, point);
}

String _periodTypeLabel(IndicatorGoalPeriodType type) => switch (type) {
  IndicatorGoalPeriodType.daily => 'Daily',
  IndicatorGoalPeriodType.weekly => 'Weekly',
  IndicatorGoalPeriodType.monthly => 'Monthly',
};

String _formatPeriod(BuildContext context, IndicatorGoalPeriod period) {
  final localizations = MaterialLocalizations.of(context);
  if (period.type == IndicatorGoalPeriodType.daily) {
    return localizations.formatFullDate(period.start.asLocalDate);
  }
  final start = localizations.formatShortMonthDay(period.start.asLocalDate);
  final end = localizations.formatShortMonthDay(period.end.asLocalDate);
  return '$start – $end, ${period.end.year}';
}

String _historyLabel(IndicatorGoalPeriod period) {
  return '${period.start.month}/${period.start.day}';
}

PlannerDate _addMonths(PlannerDate date, int delta) {
  final month = DateTime(date.year, date.month + delta, 1);
  return PlannerDate.fromDateTime(month);
}

IconData _iconForGoal(String key) => switch (key) {
  'job_applications' => Icons.work_outline,
  'scripture_study' => Icons.menu_book_outlined,
  'exercise' => Icons.fitness_center,
  'meaningful_connections' => Icons.people_outline,
  'budget_review' => Icons.pie_chart_outline,
  'temple_visit' => Icons.account_balance_outlined,
  _ => Icons.people_outline,
};
