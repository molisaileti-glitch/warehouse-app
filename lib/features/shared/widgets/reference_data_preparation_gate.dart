import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/core/sync/sync_engine.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

const _referenceDataPreparedKey = 'reference_data_prepared_v1';

final referenceDataPreparationServiceProvider =
    Provider<ReferenceDataPreparationService>(
  (ref) => ReferenceDataPreparationService(ref),
);

enum RequiredReferenceData { crops, regions, districts, wards, villages }

class ReferenceDataPreparationResult {
  final int pulled;
  final List<RequiredReferenceData> missing;
  final Object? error;

  const ReferenceDataPreparationResult({
    required this.pulled,
    required this.missing,
    this.error,
  });

  bool get isSuccess => missing.isEmpty;
}

class ReferenceDataPreparationService {
  final Ref _ref;

  ReferenceDataPreparationService(this._ref);

  Future<bool> needsPreparation() async {
    final prefs = await SharedPreferences.getInstance();
    final prepared = prefs.getBool(_referenceDataPreparedKey) ?? false;
    final missing = await _missingRequiredData();
    if (missing.isEmpty) {
      await prefs.setBool(_referenceDataPreparedKey, true);
      return false;
    }
    return !prepared || missing.isNotEmpty;
  }

  Future<ReferenceDataPreparationResult> prepare() async {
    Object? error;
    var pulled = 0;

    try {
      pulled = await _ref.read(syncManagerProvider).pullReferenceData();
    } catch (e) {
      error = e;
    }

    final missing = await _missingRequiredData();
    if (missing.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_referenceDataPreparedKey, true);
    }

    return ReferenceDataPreparationResult(
      pulled: pulled,
      missing: missing,
      error: error,
    );
  }

  Future<List<RequiredReferenceData>> _missingRequiredData() async {
    final missing = <RequiredReferenceData>[];

    if ((await _ref.read(cropDaoProvider).getAllCrops()).isEmpty) {
      missing.add(RequiredReferenceData.crops);
    }
    if ((await _ref.read(regionDaoProvider).getAllRegions()).isEmpty) {
      missing.add(RequiredReferenceData.regions);
    }
    if ((await _ref.read(districtDaoProvider).getAllDistricts()).isEmpty) {
      missing.add(RequiredReferenceData.districts);
    }
    if ((await _ref.read(wardDaoProvider).getAllWards()).isEmpty) {
      missing.add(RequiredReferenceData.wards);
    }
    if ((await _ref.read(villageDaoProvider).getAllVillages()).isEmpty) {
      missing.add(RequiredReferenceData.villages);
    }

    return missing;
  }
}

class ReferenceDataPreparationGate extends ConsumerStatefulWidget {
  final Widget child;

  const ReferenceDataPreparationGate({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ReferenceDataPreparationGate> createState() =>
      _ReferenceDataPreparationGateState();
}

class _ReferenceDataPreparationGateState
    extends ConsumerState<ReferenceDataPreparationGate> {
  String? _checkedUserId;
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).valueOrNull;
    final userId = auth?.userId;

    if (auth?.status == AuthStatus.authenticated &&
        userId != null &&
        userId != _checkedUserId &&
        !_dialogOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPreparationIfNeeded(userId);
      });
    }

    return widget.child;
  }

  Future<void> _showPreparationIfNeeded(String userId) async {
    if (!mounted || _dialogOpen || _checkedUserId == userId) return;

    final service = ref.read(referenceDataPreparationServiceProvider);
    final needsPreparation = await service.needsPreparation();
    if (!mounted) return;

    if (!needsPreparation) {
      _checkedUserId = userId;
      return;
    }

    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReferenceDataPreparationDialog(),
    );
    _dialogOpen = false;
    _checkedUserId = userId;
  }
}

enum _PreparationDialogState { preparing, success, failure }

class _ReferenceDataPreparationDialog extends ConsumerStatefulWidget {
  const _ReferenceDataPreparationDialog();

  @override
  ConsumerState<_ReferenceDataPreparationDialog> createState() =>
      _ReferenceDataPreparationDialogState();
}

class _ReferenceDataPreparationDialogState
    extends ConsumerState<_ReferenceDataPreparationDialog> {
  _PreparationDialogState _state = _PreparationDialogState.preparing;
  ReferenceDataPreparationResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    setState(() {
      _state = _PreparationDialogState.preparing;
      _result = null;
    });

    final result =
        await ref.read(referenceDataPreparationServiceProvider).prepare();
    if (!mounted) return;

    setState(() {
      _result = result;
      _state = result.isSuccess
          ? _PreparationDialogState.success
          : _PreparationDialogState.failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = _result;
    final isPreparing = _state == _PreparationDialogState.preparing;
    final isSuccess = _state == _PreparationDialogState.success;
    final accent = isSuccess
        ? AppColors.success
        : _state == _PreparationDialogState.failure
            ? AppColors.error
            : AppColors.primary;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: isPreparing
                  ? SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: accent,
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        color: accent,
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Text(
              switch (_state) {
                _PreparationDialogState.preparing => l10n.preparingDataTitle,
                _PreparationDialogState.success => l10n.dataReadyTitle,
                _PreparationDialogState.failure =>
                  l10n.dataPreparationFailedTitle,
              },
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              switch (_state) {
                _PreparationDialogState.preparing =>
                  l10n.preparingDataDescription,
                _PreparationDialogState.success => l10n.dataReadyDescription,
                _PreparationDialogState.failure =>
                  _failureDescription(l10n, result),
              },
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (!isPreparing) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: isSuccess
                    ? () => Navigator.of(context).pop()
                    : () => _prepare(),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                child: Text(isSuccess ? l10n.continueButton : l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _failureDescription(
    AppLocalizations l10n,
    ReferenceDataPreparationResult? result,
  ) {
    final missing = result?.missing ?? const <RequiredReferenceData>[];
    if (missing.isEmpty) return l10n.dataPreparationFailedDescription;

    final labels = missing.map((item) => _labelFor(l10n, item)).join(', ');
    return l10n.dataPreparationMissingDescription(labels);
  }

  String _labelFor(AppLocalizations l10n, RequiredReferenceData item) {
    return switch (item) {
      RequiredReferenceData.crops => l10n.crops,
      RequiredReferenceData.regions => l10n.regions,
      RequiredReferenceData.districts => l10n.districts,
      RequiredReferenceData.wards => l10n.wards,
      RequiredReferenceData.villages => l10n.villages,
    };
  }
}
