import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/responsive/screen_type.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../voice_input/domain/entities/voice_draft.dart';
import '../../../voice_input/domain/entities/voice_navigation_seeds.dart';
import '../../../voice_input/domain/services/voice_intent_parser.dart';
import '../../../voice_input/presentation/cubit/voice_input_cubit.dart';
import '../../../voice_input/presentation/widgets/voice_capture_button.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/services/category_validation_service.dart';
import '../bloc/category_list_bloc.dart';
import '../widgets/inventory_feedback.dart';

class CategoryListPage extends StatelessWidget {
  const CategoryListPage({
    super.key,
    required this.session,
    this.voiceSeed,
    this.startGuidedVoiceCategory = false,
  });

  final AuthSession session;
  final VoiceCategorySeed? voiceSeed;
  final bool startGuidedVoiceCategory;

  bool get _canWrite => PermissionGuard.can(
        session.user.permissions,
        Permission.inventoryWrite,
      );

  @override
  Widget build(BuildContext context) {
    ensureVoiceInputDependencies();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => CategoryListBloc(
            listCategoriesWithStats: sl(),
            createCategory: sl(),
            updateCategory: sl(),
            deleteCategory: sl(),
            session: session,
          )..add(const CategoryListLoadRequested()),
        ),
        BlocProvider(create: (_) => sl<VoiceInputCubit>()),
      ],
      child: _CategoryListView(
        canWrite: _canWrite,
        voiceSeed: voiceSeed,
        startGuidedVoiceCategory: startGuidedVoiceCategory,
      ),
    );
  }
}

class CategoryFormResult {
  const CategoryFormResult({required this.name, this.description});

  final String name;
  final String? description;
}

class _CategoryListView extends StatefulWidget {
  const _CategoryListView({
    required this.canWrite,
    this.voiceSeed,
    this.startGuidedVoiceCategory = false,
  });

  final bool canWrite;
  final VoiceCategorySeed? voiceSeed;
  final bool startGuidedVoiceCategory;

  @override
  State<_CategoryListView> createState() => _CategoryListViewState();
}

class _CategoryListViewState extends State<_CategoryListView> {
  bool _guidedVoiceStarted = false;

