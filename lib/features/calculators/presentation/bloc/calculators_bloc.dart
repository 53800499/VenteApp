import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/calculator_entities.dart';
import '../../domain/repositories/calculators_repository.dart';

// --- Events ---
abstract class CalculatorsEvent extends Equatable {
  const CalculatorsEvent();

  @override
  List<Object?> get props => [];
}

class CalculatorsInitRequested extends CalculatorsEvent {
  const CalculatorsInitRequested({required this.shopId});
  final int shopId;

  @override
  List<Object?> get props => [shopId];
}

class ToggleCalculatorsModuleRequested extends CalculatorsEvent {
  const ToggleCalculatorsModuleRequested({
    required this.shopId,
    required this.enabled,
  });
  final int shopId;
  final bool enabled;

  @override
  List<Object?> get props => [shopId, enabled];
}

class SaveProductConfigRequested extends CalculatorsEvent {
  const SaveProductConfigRequested({required this.config});
  final CalculatorProductData config;

  @override
  List<Object?> get props => [config];
}

class LogCalculationRequested extends CalculatorsEvent {
  const LogCalculationRequested({required this.entry});
  final CalculatorHistoryEntry entry;

  @override
  List<Object?> get props => [entry];
}

// --- State ---
class CalculatorsState extends Equatable {
  const CalculatorsState({
    this.status = 'initial',
    this.isEnabled = false,
    this.configs = const [],
    this.history = const [],
    this.errorMessage,
  });

  final String status; // 'initial' | 'loading' | 'success' | 'failure'
  final bool isEnabled;
  final List<CalculatorProductData> configs;
  final List<CalculatorHistoryEntry> history;
  final String? errorMessage;

  CalculatorsState copyWith({
    String? status,
    bool? isEnabled,
    List<CalculatorProductData>? configs,
    List<CalculatorHistoryEntry>? history,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CalculatorsState(
      status: status ?? this.status,
      isEnabled: isEnabled ?? this.isEnabled,
      configs: configs ?? this.configs,
      history: history ?? this.history,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, isEnabled, configs, history, errorMessage];
}

// --- BLoC ---
class CalculatorsBloc extends Bloc<CalculatorsEvent, CalculatorsState> {
  CalculatorsBloc({
    required CalculatorsRepository repository,
  })  : _repo = repository,
        super(const CalculatorsState()) {
    on<CalculatorsInitRequested>(_onInit);
    on<ToggleCalculatorsModuleRequested>(_onToggle);
    on<SaveProductConfigRequested>(_onSaveProductConfig);
    on<LogCalculationRequested>(_onLogCalculation);
  }

  final CalculatorsRepository _repo;

  Future<void> _onInit(
    CalculatorsInitRequested event,
    Emitter<CalculatorsState> emit,
  ) async {
    emit(state.copyWith(status: 'loading'));
    try {
      final isEnabled = await _repo.isModuleEnabled(shopId: event.shopId);
      final configs = await _repo.getProductConfigs(shopId: event.shopId);
      final history = await _repo.getHistory(shopId: event.shopId);

      emit(state.copyWith(
        status: 'success',
        isEnabled: isEnabled,
        configs: configs,
        history: history,
      ));
    } on Failure catch (e) {
      emit(state.copyWith(status: 'failure', errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
        status: 'failure',
        errorMessage: friendlyErrorMessage(e),
      ));
    }
  }

  Future<void> _onToggle(
    ToggleCalculatorsModuleRequested event,
    Emitter<CalculatorsState> emit,
  ) async {
    emit(state.copyWith(status: 'loading'));
    try {
      await _repo.toggleModule(shopId: event.shopId, enabled: event.enabled);
      final configs = await _repo.getProductConfigs(shopId: event.shopId);
      final history = await _repo.getHistory(shopId: event.shopId);

      emit(state.copyWith(
        status: 'success',
        isEnabled: event.enabled,
        configs: configs,
        history: history,
      ));
    } on Failure catch (e) {
      emit(state.copyWith(
        status: 'failure',
        errorMessage: e.message,
        isEnabled: !event.enabled,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: 'failure',
        errorMessage: friendlyErrorMessage(e),
        isEnabled: !event.enabled,
      ));
    }
  }

  Future<void> _onSaveProductConfig(
    SaveProductConfigRequested event,
    Emitter<CalculatorsState> emit,
  ) async {
    try {
      await _repo.saveProductConfig(config: event.config);
      final configs = await _repo.getProductConfigs(shopId: event.config.shopId);
      emit(state.copyWith(configs: configs));
    } catch (_) {
      // Offline: fail silently or let it sync
    }
  }

  Future<void> _onLogCalculation(
    LogCalculationRequested event,
    Emitter<CalculatorsState> emit,
  ) async {
    try {
      await _repo.saveCalculation(entry: event.entry);
      final history = await _repo.getHistory(shopId: event.entry.shopId);
      emit(state.copyWith(
        history: history,
        status: 'saved',
        clearError: true,
      ));
    } on Failure catch (e) {
      emit(state.copyWith(status: 'failure', errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
        status: 'failure',
        errorMessage: friendlyErrorMessage(e),
      ));
    }
  }
}
