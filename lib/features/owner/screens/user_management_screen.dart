// lib/features/owner/screens/user_management_screen.dart
//
// Owner can view existing workers AND add new ones.
// Creating a worker stores it locally and queues POST /auth/signup for manual sync.
//
// Field mapping:
//   fullName    → typed by owner
//   email       → typed by owner
//   phoneNumber → typed by owner
//   password    → typed by owner
//   role        → hardcoded 'AMCOS_USER'
//   mcu         → int.parse(currentUserId) — logged-in owner's numeric server ID
//   amcos       → warehouse.amcos — pulled silently from the selected warehouse

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/database/database_provider.dart';
import '../../worker/domain/models/worker_model.dart';
import '../../shared/widgets/common_widgets.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _workersProvider = allWorkersProvider;

// ── Screen ────────────────────────────────────────────────────────────────────

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_workersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Workers'),
        actions: [
          IconButton(
            tooltip: 'Add worker',
            onPressed: () => _showAddWorkerSheet(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),

      // ── FAB — opens Add Worker sheet ──────────────────────────────────────
      body: Column(
        children: [
          // Info banner
          // Worker list
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final workers = users;
                if (workers.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_rounded,
                    title: 'No workers yet',
                    subtitle: 'Use + to create your first worker account',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: workers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _WorkerTile(user: workers[i]),
                );
              },
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: '$e'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWorkerSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddWorkerSheet(),
    );
  }
}

// ── Worker tile ───────────────────────────────────────────────────────────────

class _WorkerTile extends ConsumerWidget {
  final User user;
  const _WorkerTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouseAsync = user.warehouseId != null
        ? ref.watch(warehouseByIdProvider(user.warehouseId!))
        : const AsyncValue.data(null);

    return AppCard(
      onTap: () => context.push(AppRoutes.ownerUserDetailFor(user.id)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.workerColor.withValues(alpha: 0.12),
            child: const Icon(Icons.person_rounded,
                color: AppColors.workerColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(user.email,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                if (user.warehouseId != null)
                  warehouseAsync.maybeWhen(
                    data: (w) => w != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(children: [
                              const Icon(Icons.warehouse_rounded,
                                  size: 11, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(w.name,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted)),
                            ]),
                          )
                        : const SizedBox(),
                    orElse: () => const SizedBox(),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: user.isActive
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.textMuted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      user.isActive ? AppColors.success : AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Worker bottom sheet ───────────────────────────────────────────────────

class _AddWorkerSheet extends ConsumerStatefulWidget {
  const _AddWorkerSheet();

  @override
  ConsumerState<_AddWorkerSheet> createState() => _AddWorkerSheetState();
}

class _AddWorkerSheetState extends ConsumerState<_AddWorkerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String? _selectedWarehouseId;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWarehouseId == null) {
      setState(() => _error = 'Please assign this worker to a warehouse.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // ── Derive amcos + mcu from local DB ─────────────────────────────────────
    final warehouseDao = ref.read(warehouseDaoProvider);
    final warehouse =
        await warehouseDao.getWarehouseById(_selectedWarehouseId!);

    if (warehouse == null) {
      setState(() {
        _loading = false;
        _error = 'Selected warehouse not found. Please try again.';
      });
      return;
    }

    final amcosId = warehouse.amcos;
    if (amcosId == null) {
      setState(() {
        _loading = false;
        _error =
            '"${warehouse.name}" has no AMCOS assigned. Please select a different warehouse.';
      });
      return;
    }

    // mcu is the logged-in owner's numeric server ID stored in secure storage.
    final currentUserId = ref.read(currentUserIdProvider);
    final mcuId = int.tryParse(currentUserId ?? '');
    if (mcuId == null) {
      setState(() {
        _loading = false;
        _error = 'Could not determine owner ID. Please log out and back in.';
      });
      return;
    }

    // ── Call API ──────────────────────────────────────────────────────────────
    final result = await ref.read(workerRepoProvider).createWorker(
          WorkerModel(
            fullName: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
            password: _passwordCtrl.text,
            mcu: mcuId,
            amcos: amcosId,
            warehouseId: _selectedWarehouseId,
          ),
        );

    if (!mounted) return;

    if (result.success) {
      ref.invalidate(allWorkersProvider);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Worker account created.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      setState(() {
        _loading = false;
        _error = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final warehousesAsync = currentUserId != null
        ? ref.watch(warehousesByOwnerProvider(currentUserId))
        : const AsyncValue<List<Warehouse>>.data([]);

    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: _FormView(
        formKey: _formKey,
        nameCtrl: _nameCtrl,
        emailCtrl: _emailCtrl,
        phoneCtrl: _phoneCtrl,
        passwordCtrl: _passwordCtrl,
        selectedWarehouseId: _selectedWarehouseId,
        warehousesAsync: warehousesAsync,
        error: _error,
        loading: _loading,
        obscurePassword: _obscurePassword,
        onWarehouseChanged: (id) => setState(() => _selectedWarehouseId = id),
        onTogglePassword: () =>
            setState(() => _obscurePassword = !_obscurePassword),
        onSubmit: _submit,
      ),
    );
  }
}

// ── Form view ─────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final String? selectedWarehouseId;
  final AsyncValue<List<Warehouse>> warehousesAsync;
  final String? error;
  final bool loading;
  final bool obscurePassword;
  final ValueChanged<String?> onWarehouseChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  const _FormView({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.selectedWarehouseId,
    required this.warehousesAsync,
    required this.error,
    required this.loading,
    required this.obscurePassword,
    required this.onWarehouseChanged,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final warehouses =
        warehousesAsync.valueOrNull?.where((w) => w.isActive).toList() ?? [];

    return Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.ownerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_rounded,
                    color: AppColors.ownerColor, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Worker',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Fill in details and assign a warehouse',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ]),
            const SizedBox(height: 24),

            // Error banner
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // Full name field
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter worker name' : null,
            ),
            const SizedBox(height: 12),

            // Email field
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter worker email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Phone number field
            TextFormField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter phone number' : null,
            ),
            const SizedBox(height: 12),

            // Password field
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: onTogglePassword,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a password';
                if (v.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Warehouse dropdown
            // The selected warehouse also silently provides the amcos ID.
            DropdownButtonFormField<String>(
              initialValue: selectedWarehouseId,
              decoration: const InputDecoration(
                labelText: 'Assign to warehouse',
                prefixIcon: Icon(Icons.warehouse_rounded),
                helperText:
                    'AMCOS is derived automatically from this selection',
                helperStyle:
                    TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              hint: const Text('Select warehouse'),
              items: warehouses
                  .map((w) => DropdownMenuItem(
                        value: w.id,
                        child: Text(w.amcosName != null
                            ? '${w.name} · ${w.amcosName}'
                            : w.name),
                      ))
                  .toList(),
              onChanged: onWarehouseChanged,
              validator: (v) => v == null ? 'Please assign a warehouse' : null,
            ),
            const SizedBox(height: 28),

            // Submit button
            loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.ownerColor))
                : ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ownerColor),
                    child: const Text('Create Worker Account'),
                  ),
          ],
        ),
      ),
    );
  }
}
