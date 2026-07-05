import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/benin_period_range.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sales_analysis_entities.dart';
import '../../domain/usecases/sales_analysis_usecases.dart';

part 'sales_analysis_event.dart';
part 'sales_analysis_state.dart';

class SalesAnalysisBloc extends Bloc<SalesAnalysisEvent, SalesAnalysisState> {
  SalesAnalysisBloc({
    required ListProductSalesAnalysis listProducts,
    required ListEmployeePriceAnalysis listEmployees,
    required ListCustomerSalesInsights listCustomers,
    required ListCategorySalesAnalysis listCategories,
    required GetMarginAnalysis getMargins,
    required ListPriceDeviationAnalysis listPriceDeviations,
    required GetSalesTrendAnalysis getTrends,
    required AuthSession session,
  })  : _listProducts = listProducts,
        _listEmployees = listEmployees,
        _listCustomers = listCustomers,
        _listCategories = listCategories,
        _getMargins = getMargins,
        _listPriceDeviations = listPriceDeviations,
        _getTrends = getTrends,
        _session = session,
        super(const SalesAnalysisState()) {
    on<SalesAnalysisLoadRequested>(_onLoad);
    on<SalesAnalysisPeriodChanged>(_onPeriodChanged);
    on<SalesAnalysisTabChanged>(_onTabChanged);
  }

  final ListProductSalesAnalysis _listProducts;
  final ListEmployeePriceAnalysis _listEmployees;
  final ListCustomerSalesInsights _listCustomers;
  final ListCategorySalesAnalysis _listCategories;
  final GetMarginAnalysis _getMargins;
  final ListPriceDeviationAnalysis _listPriceDeviations;
  final GetSalesTrendAnalysis _getTrends;
  final AuthSession _session;

  AuthSession get session => _session;

  int get shopId => _session.shop.id;

  Future<void> _onLoad(
    SalesAnalysisLoadRequested event,
    Emitter<SalesAnalysisState> emit,
  ) async {
    emit(state.copyWith(status: SalesAnalysisStatus.loading, clearError: true));
    await _fetch(emit);
  }

  Future<void> _onPeriodChanged(
    SalesAnalysisPeriodChanged event,
    Emitter<SalesAnalysisState> emit,
  ) async {
    emit(
      state.copyWith(
        query: state.query.copyWith(
          period: event.period,
          customFrom: event.customFrom,
          customTo: event.customTo,
        ),
        status: SalesAnalysisStatus.loading,
        clearError: true,
      ),
    );
    await _fetch(emit);
  }

  void _onTabChanged(
    SalesAnalysisTabChanged event,
    Emitter<SalesAnalysisState> emit,
  ) {
    emit(state.copyWith(tabIndex: event.index));
  }

  Future<void> _fetch(Emitter<SalesAnalysisState> emit) async {
    try {
      final period = resolveReportPeriod(
        preset: state.query.period,
        customFrom: state.query.customFrom,
        customTo: state.query.customTo,
      );
      final products = await _listProducts(
        shopId: shopId,
        query: state.query,
      );
      final employees = await _listEmployees(
        shopId: shopId,
        query: state.query,
      );
      final customers = await _listCustomers(
        shopId: shopId,
        query: state.query,
      );
      final categories = await _listCategories(
        shopId: shopId,
        query: state.query,
      );
      final margins = await _getMargins(
        shopId: shopId,
        query: state.query,
      );
      final priceDeviations = await _listPriceDeviations(
        shopId: shopId,
        query: state.query,
      );
      final trends = await _getTrends(
        shopId: shopId,
        query: state.query,
      );
      emit(
        state.copyWith(
          status: SalesAnalysisStatus.loaded,
          periodLabel: period.label,
          products: products,
          employees: employees,
          customers: customers,
          categories: categories,
          margins: margins,
          priceDeviations: priceDeviations,
          trends: trends,
          clearError: true,
        ),
      );
    } on Failure catch (error) {
      emit(
        state.copyWith(
          status: SalesAnalysisStatus.failure,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }
}
