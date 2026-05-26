import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/screens/spiritual_notebook/read_only_member_notebook_screen.dart';
import 'package:summerschool/services/firestore_user_service.dart';

class AllMembersScreen extends StatefulWidget {
  const AllMembersScreen({super.key});

  @override
  State<AllMembersScreen> createState() => _AllMembersScreenState();
}

class _AllMembersScreenState extends State<AllMembersScreen> {
  String _query = '';
  String _roleFilter = 'all';
  String _stageFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('All Members')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This page is available to managers only.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text('All Members'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: StreamBuilder<List<UserModel>>(
            stream: context.read<FirestoreUserService>().watchAllUsers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = snapshot.data!;
              debugPrint(
                '[Manager][AllMembers] members loaded count=${users.length}',
              );

              final roles = <String>{
                'all',
                ...users.map((u) => u.role.value),
              }.toList()..sort();
              final stages = <String>{
                'all',
                ...users.map((u) => u.stage.trim()).where((s) => s.isNotEmpty),
              }.toList()..sort();

              final safeRoleFilter = roles.contains(_roleFilter)
                  ? _roleFilter
                  : 'all';
              final safeStageFilter = stages.contains(_stageFilter)
                  ? _stageFilter
                  : 'all';

              if (safeRoleFilter != _roleFilter ||
                  safeStageFilter != _stageFilter) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _roleFilter = safeRoleFilter;
                    _stageFilter = safeStageFilter;
                  });
                });
              }

              final filtered = users.where((u) {
                final q = _query.trim().toLowerCase();
                final searchMatch =
                    q.isEmpty ||
                    u.name.toLowerCase().contains(q) ||
                    u.phone.toLowerCase().contains(q);
                final roleMatch =
                    safeRoleFilter == 'all' || u.role.value == safeRoleFilter;
                final stageMatch =
                    safeStageFilter == 'all' ||
                    u.stage.trim() == safeStageFilter;
                return searchMatch && roleMatch && stageMatch;
              }).toList();

              debugPrint(
                '[Manager][AllMembers] search/filter applied query="$_query" role=$_roleFilter stage=$_stageFilter result=${filtered.length}',
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1000;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FiltersBar(
                        roles: roles,
                        stages: stages,
                        roleFilter: safeRoleFilter,
                        stageFilter: safeStageFilter,
                        onSearchChanged: (v) => setState(() => _query = v),
                        onRoleChanged: (v) => setState(() => _roleFilter = v),
                        onStageChanged: (v) => setState(() => _stageFilter = v),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filtered.isEmpty
                            ? const _EmptyState()
                            : compact
                            ? ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final u = filtered[index];
                                  return _MemberCard(
                                    user: u,
                                    onOpenNote: () => _openNote(context, u),
                                  );
                                },
                              )
                            : _MembersTable(
                                users: filtered,
                                onOpenNote: _openNote,
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _openNote(BuildContext context, UserModel user) {
    debugPrint(
      '[Manager][AllMembers] spiritual notebook opened userId=${user.id}',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadOnlyMemberNotebookScreen(member: user),
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.roles,
    required this.stages,
    required this.roleFilter,
    required this.stageFilter,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onStageChanged,
  });

  final List<String> roles;
  final List<String> stages;
  final String roleFilter;
  final String stageFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onStageChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          runSpacing: 10,
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Search by name or phone',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                value: roleFilter,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => onRoleChanged(v ?? 'all'),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                value: stageFilter,
                decoration: const InputDecoration(
                  labelText: 'Stage',
                  border: OutlineInputBorder(),
                ),
                items: stages
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => onStageChanged(v ?? 'all'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersTable extends StatelessWidget {
  const _MembersTable({required this.users, required this.onOpenNote});

  final List<UserModel> users;
  final void Function(BuildContext context, UserModel user) onOpenNote;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1100),
            child: DataTable(
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w800),
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Confession Father')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Stage')),
                DataColumn(label: Text('Spiritual Note')),
              ],
              rows: users.map((u) {
                return DataRow(
                  cells: [
                    DataCell(Text(u.name)),
                    DataCell(Text(u.phone)),
                    DataCell(Text(u.confessionFather)),
                    DataCell(Text(u.role.value)),
                    DataCell(Text(u.stage)),
                    DataCell(
                      OutlinedButton(
                        onPressed: () => onOpenNote(context, u),
                        child: const Text('His Note'),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.user, required this.onOpenNote});

  final UserModel user;
  final VoidCallback onOpenNote;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('Phone: ${user.phone}'),
            Text('Confession Father: ${user.confessionFather}'),
            Text('Role: ${user.role.value}'),
            Text('Stage: ${user.stage}'),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton(
                onPressed: onOpenNote,
                child: const Text('His Note'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_rounded, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text('No members match your filters.'),
        ],
      ),
    );
  }
}
