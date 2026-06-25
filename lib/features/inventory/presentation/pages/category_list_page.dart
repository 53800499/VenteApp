import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/responsive/screen_type.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/services/category_validation_service.dart';
import '../bloc/category_list_bloc.dart';

class CategoryListPage extends StatelessWidget {
  const CategoryListPage({super.key, required this.session});

  final AuthSession session;

  bool get _canWrite => PermissionGuard.can(
        session.user.permissions,
        Permission.inventoryWrite,
      );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CategoryListBloc(
        listCategoriesWithStats: sl(),
        createCategory: sl(),
        updateCategory: sl(),
        deleteCategory: sl(),
        session: session,
      )..add(const CategoryListLoadRequested()),
      child: _CategoryListView(canWrite: _canWrite),
    );
  }
}

class _CategoryListView extends StatelessWidget {
  const _CategoryListView({required this.canWrite});

  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catégories')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _showCategoryForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Catégorie'),
            )
          : null,
      body: ResponsivePage(
        padding: EdgeInsets.zero,
        child: BlocConsumer<CategoryListBloc, CategoryListState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          if (state.status == CategoryListStatus.loading && !state.isRefreshing) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == CategoryListStatus.failure &&
              state.categories.isEmpty) {
            return Center(
              child: FilledButton(
                onPressed: () => context
                    .read<CategoryListBloc>()
                    .add(const CategoryListLoadRequested()),
                child: const Text('Réessayer'),
              ),
            );
          }

          if (state.categories.isEmpty) {
            return const Center(child: Text('Aucune catégorie'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<CategoryListBloc>()
                  .add(const CategoryListRefreshRequested());
              await context.read<CategoryListBloc>().stream.firstWhere(
                    (s) => !s.isRefreshing,
                  );
            },
            child: ResponsiveBuilder(
              builder: (context, screenType) {
                final horizontal = Breakpoints.horizontalPadding(screenType);
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
                      onDelete: () => _confirmDelete(context, item),
                      onToggleActive: (active) {
                        context.read<CategoryListBloc>().add(
                              CategoryToggleActiveRequested(
                                categoryId: item.category.id,
                                isActive: active,
                              ),
                            );
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      ),
    );
  }

  Future<void> _showCategoryForm(
    BuildContext context, {
    ProductCategory? category,
  }) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _CategoryFormDialog(
        initialName: category?.name,
        title: category == null ? 'Nouvelle catégorie' : 'Modifier la catégorie',
      ),
    );

    if (name == null || !context.mounted) return;

    final bloc = context.read<CategoryListBloc>();
    if (category == null) {
      bloc.add(CategoryCreateRequested(name));
    } else {
      bloc.add(CategoryUpdateRequested(categoryId: category.id, name: name));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryWithStats item,
  ) async {
    if (item.category.name == CategoryValidationService.defaultCategoryName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La catégorie « Général » ne peut pas être supprimée.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text(
          item.productCount > 0
              ? 'Cette catégorie contient ${item.productCount} produit(s) et ne peut pas être supprimée.'
              : 'Supprimer « ${item.category.name} » définitivement ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          if (item.productCount == 0)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<CategoryListBloc>().add(
            CategoryDeleteRequested(item.category.id),
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
          item.productCount == 1
              ? '1 produit'
              : '${item.productCount} produits',
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
  });

  final String title;
  final String? initialName;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _nameController.text.trim());
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
