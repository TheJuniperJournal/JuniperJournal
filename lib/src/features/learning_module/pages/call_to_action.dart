import 'assessment_block.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:juniper_journal/src/backend/db/repositories/learning_module_repo.dart';
import 'package:juniper_journal/src/features/home_page/home_page.dart';
import 'package:juniper_journal/src/features/learning_module/learning_module.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class CallToAction extends StatefulWidget {
  final Map<String, dynamic>? existingModule;

  const CallToAction({super.key, this.existingModule});

  @override
  State<CallToAction> createState() => _CallToActionScreenState();
}

class _CallToActionScreenState extends State<CallToAction> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedNavigation = 'CALL TO ACTION';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadExistingData();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadExistingData() async {
    final module = widget.existingModule;
    if (module != null && module['id'] != null) {
      final repo = LearningModuleRepo();
      final fresh = await repo.getModule(module['id'].toString());

      if (!mounted) return;

      if (fresh != null && fresh['call_to_action'] != null) {
        setState(() {
          _controller.text = fresh['call_to_action'].toString();
        });
      }
    }
  }

  String _formatDate(String? createdAt) {
    if (createdAt == null) {
      return DateFormat('EEEE, MMMM d').format(DateTime.now());
    }
    try {
      return DateFormat(
        'EEEE, MMMM d',
      ).format(DateTime.parse(createdAt).toLocal());
    } catch (_) {
      return 'Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final widgetModule = widget.existingModule ?? {};
    final moduleName = widgetModule['module_name'] ?? 'Module Name';
    final formattedDate = _formatDate(widgetModule['created_at']);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.back,
                        color: AppColors.buttonPrimary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            moduleName,
                            style: const TextStyle(
                              fontFamily: AppTypography.headingFamily,
                              fontSize: AppTypography.sectionTitleSize,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              fontSize: AppTypography.helperSize,
                              color: AppColors.lightGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // chips
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [_buildNavigationDropdown(widgetModule)],
                ),
                const SizedBox(height: 16),

                // Single text area for call to action
                TextFormField(
                  minLines: 5,
                  controller: _controller,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: '',
                    hintStyle: const TextStyle(color: AppColors.hintText),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Call to action must be completed';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // complete
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          final repo = LearningModuleRepo();
                          final widgetModule = widget.existingModule ?? {};
                          final moduleId = widgetModule['id']?.toString();

                          if (moduleId == null || moduleId == 'null') {
                            showTopSnackBar(
                              context,
                              'Module ID missing – cannot save call to action',
                              isError: true,
                            );
                            return;
                          }

                          final ok = await repo.updateCallToAction(
                            id: moduleId,
                            callToAction: _controller.text.trim(),
                          );

                          if (ok) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const HomeShellScreen(),
                              ),
                              (route) => false,
                            );
                          } else {
                            showTopSnackBar(
                              context,
                              'Failed to save call to action',
                              isError: true,
                            );
                          }
                        } catch (e, st) {
                          debugPrint('Error saving call to action: $e');
                          debugPrint('Stack trace: $st');

                          showTopSnackBar(
                            context,
                            'Error saving call to action: $e',
                            isError: true,
                          );
                        }
                      }
                    },

                    child: const Text('Complete'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationDropdown(Map<String, dynamic> module) {
    return Container(
      height: MediaQuery.sizeOf(context).width >= 1000
          ? AppMetrics.controlHeight
          : 28,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedNavigation,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: AppColors.primary,
          ),
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.primary,
            fontSize: AppTypography.helperSize,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
          dropdownColor: AppColors.accent.withValues(alpha: 0.5),
          items: const [
            DropdownMenuItem(value: 'TITLE', child: Text('TITLE')),
            DropdownMenuItem(
              value: 'ANCHORING PHENOMENON',
              child: Text('ANCHORING PHENOMENON'),
            ),
            DropdownMenuItem(value: 'OBJECTIVE', child: Text('OBJECTIVE')),
            DropdownMenuItem(value: 'LEARNING', child: Text('LEARNING')),
            DropdownMenuItem(
              value: 'CONCEPT EXPLORATION',
              child: Text('CONCEPT EXPLORATION'),
            ),
            DropdownMenuItem(value: 'ACTIVITY', child: Text('ACTIVITY')),
            DropdownMenuItem(
              value: 'CALL TO ACTION', // 👈 exactly once
              child: Text('CALL TO ACTION'),
            ),
            if (assessmentFeaturesEnabled)
              DropdownMenuItem(value: 'ASSESSMENT', child: Text('ASSESSMENT')),
            DropdownMenuItem(value: 'SUMMARY', child: Text('SUMMARY')),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedNavigation = value;
            });

            if (value == 'TITLE') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreateTemplateScreen(existingModule: module),
                ),
              );
            } else if (value == 'ANCHORING PHENOMENON') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AnchoringPhenomenon(existingModule: module),
                ),
              );
            } else if (value == 'OBJECTIVE') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) => LearningObjectiveScreen(module: module),
                ),
              );
            } else if (value == 'LEARNING') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) => ThreeDLearning(module: module),
                ),
              );
            } else if (value == 'CONCEPT EXPLORATION') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ConceptExplorationScreen(module: module),
                ),
              );
            } else if (value == 'ACTIVITY') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) => ActivityScreen(module: module),
                ),
              );
            } else if (value == 'ASSESSMENT') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) => Assessment(module: module),
                ),
              );
            } else if (value == 'SUMMARY') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) => Summary(module: module),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
