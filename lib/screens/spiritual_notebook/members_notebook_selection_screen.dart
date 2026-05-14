import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/user_model.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/members_notebook_provider.dart';
import 'package:summerschool/services/spiritual_notebook_service.dart';
import 'package:summerschool/screens/spiritual_notebook/read_only_member_notebook_screen.dart';

class MembersNotebookSelectionScreen extends StatefulWidget {
  const MembersNotebookSelectionScreen({super.key});

  @override
  State<MembersNotebookSelectionScreen> createState() =>
      _MembersNotebookSelectionScreenState();
}

class _MembersNotebookSelectionScreenState
    extends State<MembersNotebookSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.user;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ChangeNotifierProvider<MembersNotebookProvider>(
      create: (_) =>
          MembersNotebookProvider(SpiritualNotebookService())
            ..startListening(stage: currentUser.stage),
      child: Consumer<MembersNotebookProvider>(
        builder: (context, provider, _) {
          final members = provider.members;

          return Scaffold(
            backgroundColor: AppColors.surfaceSoft,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              title: const Text('Members Notebooks'),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      onChanged: provider.setSearchQuery,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Search members',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: provider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : members.isEmpty
                          ? _EmptyState(
                              hasSearch: provider.searchQuery.trim().isNotEmpty,
                            )
                          : ListView.separated(
                              itemCount: members.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final member = members[index];
                                return _MemberCard(
                                  member: member,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ReadOnlyMemberNotebookScreen(
                                              member: member,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.onTap});

  final UserModel member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Icon(Icons.person_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Stage: ${member.stage}'),
                    Text('Class: ${member.className}'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 52, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            hasSearch
                ? 'No members match this search.'
                : 'No members found for your stage/class.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
