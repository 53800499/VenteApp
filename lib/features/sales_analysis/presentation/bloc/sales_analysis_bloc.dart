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
    required ClearSalesAnalysisRemoteCache clearRemoteCache,
    required AuthSession session,
  })  : _listProducts = listProducts,
        _listEmployees = listEmployees,
        _listCustomers = listCustomers,
        _listCategories = listCategories,
        _getMargins = getMargins,
        _listPriceDeviations = listPriceDeviations,
        _getTrends = getTrends,
        _clearRemoteCache = clearRemoteCache,
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
  final ClearSalesAnalysisRemoteCache _clearRemoteCache;
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
    _clearRemoteCache();
    try {
      final period = resolveReportPeriod(
        preset: state.query.period,
        customFrom: state.query.customFrom,
        customTo: state.query.customTo,
      );

      final localResults = await Future.wait([
        _listProducts(shopId: shopId, query: state.query),
        _listEmployees(shopId: shopId, query: state.query),
        _listCustomers(shopId: shopId, query: state.query),
      ]);

      emit(
        state.copyWith(
          status: SalesAnalysisStatus.loaded,
          periodLabel: period.label,
          products: localResults[0] as List<ProductSalesSummary>,
          employees: localResults[1] as List<EmployeePricePerformance>,
          customers: localResults[2] as List<CustomerSalesInsight>,
          clearError: true,
        ),
      );

      final remoteResults = await Future.wait([
        _listCategories(shopId: shopId, query: state.query),
        _getMargins(shopId: shopId, query: state.query),
        _listPriceDeviations(shopId: shopId, query: state.query),
        _getTrends(shopId: shopId, query: state.query),
      ]);

      if (emit.isDone) return;

      emit(
        state.copyWith(
          status: SalesAnalysisStatus.loaded,
          periodLabel: period.label,
          products: localResults[0] as List<ProductSalesSummary>,
          employees: localResults[1] as List<EmployeePricePerformance>,
          customers: localResults[2] as List<CustomerSalesInsight>,
          categories: remoteResults[0] as List<CategorySalesSummary>,
          margins: remoteResults[1] as MarginSummary,
          priceDeviations: remoteResults[2] as List<PriceDeviationLine>,
          trends: remoteResults[3] as SalesTrendSummary,
          clearError: true,
        ),
      );
    } on Failure catch (error) {
      if (state.products.isNotEmpty) {
        emit(
          state.copyWith(
            status: SalesAnalysisStatus.loaded,
            errorMessage: friendlyErrorMessage(error),
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: SalesAnalysisStatus.failure,
          errorMessage: friendlyErrorMessage(error),
        ),
      );
    } catch (_) {
      if (state.products.isNotEmpty) {
        emit(
          state.copyWith(
            status: SalesAnalysisStatus.loaded,
            errorMessage: 'Certaines données n\'ont pas pu être actualisées.',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: SalesAnalysisStatus.failure,
          errorMessage: 'Impossible de charger l\'analyse des ventes.',
        ),
      );
    }
  }
}
