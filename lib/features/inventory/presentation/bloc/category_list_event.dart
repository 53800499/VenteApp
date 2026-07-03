part of 'category_list_bloc.dart';

sealed class CategoryListEvent extends Equatable {
  const CategoryListEvent();

  @override
  List<Object?> get props => [];
}

class CategoryListLoadRequested extends CategoryListEvent {
  const CategoryListLoadRequested();
}

class CategoryListRefreshRequested extends CategoryListEvent {
  const CategoryListRefreshRequested();
}

class CategoryCreateRequested extends CategoryListEvent {
  const CategoryCreateRequested({
    required this.name,
    this.description,
  });

  final String name;
  final String? description;

  @override
  List<Object?> get props => [name, description];
}

class CategoryUpdateRequested extends CategoryListEvent {
  const CategoryUpdateRequested({
    required this.categoryId,
    required this.name,
    this.description,
  });

  final int categoryId;
  final String name;
  final String? description;

  @override
  List<Object?> get props => [categoryId, name, description];
}

class CategoryToggleActiveRequested extends CategoryListEvent {
  const CategoryToggleActiveRequested({
    required this.categoryId,
    required this.isActive,
  });

  final int categoryId;
  final bool isActive;

  @override
  List<Object?> get props => [categoryId, isActive];
}

class CategoryDeleteRequested extends CategoryListEvent {
  const CategoryDeleteRequested(this.categoryId);

  final int categoryId;

  @override
  List<Object?> get props => [categoryId];
}

class CategoryFeedbackDismissed extends CategoryListEvent {
  const CategoryFeedbackDismissed();
}
