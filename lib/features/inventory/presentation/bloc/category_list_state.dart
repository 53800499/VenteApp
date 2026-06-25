part of 'category_list_bloc.dart';

enum CategoryListStatus { initial, loading, loaded, failure }

class CategoryListState extends Equatable {
  const CategoryListState({
    this.status = CategoryListStatus.initial,
    this.categories = const [],
    this.errorMessage,
    this.isRefreshing = false,
    this.isSaving = false,
  });

  final CategoryListStatus status;
  final List<CategoryWithStats> categories;
  final String? errorMessage;
  final bool isRefreshing;
  final bool isSaving;

  CategoryListState copyWith({
    CategoryListStatus? status,
    List<CategoryWithStats>? categories,
    String? errorMessage,
    bool? isRefreshing,
    bool? isSaving,
    bool clearError = false,
  }) {
    return CategoryListState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  @override
  List<Object?> get props => [
        status,
        categories,
        errorMessage,
        isRefreshing,
        isSaving,
      ];
}
