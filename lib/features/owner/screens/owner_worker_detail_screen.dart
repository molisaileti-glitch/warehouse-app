import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/providers/auth_provider.dart';
import 'package:warehouse_app/core/providers/repository_providers.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

final _workerAmcosProvider = StreamProvider.family<Amcos?, int>((ref, id) {
  return ref.watch(amcosDaoProvider).watchAmcosById(id);
});

final _workerMcuProvider = StreamProvider.family<User?, int>((ref, id) {
  return ref.watch(workerDaoProvider).watchUserById(id.toString());
});

class OwnerWorkerDetailScreen extends ConsumerWidget {
  final String workerId;

  const OwnerWorkerDetailScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(allWorkersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Worker Details'),
        actions: [
          workersAsync.maybeWhen(
            data: (workers) {
              final worker =
                  workers.where((item) => item.id == workerId).firstOrNull;
              if (worker == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Edit worker',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _showEditSheet(context, worker),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: workersAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (workers) {
          final worker =
              workers.where((item) => item.id == workerId).firstOrNull;
          if (worker == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Worker not found',
            );
          }

          final warehouseAsync = worker.warehouseId == null
              ? const AsyncValue<Warehouse?>.data(null)
              : ref.watch(warehouseByIdProvider(worker.warehouseId!));
          final amcosAsync = worker.amcos == null
              ? const AsyncValue<Amcos?>.data(null)
              : ref.watch(_workerAmcosProvider(worker.amcos!));
          final mcuAsync = worker.mcu == null
              ? const AsyncValue<User?>.data(null)
              : ref.watch(_workerMcuProvider(worker.mcu!));
          final amcosName = _amcosLabel(amcosAsync, worker.amcos);
          final mcuName = _mcuLabel(mcuAsync, amcosAsync, worker.mcu);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            AppColors.workerColor.withValues(alpha: 0.12),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.workerColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              worker.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              worker.email,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SyncStatusBadge(status: worker.syncStatus),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    children: [
                      _DetailRow(label: 'Phone', value: worker.phoneNumber),
                      _DetailRow(label: 'Role', value: worker.role),
                      _DetailRow(
                        label: 'Status',
                        value: worker.isActive ? 'Active' : 'Inactive',
                      ),
                      _DetailRow(label: 'AMCOS', value: amcosName),
                      _DetailRow(label: 'MCU', value: mcuName),
                      warehouseAsync.maybeWhen(
                        data: (warehouse) => _DetailRow(
                          label: 'Warehouse',
                          value: warehouse?.name ?? '-',
                        ),
                        orElse: () => const _DetailRow(
                          label: 'Warehouse',
                          value: 'Loading...',
                        ),
                      ),
                      _DetailRow(
                        label: 'Created',
                        value: DateFormat('MMM d, yyyy HH:mm')
                            .format(worker.createdAt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: () => _deleteWorker(context, ref, worker),
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('Delete Worker'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _amcosLabel(AsyncValue<Amcos?> async, int? id) {
    if (id == null) return '-';
    return async.maybeWhen(
      data: (amcos) {
        final name = amcos?.name.trim();
        return name == null || name.isEmpty ? 'AMCOS #$id' : name;
      },
      loading: () => 'Loading...',
      orElse: () => 'AMCOS #$id',
    );
  }

  String _mcuLabel(AsyncValue<User?> async, AsyncValue<Amcos?> amcos, int? id) {
    if (id == null) return '-';
    return async.maybeWhen(
      data: (user) {
        final name = user?.fullName.trim();
        if (name != null && name.isNotEmpty) return name;
        final amcosMcuName = amcos.valueOrNull?.mcuName.trim();
        if (amcosMcuName != null && amcosMcuName.isNotEmpty) {
          return amcosMcuName;
        }
        return 'MCU #$id';
      },
      loading: () => 'Loading...',
      orElse: () => 'MCU #$id',
    );
  }

  void _showEditSheet(BuildContext context, User worker) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditWorkerSheet(
        worker: worker,
        parentContext: context,
      ),
    );
  }

  Future<void> _deleteWorker(
    BuildContext context,
    WidgetRef ref,
    User worker,
  ) async {
    final confirmed = await showCreationConfirmDialog(
      context,
      title: 'Delete Worker',
      description:
          'This will remove ${worker.fullName} locally and queue the change for sync.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    showCenteredLoadingDialog(
      context,
      title: 'Deleting Worker',
      description: 'Removing this worker locally.',
    );
    try {
      await ref.read(workerRepoProvider).deleteWorker(worker.id);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ref.invalidate(allWorkersProvider);
      await showCreationSuccessDialog(
        context,
        title: 'Worker Deleted',
        description: 'Worker successfully deleted.',
      );
      if (context.mounted) context.go(AppRoutes.ownerUsers);
    } catch (error) {
      if (!context.mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _EditWorkerSheet extends ConsumerStatefulWidget {
  final User worker;
  final BuildContext parentContext;

  const _EditWorkerSheet({
    required this.worker,
    required this.parentContext,
  });

  @override
  ConsumerState<_EditWorkerSheet> createState() => _EditWorkerSheetState();
}

class _EditWorkerSheetState extends ConsumerState<_EditWorkerSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.worker.fullName);
  late final _emailCtrl = TextEditingController(text: widget.worker.email);
  late final _phoneCtrl =
      TextEditingController(text: widget.worker.phoneNumber);
  late String? _warehouseId = widget.worker.warehouseId;
  late bool _isActive = widget.worker.isActive;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_warehouseId == null) {
      setState(() => _error = 'Please assign this worker to a warehouse.');
      return;
    }

    final warehouse =
        await ref.read(warehouseDaoProvider).getWarehouseById(_warehouseId!);
    if (!mounted) return;
    if (warehouse == null) {
      setState(() => _error = 'Selected warehouse not found.');
      return;
    }

    final currentUserId = ref.read(currentUserIdProvider);
    final mcuId = int.tryParse(currentUserId ?? '') ?? widget.worker.mcu;
    final confirmed = await showCreationConfirmDialog(
      context,
      title: 'Save Worker Changes',
      description: 'Save changes for ${_nameCtrl.text.trim()}?',
      confirmLabel: 'Save',
    );
    if (!confirmed) return;
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    showCenteredLoadingDialog(
      context,
      title: 'Updating Worker',
      description: 'Saving worker changes locally.',
    );

    try {
      await ref.read(workerRepoProvider).updateWorker(
            id: widget.worker.id,
            fullName: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
            warehouseId: _warehouseId,
            mcu: mcuId,
            amcos: warehouse.amcos,
            isActive: _isActive,
          );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ref.invalidate(allWorkersProvider);
      Navigator.pop(context);
      if (widget.parentContext.mounted) {
        await showCreationSuccessDialog(
          widget.parentContext,
          title: 'Worker Updated',
          description: 'Worker successfully updated.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() {
        _loading = false;
        _error = 'Error: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final warehousesAsync = currentUserId == null
        ? const AsyncValue<List<Warehouse>>.data([])
        : ref.watch(warehousesByOwnerProvider(currentUserId));
    final warehouses =
        warehousesAsync.valueOrNull?.where((w) => w.isActive).toList() ??
            const <Warehouse>[];

    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Edit Worker',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return value.contains('@') ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _warehouseId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assign to warehouse',
                  prefixIcon: Icon(Icons.warehouse_rounded),
                ),
                selectedItemBuilder: (context) => warehouses
                    .map(
                      (warehouse) => Text(
                        warehouse.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                    .toList(),
                items: warehouses
                    .map(
                      (warehouse) => DropdownMenuItem<String>(
                        value: warehouse.id,
                        child: Text(
                          warehouse.amcosName == null
                              ? warehouse.name
                              : '${warehouse.name} - ${warehouse.amcosName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _warehouseId = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                activeThumbColor: AppColors.primary,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _save,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
