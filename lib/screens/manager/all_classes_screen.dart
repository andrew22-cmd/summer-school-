import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/providers/auth_provider.dart';
import 'package:summerschool/screens/manager/manager_class_details_screen.dart';
import 'package:provider/provider.dart';

class AllClassesScreen extends StatelessWidget {
  const AllClassesScreen({super.key});

  static const List<String> _stages = [
    '1s',
    '1m',
    '2s',
    '2m',
    '3s',
    '3m',
    '4s',
    '4m',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('All Classes')),
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
        title: const Text('All Classes'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1400
                ? 5
                : width >= 1100
                ? 4
                : width >= 800
                ? 3
                : width >= 560
                ? 2
                : 1;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a class to monitor (read only)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      itemCount: _stages.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.45,
                      ),
                      itemBuilder: (context, index) {
                        final stage = _stages[index];
                        return _StageCard(
                          stage: stage,
                          onTap: () {
                            debugPrint(
                              '[Manager][AllClasses] selected class="$stage"',
                            );
                            debugPrint(
                              '[Manager][AllClasses] navigation -> ManagerClassDetailsScreen(stage="$stage")',
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ManagerClassDetailsScreen(
                                  selectedStage: stage,
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
            );
          },
        ),
      ),
    );
  }
}

class _StageCard extends StatefulWidget {
  const _StageCard({required this.stage, required this.onTap});

  final String stage;
  final VoidCallback onTap;

  @override
  State<_StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<_StageCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, _hovered ? -2.0 : 0.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF7FBFF), Colors.white],
                ),
                border: Border.all(
                  color: _hovered
                      ? AppColors.primary.withOpacity(0.45)
                      : Colors.grey.shade300,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_hovered ? 0.08 : 0.04),
                    blurRadius: _hovered ? 14 : 10,
                    offset: Offset(0, _hovered ? 8 : 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.stage,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