  bool get canWrite => widget.canWrite;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final seed = widget.voiceSeed;
      if (seed != null && seed.hasAny) {
        unawaited(
          _showCategoryForm(
            context,
            initialName: seed.name,
            initialDescription: seed.description,
          ),
        );
        return;
      }
      if (widget.startGuidedVoiceCategory && !_guidedVoiceStarted) {
        _guidedVoiceStarted = true;
        unawaited(_runGuidedVoiceCategory());
      }
    });
  }

  Future<void> _runGuidedVoiceCategory() async {
    if (!canWrite || !mounted) return;
    final cubit = context.read<VoiceInputCubit>();
    const formatHint =
        'Dites : nom Boissons\n'
        'ou : catégorie Alimentation description Produits alimentaires';

    final spoken = await showVoiceWorkflowPromptDialog(
      context: context,
      cubit: cubit,
      question: 'Nouvelle catégorie',
      details: formatHint,
    );
    cubit.reset();
    if (!mounted || spoken == null || spoken.trim().isEmpty) return;

    final structured =
        VoiceIntentParser().parseStructuredCategoryLine(spoken);
    if (structured == null) {
      await showVoiceAssistantFailureDialog(
        context,
        message: 'Format non reconnu.\n\n$formatHint',
        kind: VoiceIntentKind.createCategory,
      );
      return;
    }

    await _showCategoryForm(
      context,
      initialName: structured.name,
      initialDescription: structured.description,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories'),
        actions: [
          if (canWrite)
            VoiceCaptureButton(
              expectedKind: VoiceIntentKind.createCategory,
              onCapture: _runGuidedVoiceCategory,
            ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _showCategoryForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Catégorie'),
            )
          : null,
      body: Column(
        children: [
          const VoiceListeningBanner(),
          Expanded(
            child: ResponsivePage(
              padding: EdgeInsets.zero,
              child: BlocConsumer<CategoryListBloc, CategoryListState>(
                listenWhen: (prev, curr) {
                  if (prev.errorMessage != curr.errorMessage &&
                      curr.errorMessage != null) {
                    return true;
                  }
                  if (prev.isSaving &&
                      !curr.isSaving &&
                      curr.errorMessage == null) {
                    return true;
                  }
                  return false;
                },
                listener: (context, state) async {
                  if (state.errorMessage != null) {
                    await InventoryFeedback.showErrorDialog(
                      context,
                      title: 'Action impossible',
                      message: state.errorMessage!,
                    );
                    if (context.mounted) {
                      context
                          .read<CategoryListBloc>()
                          .add(const CategoryFeedbackDismissed());
                    }
                    return;
                  }
                  await InventoryFeedback.showSuccess(
                    context: context,
                    title: 'Catégorie enregistrée',
                    message: 'Les modifications ont été appliquées.',
                  );
                },
                builder: (context, state) {
                  if (state.status == CategoryListStatus.loading &&
                      !state.isRefreshing) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: AppSpacing.md),
                          Text('Chargement des catégories…'),
                        ],
                      ),
                    );
                  }

                  if (state.status == CategoryListStatus.failure &&
                      state.categories.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.errorMessage ?? 'Erreur de chargement',
                            ),
                            const SizedBox(height: AppSpacing.md),
                            FilledButton(
                              onPressed: () => context
                                  .read<CategoryListBloc>()
                                  .add(const CategoryListLoadRequested()),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state.categories.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        context
                            .read<CategoryListBloc>()
                            .add(const CategoryListRefreshRequested());
                        await context
                            .read<CategoryListBloc>()
                            .stream
                            .firstWhere((s) => !s.isRefreshing);
                      },
                      child: EmptyListPlaceholder(
                        embedded: true,
                        icon: Icons.category_outlined,
                        title: 'Aucune catégorie',
                        subtitle: canWrite
                            ? 'Ajoutez votre première catégorie avec le bouton +'
                            : null,
                      ),
                    );
                  }

                  return Column(
                    children: [
                      if (state.isRefreshing || state.isSaving)
                        const LinearProgressIndicator(),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            context
                                .read<CategoryListBloc>()
                                .add(const CategoryListRefreshRequested());
                            await context
                                .read<CategoryListBloc>()
                                .stream
                                .firstWhere((s) => !s.isRefreshing);
                          },
                          child: ResponsiveBuilder(
                            builder: (context, screenType) {
                              final horizontal =
                                  Breakpoints.horizontalPadding(screenType);
                              final bottomPadding =
                                  screenType.isTablet ? AppSpacing.lg : 100.0;

                              return ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  horizontal,
                                  AppSpacing.md,
                                  horizontal,
                                  bottomPadding,
                                ),
                                itemCount: state.categories.length,
                                separatorBuilder: (_, index) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final item = state.categories[index];
                                  return _CategoryTile(
                                    item: item,
                                    canWrite: canWrite,
                                    onEdit: () => _showCategoryForm(
                                      context,
                                      category: item.category,
                                    ),
                                    onDelete: () =>
                                        _confirmDelete(context, item),
                                    onToggleActive: (active) =>
                                        _confirmToggleActive(
                                      context,
                                      item,
                                      active,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryForm(
    BuildContext context, {
    ProductCategory? category,
    String? initialName,
    String? initialDescription,
  }) async {
    final result = await showDialog<CategoryFormResult>(
      context: context,
      builder: (ctx) => _CategoryFormDialog(
        initialName: category?.name ?? initialName,
        initialDescription: category?.description ?? initialDescription,
        title:
            category == null ? 'Nouvelle catégorie' : 'Modifier la catégorie',
      ),
    );

    if (result == null || !context.mounted) return;

    final bloc = context.read<CategoryListBloc>();
    if (category == null) {
      bloc.add(CategoryCreateRequested(
        name: result.name,
        description: result.description,
      ));
    } else {
      bloc.add(CategoryUpdateRequested(
        categoryId: category.id,
        name: result.name,
        description: result.description,
      ));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryWithStats item,
  ) async {
    if (item.category.name == CategoryValidationService.defaultCategoryName) {
      InventoryFeedback.showInfo(
        context,
        'La catégorie « Général » ne peut pas être supprimée.',
      );
      return;
    }

    if (item.productCount > 0) {
      await InventoryFeedback.showErrorDialog(
        context,
        title: 'Suppression impossible',
        message:
            'Cette catégorie contient ${item.productCount} produit(s).',
      );
      return;
    }

    final confirmed = await InventoryFeedback.confirm(
      context: context,
      title: 'Supprimer la catégorie ?',
      message: 'Supprimer « ${item.category.name} » définitivement ?',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      context.read<CategoryListBloc>().add(
            CategoryDeleteRequested(item.category.id),
          );
    }
  }

  Future<void> _confirmToggleActive(
    BuildContext context,
    CategoryWithStats item,
    bool active,
  ) async {
    final confirmed = await InventoryFeedback.confirm(
      context: context,
      title: active ? 'Réactiver la catégorie' : 'Désactiver la catégorie',
      message: active
          ? 'Réactiver « ${item.category.name} » ?'
          : 'Désactiver « ${item.category.name} » ? Les produits restent associés.',
      confirmLabel: active ? 'Réactiver' : 'Désactiver',
    );
    if (confirmed == true && context.mounted) {
      context.read<CategoryListBloc>().add(
            CategoryToggleActiveRequested(
              categoryId: item.category.id,
              isActive: active,
            ),
          );
    }
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.item,
    required this.canWrite,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final CategoryWithStats item;
  final bool canWrite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final category = item.category;
    final isDefault =
        category.name == CategoryValidationService.defaultCategoryName;

    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: category.isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.category_outlined,
            color: category.isActive
                ? Theme.of(context).colorScheme.primary
                : AppColors.onSurfaceMuted,
          ),
        ),
        title: Text(
          category.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration:
                category.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          [
            if (category.description != null &&
                category.description!.isNotEmpty)
              category.description!,
            item.productCount == 1
                ? '1 produit'
                : '${item.productCount} produits',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: canWrite
            ? PopupMenuButton<String>(
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      onEdit();
                    case 'toggle':
                      onToggleActive(!category.isActive);
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Renommer'),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      category.isActive ? 'Désactiver' : 'Réactiver',
                    ),
                  ),
                  if (!isDefault)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer'),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.title,
    this.initialName,
    this.initialDescription,
  });

  final String title;
  final String? initialName;
  final String? initialDescription;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController =
        TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nom de la catégorie',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Min. 2 caractères';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optionnelle)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final description = _descriptionController.text.trim();
              Navigator.pop(
                context,
                CategoryFormResult(
                  name: _nameController.text.trim(),
                  description: description.isEmpty ? null : description,
                ),
              );
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
