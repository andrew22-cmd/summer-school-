import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/providers/admin_users_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserModel> _filterUsers(List<UserModel> users) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return users;

    return users.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q) ||
          u.stage.toLowerCase().contains(q) ||
          u.role.value.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _showUserFormDialog({UserModel? user}) async {
    final provider = context.read<AdminUsersProvider>();
    final isEdit = user != null;

    final nameController = TextEditingController(text: user?.name ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final fatherController = TextEditingController(
      text: user?.confessionFather ?? '',
    );
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();

    // Stage dropdown options
    const stageOptions = [
      '1 S',
      '1 M',
      '2 S',
      '2 M',
      '3 S',
      '3 M',
      '4 S',
      '4 M',
    ];

    UserRole selectedRole = user?.role ?? UserRole.member;
    String? selectedStage = (user?.stage ?? '').isNotEmpty ? user?.stage : null;
    bool _showPassword = false;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit User' : 'Add User'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name field
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty)
                              return 'Name is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Email field
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if ((v ?? '').isEmpty) return 'Email is required';
                            if (!v!.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Password field only shown when adding new user
                        if (!isEdit) ...[
                          TextFormField(
                            controller: passwordController,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              labelText: 'Password (min 6 chars) *',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setDialogState(
                                    () => _showPassword = !_showPassword,
                                  );
                                },
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password is required';
                              }
                              if (v.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Phone field
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Confession Father field
                        TextFormField(
                          controller: fatherController,
                          decoration: const InputDecoration(
                            labelText: 'Confession Father',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Role dropdown
                        DropdownButtonFormField<UserRole>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role *',
                            border: OutlineInputBorder(),
                          ),
                          items: UserRoleX.all
                              .map(
                                (role) => DropdownMenuItem<UserRole>(
                                  value: role,
                                  child: Text(role.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              selectedRole = value;
                              // Managers do not need stage.
                              if (selectedRole == UserRole.manager) {
                                selectedStage = null;
                              }
                            });
                          },
                          validator: (value) {
                            if (value == null) return 'Role is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Stage dropdown
                        DropdownButtonFormField<String>(
                          value: selectedStage,
                          decoration: InputDecoration(
                            labelText: selectedRole == UserRole.manager
                                ? 'Stage (not required for manager)'
                                : 'Stage *',
                            border: const OutlineInputBorder(),
                          ),
                          items: stageOptions
                              .map(
                                (stage) => DropdownMenuItem<String>(
                                  value: stage,
                                  child: Text(stage),
                                ),
                              )
                              .toList(),
                          onChanged: selectedRole == UserRole.manager
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() => selectedStage = value);
                                },
                          validator: (value) {
                            if (selectedRole == UserRole.manager) {
                              return null;
                            }
                            if (value == null || value.isEmpty) {
                              return 'Stage is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    try {
                      if (isEdit) {
                        final stageValue = selectedRole == UserRole.manager
                            ? ''
                            : (selectedStage ?? '');
                        await provider.editUser(
                          id: user.id,
                          name: nameController.text,
                          phone: phoneController.text,
                          confessionFather: fatherController.text,
                          role: selectedRole,
                          stage: stageValue,
                          email: emailController.text,
                        );
                      } else {
                        // Add user with Firebase Auth + Firestore sync
                        final stageValue = selectedRole == UserRole.manager
                            ? ''
                            : (selectedStage ?? '');
                        await provider.addUser(
                          name: nameController.text,
                          phone: phoneController.text,
                          confessionFather: fatherController.text,
                          role: selectedRole,
                          stage: stageValue,
                          email: emailController.text,
                          password: passwordController.text,
                        );
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.errorMessage ?? 'Failed to save user.',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Add User'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    fatherController.dispose();
    emailController.dispose();
    passwordController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'User updated.'
                : 'User account created successfully! They can now log in.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(UserModel user) async {
    final provider = context.read<AdminUsersProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await provider.deleteUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User deleted.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to delete user.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminUsersProvider>();
    final allUsers = provider.users;
    final users = _filterUsers(allUsers);

    final managers = allUsers.where((u) => u.role == UserRole.manager).length;
    final memberManagers = allUsers
        .where((u) => u.role == UserRole.memberManager)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.adminLogin,
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserFormDialog(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add User'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'All Users',
                    value: allUsers.length.toString(),
                    icon: Icons.groups_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: 'Managers',
                    value: managers.toString(),
                    icon: Icons.admin_panel_settings_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: 'Member Managers',
                    value: memberManagers.toString(),
                    icon: Icons.manage_accounts_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, phone, stage, role...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : users.isEmpty
                  ? const Center(child: Text('No users found.'))
                  : ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              child: Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : 'U',
                              ),
                            ),
                            title: Text(
                              user.name.isEmpty ? 'Unnamed User' : user.name,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  user.email.isEmpty ? 'No email' : user.email,
                                ),
                                Text(
                                  'Phone: ${user.phone.isEmpty ? '-' : user.phone}',
                                ),
                                Text(
                                  'Stage: ${user.stage.isEmpty ? '-' : user.stage}',
                                ),
                              ],
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Chip(label: Text(user.role.label)),
                                IconButton(
                                  onPressed: () =>
                                      _showUserFormDialog(user: user),
                                  icon: const Icon(Icons.edit_rounded),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  onPressed: () => _confirmDelete(user),
                                  icon: const Icon(Icons.delete_rounded),
                                  color: Theme.of(context).colorScheme.error,
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
