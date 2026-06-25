import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/usecases/inventory_usecases.dart';

part 'category_list_event.dart';
part 'category_list_state.dart';

class CategoryListBloc extends Bloc<CategoryListEvent, CategoryListState> {
  CategoryListBloc({
    required ListCategoriesWithStats listCategoriesWithStats,
    required CreateCategory createCategory,
    required UpdateCategory updateCategory,
    required DeleteCategory deleteCategory,
    required AuthSession session,
  })  : _listCategoriesWithStats = listCategoriesWithStats,
        _createCategory = createCategory,
        _updateCategory = updateCategory,
        _deleteCategory = deleteCategory,
        _session = session,
        super(const CategoryListState()) {
    on<CategoryListLoadRequested>(_onLoad);
    on<CategoryListRefreshRequested>(_onRefresh);
    on<CategoryCreateRequested>(_onCreate);
    on<CategoryUpdateRequested>(_onUpdate);
    on<CategoryDeleteRequested>(_onDelete);
    on<CategoryToggleActiveRequested>(_onToggleActive);
  }

  final ListCategoriesWithStats _listCategoriesWithStats;
  final CreateCategory _createCategory;
  final UpdateCategory _updateCategory;
  final DeleteCategory _deleteCategory;
  final AuthSession _session;

  int get _shopId => _session.shop.id;

  Future<void> _onLoad(
    CategoryListLoadRequested event,
    Emitter<CategoryListState> emit,
  ) async {
    emit(state.copyWith(status: CategoryListStatus.loading, clearError: true));
    await _fetch(emit);
  }

  Future<void> _onRefresh(
    CategoryListRefreshRequested event,
    Emitter<CategoryListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    await _fetch(emit);
  }

  Future<void> _fetch(Emitter<CategoryListState> emit) async {
    try {
      final categories = await _listCategoriesWithStats(shopId: _shopId);
      emit(
        state.copyWith(
          status: CategoryListStatus.loaded,
          categories: categories,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: CategoryListStatus.failure,
          errorMessage: e.message,
          isRefreshing: false,
        ),
      );
    }
  }

  Future<void> _onCreate(
    CategoryCreateRequested event,
    Emitter<CategoryListState> emit,
  ) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _createCategory(
        shopId: _shopId,
        input: CreateCategoryInput(name: event.name),
      );
      emit(state.copyWith(isSaving: false));
      await _fetch(emit);
    } on Failure catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: e.message));
    }
  }

  Future<void> _onUpdate(
    CategoryUpdateRequested event,
    Emitter<CategoryListState> emit,
  ) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _updateCategory(
        shopId: _shopId,
        categoryId: event.categoryId,
        input: UpdateCategoryInput(name: event.name),
      );
      emit(state.copyWith(isSaving: false));
      await _fetch(emit);
    } on Failure catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: e.message));
    }
  }

  Future<void> _onToggleActive(
    CategoryToggleActiveRequested event,
    Emitter<CategoryListState> emit,
  ) async {
    try {
      await _updateCategory(
        shopId: _shopId,
        categoryId: event.categoryId,
        input: UpdateCategoryInput(isActive: event.isActive),
      );
      await _fetch(emit);
    } on Failure catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> _onDelete(
    CategoryDeleteRequested event,
    Emitter<CategoryListState> emit,
  ) async {
    try {
      await _deleteCategory(shopId: _shopId, categoryId: event.categoryId);
      await _fetch(emit);
    } on Failure catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }
}
