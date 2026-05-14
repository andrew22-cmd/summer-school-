import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:summerschool/core/routes/app_routes.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/services/firestore_user_service.dart';
import 'package:summerschool/core/constants/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isSaving = false;

  FirestoreUserService get _userService => FirestoreUserService();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.login),
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    // Initialize controller with current phone
    _phoneController.text = user.phone;

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await _handleLogout(context);
            },
            icon: Icon(Icons.logout, color: AppColors.primary),
            label: const Text(
              'Logout',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(user),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildReadOnlyField(label: 'Email', value: user.email),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(label: 'Name', value: user.name),
                    const SizedBox(height: 12),
                    _buildEditablePhoneField(),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(label: 'Role', value: user.role.value),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(label: 'Stage', value: user.stage),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(label: 'Class', value: user.className),
                    const SizedBox(height: 12),
                    _buildReadOnlyField(
                      label: 'Confession Father',
                      value: user.confessionFather,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildActions(context, user),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    final initials = _computeInitials(user.name);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Text(
              initials,
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.email,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _computeInitials(String name) {
    final parts = name.trim().split(RegExp('\\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: AppColors.primary, width: 6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.lock, size: 18, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildEditablePhoneField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: InputBorder.none,
                isDense: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Please enter a phone number.';
                if (v.trim().length < 6) return 'Enter a valid phone number.';
                return null;
              },
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, UserModel user) {
    final changed = _phoneController.text.trim() != user.phone.trim();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: AppColors.primary.withOpacity(0.12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _isSaving ? null : () => _handleLogout(context),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: (!_isSaving && changed) ? () => _savePhone(user) : null,
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _savePhone(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;

    final newPhone = _phoneController.text.trim();
    setState(() => _isSaving = true);

    try {
      await _userService.updateUser(user.id, {'phone': newPhone});

      // Update local provider user if available
      final auth = context.read<AuthProvider>();
      // Re-fetch the user from service and reinitialize auth provider so provider user is refreshed
      await auth.initialize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone updated successfully')),
        );
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $message')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (r) => false);
    }
  }
}
