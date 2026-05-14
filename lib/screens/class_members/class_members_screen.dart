import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/providers/class_member_provider.dart';
import 'package:summerschool/providers/points_provider.dart';
import 'package:summerschool/services/class_member_service.dart';
import 'package:summerschool/services/points_service.dart';
import 'package:summerschool/models/class_member_model.dart';
import 'package:summerschool/screens/class_members/add_edit_class_member_screen.dart';
import 'package:summerschool/screens/points/points_history_screen.dart';

class ClassMembersScreen extends StatefulWidget {
  const ClassMembersScreen({super.key});

  @override
  State<ClassMembersScreen> createState() => _ClassMembersScreenState();
}

class _ClassMembersScreenState extends State<ClassMembersScreen> {
  String? _lastLoggedStage;

  void _openHistory(ClassMemberModel student, String stage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ChangeNotifierProvider<PointsProvider>(
          create: (_) =>
              PointsProvider(PointsService())
                ..startListeningHistory(stage, studentId: student.id),
          child: PointsHistoryScreen(student: student),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      debugPrint(
        '[ClassMembersScreen] AuthProvider still loading. Waiting before starting class query.',
      );

      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = auth.user;

    if (user == null) {
      debugPrint(
        '[ClassMembersScreen] currentUser is null after auth load. No class query started.',
      );

      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final normalizedStage = ClassMemberService.normalizeStage(user.stage);

    if (user.stage.trim().isEmpty || normalizedStage.isEmpty) {
      debugPrint(
        '[ClassMembersScreen] user loaded but stage is empty. uid=${user.id} role=${user.role.value} stage="${user.stage}" stage_norm="$normalizedStage". Waiting instead of running empty query.',
      );

      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_lastLoggedStage != user.stage) {
      _lastLoggedStage = user.stage;

      debugPrint(
        '[ClassMembersScreen] current user uid=${user.id} role=${user.role.value} stage="${user.stage}" stage_norm="$normalizedStage"',
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        debugPrint(
          '[STREAM START] ClassMembersScreen starting realtime listener for stage="${user.stage}"',
        );

        context.read<ClassMemberProvider>().startListening(user.stage);
      });
    }

    return Consumer<ClassMemberProvider>(
      builder: (context, provider, _) {
        debugPrint(
          '[UI REBUILD] ClassMembersScreen Consumer rebuild members=${provider.members.length}',
        );

        final members = provider.members;

        return Scaffold(
          backgroundColor: AppColors.surfaceSoft,

          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            title: Text('Class: ${user.stage}'),
          ),

          floatingActionButton: auth.isMemberManager
              ? FloatingActionButton(
                  onPressed: () async {
                    final created = await Navigator.push<ClassMemberModel?>(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) =>
                            ChangeNotifierProvider<ClassMemberProvider>.value(
                              value: context.read<ClassMemberProvider>(),
                              child: const AddEditClassMemberScreen(),
                            ),
                      ),
                    );

                    if (created != null) {}
                  },
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add),
                )
              : null,

          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),

              child: Column(
                children: [
                  TextField(
                    onChanged: provider.setSearch,

                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search by name',
                      filled: true,
                      fillColor: Colors.white,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: provider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : members.isEmpty
                        ? Center(
                            child: Text('No students found for ${user.stage}'),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,

                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  AppColors.primary.withOpacity(0.1),
                                ),

                                border: TableBorder.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),

                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'الاسم',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  DataColumn(
                                    label: Text(
                                      'مرحلة',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  DataColumn(
                                    label: Text(
                                      'السنة',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  DataColumn(
                                    label: Text(
                                      'التليفون',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  DataColumn(
                                    label: Text(
                                      'تليفون ولي الأمر',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  DataColumn(
                                    label: Text(
                                      'اب الاعتراف',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  DataColumn(
                                    label: Text(
                                      'الطايوهات',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  DataColumn(
                                    label: Text(
                                      'الإجراءات',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],

                                rows: members.map((m) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(m.name)),
                                      DataCell(Text(m.stage)),
                                      DataCell(Text(m.year)),
                                      DataCell(Text(m.phone)),
                                      DataCell(Text(m.parentPhone)),
                                      DataCell(Text(m.confessionFather)),

                                      DataCell(
                                        Consumer<ClassMemberProvider>(
                                          builder: (context, memberProvider, _) {
                                            debugPrint(
                                              '[UI REBUILD][DataTable] member="${m.name}"',
                                            );

                                            final freshMember = memberProvider
                                                .allMembers
                                                .firstWhere(
                                                  (mem) => mem.id == m.id,
                                                  orElse: () => m,
                                                );

                                            debugPrint(
                                              '[TOTAL POINTS UPDATED] member="${freshMember.name}" totalPoints=${freshMember.totalPoints}',
                                            );

                                            return Text(
                                              freshMember.totalPoints
                                                  .toString(),

                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.green,
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,

                                          children: [
                                            IconButton(
                                              tooltip: 'History',
                                              iconSize: 18,

                                              onPressed: () =>
                                                  _openHistory(m, user.stage),

                                              icon: const Icon(
                                                Icons.history_rounded,
                                                color: Colors.purple,
                                              ),
                                            ),

                                            if (auth.isMemberManager)
                                              IconButton(
                                                tooltip: 'Edit',
                                                iconSize: 18,

                                                onPressed: () async {
                                                  await Navigator.push<
                                                    ClassMemberModel?
                                                  >(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (ctx) =>
                                                          ChangeNotifierProvider<
                                                            ClassMemberProvider
                                                          >.value(
                                                            value: context
                                                                .read<
                                                                  ClassMemberProvider
                                                                >(),

                                                            child:
                                                                AddEditClassMemberScreen(
                                                                  member: m,
                                                                ),
                                                          ),
                                                    ),
                                                  );
                                                },

                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  color: Colors.blue,
                                                ),
                                              ),

                                            if (auth.isMemberManager)
                                              IconButton(
                                                tooltip: 'Delete',
                                                iconSize: 18,

                                                onPressed: () async {
                                                  final confirmed =
                                                      await showDialog<bool>(
                                                        context: context,

                                                        builder: (_) => AlertDialog(
                                                          title: const Text(
                                                            'حذف الطالب',
                                                          ),

                                                          content: Text(
                                                            'هل تريد حذف ${m.name}؟ لا يمكن التراجع عن هذا الإجراء.',
                                                          ),

                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    false,
                                                                  ),

                                                              child: const Text(
                                                                'الغاء',
                                                              ),
                                                            ),

                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    true,
                                                                  ),

                                                              child: const Text(
                                                                'حذف',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );

                                                  if (confirmed == true) {
                                                    try {
                                                      await context
                                                          .read<
                                                            ClassMemberProvider
                                                          >()
                                                          .deleteMember(m.id);
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Delete failed: $e',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },

                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
