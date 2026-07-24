import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../customers/domain/entities/customer_entities.dart';
import '../../../customers/domain/usecases/customer_usecases.dart';
import '../../../customers/presentation/pages/customer_list_page.dart';
import '../../../cash_sessions/domain/usecases/cash_session_usecases.dart';
import '../../../cash_sessions/presentation/pages/cash_sessions_page.dart';
import '../../../debts/domain/entities/debt_entities.dart';
import '../../../debts/domain/usecases/debt_usecases.dart';
import '../../../debts/presentation/pages/record_debt_payment_page.dart';
import '../../../expenses/domain/entities/expense_entities.dart';
import '../../../expenses/domain/usecases/expense_usecases.dart';
import '../../../expenses/presentation/pages/expense_form_page.dart';
import '../../../fx_exchange/domain/entities/fx_exchange_entities.dart';
import '../../../fx_exchange/domain/usecases/fx_exchange_usecases.dart';
import '../../../fx_exchange/presentation/pages/fx_exchange_page.dart';
import '../../../inventory/domain/entities/inventory_entities.dart';
import '../../../inventory/domain/usecases/inventory_usecases.dart';
import '../../../procurement/domain/entities/procurement.dart';
import '../../../procurement/domain/repositories/procurement_repository.dart';
import '../../../procurement/presentation/bloc/procurement_bloc.dart';
import '../../../procurement/presentation/models/po_form_prefill.dart';
import '../../../procurement/presentation/pages/procurement_page.dart';
import '../../../procurement/presentation/pages/receive_items_page.dart';
import '../../../sales/domain/entities/sale_entities.dart';
import '../../../sales/domain/usecases/sale_usecases.dart';
import '../../../sales/presentation/pages/new_sale_page.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../inventory/presentation/pages/product_detail_page.dart';
import '../../../inventory/presentation/pages/product_form_page.dart';
import '../../../inventory/presentation/pages/product_list_page.dart';
import '../../../inventory/presentation/pages/category_list_page.dart';
import '../../data/speech_recognition_service.dart';
import '../../data/voice_input_preferences.dart';
import '../../domain/entities/voice_draft.dart';
import '../../domain/entities/voice_navigation_seeds.dart';
import '../../domain/services/voice_answer_formatter.dart';
import '../../domain/services/voice_failure_explainer.dart';
import '../../domain/services/voice_intent_parser.dart';
import '../../domain/workflows/voice_workflow_engine.dart';
import '../cubit/voice_input_cubit.dart';
import '../services/voice_audit_helper.dart';
import '../widgets/voice_capture_button.dart';

/// Orchestre l'assistant vocal global (catalogues → parse → preview → action).
/// V3 : session conversationnelle (Q&A + enchaînement).
/// Phase 2 : workflows opérationnels (dette multi, FX confirmé, réception PO).
/// Phase 3 : copilote (conseil stock, explication caisse).
class VoiceAssistantCoordinator {
  VoiceAssistantCoordinator({
    required this.session,
    required this.context,
  });

  final AuthSession session;
  final BuildContext context;

  Set<Permission> get _perms => session.user.permissions;

  Future<void> start() async {
    ensureVoiceInputDependencies();
    final prefs = sl<VoiceInputPreferences>();
    if (!prefs.isEnabled) {
      await _fail(
        'La saisie vocale est désactivée dans les paramètres.',
      );
      return;
    }

    final cubit = sl<VoiceInputCubit>();
    cubit.refreshEnabled();

    final catalogs = await _loadCatalogs();
    if (!context.mounted) return;

    var continueSession = true;
    while (continueSession && context.mounted) {
      continueSession = await _runOneTurn(cubit, catalogs);
      cubit.reset();
    }
  }

  /// Un tour d'écoute. Retourne `true` pour enchaîner une autre commande.
  Future<bool> _runOneTurn(
    VoiceInputCubit cubit,
    _CatalogBundle catalogs,
  ) async {
    var dialogOpen = true;

    Future<void> closeListeningDialog(BuildContext dialogContext) async {
      if (!dialogOpen) return;
      dialogOpen = false;
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
    }

    // Completer pour synchroniser la fin du tour avec la fermeture du dialog
    final turnDone = Completer<bool>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: cubit,
          child: _VoiceListeningDialog(
            onReady: () async {
              final cont = await _processTurn(
                cubit,
                catalogs,
                closeDialog: () => closeListeningDialog(dialogContext),
              );
              if (!turnDone.isCompleted) turnDone.complete(cont);
            },
            onCancel: () async {
              await cubit.cancelListening();
              await closeListeningDialog(dialogContext);
              if (!turnDone.isCompleted) turnDone.complete(false);
            },
          ),
        );
      },
    );

    // Attendre la fin du tour (réponse / preview), pas seulement la fermeture du micro.
    return turnDone.future;
  }

  Future<bool> _processTurn(
    VoiceInputCubit cubit,
    _CatalogBundle catalogs, {
    required Future<void> Function() closeDialog,
  }) async {
    try {
      cubit.markPreparing();
      if (!context.mounted) {
        await closeDialog();
        return false;
      }

      await cubit.captureAuto(
        products: catalogs.products,
        customers: catalogs.customers,
        categories: catalogs.categories,
        suppliers: catalogs.suppliers,
        openDebts: catalogs.openDebts,
        fxRates: catalogs.fxRates,
        fxSessionId: catalogs.fxSessionId,
      );

      if (!context.mounted) {
        await closeDialog();
        return false;
      }

      final state = cubit.state;
      if (state.status == VoiceInputStatus.cancelled) {
        await closeDialog();
        return false;
      }

      await closeDialog();

      if (state.status == VoiceInputStatus.error) {
        await _fail(
          state.errorMessage ??
              'La reconnaissance vocale a échoué. Réessayez près du micro.',
        );
        if (!context.mounted) return false;
        return showVoiceContinueDialog(context);
      }
      var draft = state.draft;
      if (draft == null) {
        await _fail(
          'Aucune commande vocale n’a pu être analysée. Réessayez.',
        );
        if (!context.mounted) return false;
        return showVoiceContinueDialog(context);
      }

      final clarified = await _maybeClarify(cubit, catalogs, draft);
      if (!context.mounted) return false;
      if (clarified == null) {
        return showVoiceContinueDialog(context);
      }
      draft = clarified;

      if (!_canAccess(draft.kind)) {
        await _fail(
          'Permission insuffisante pour « ${draft.kind.labelFr} ».',
          kind: draft.kind,
        );
        if (!context.mounted) return false;
        return showVoiceContinueDialog(context);
      }

      // ——— Q&A V3 ———
      if (draft.kind.isQuery) {
        draft = await _enrichQueryDraft(draft);
        if (!context.mounted) return false;
        final answer = formatVoiceAnswer(draft);
        final action = await showVoiceAnswerDialog(
          context,
          title: 'ARIKE Assistant — ${draft.kind.labelFr}',
          answer: answer,
          canOpenScreen: true,
        );
        if (!context.mounted) return false;
        if (action == VoiceAnswerAction.openScreen) {
          await _openQueryScreen(draft);
          if (!context.mounted) return false;
          return showVoiceContinueDialog(context);
        }
        if (action == VoiceAnswerAction.anotherCommand) return true;
        return false;
      }

      // ——— Vente / stock : formulaires guidés ———
      if (draft.kind == VoiceIntentKind.sale) {
        if (!context.mounted) return false;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NewSalePage(
              session: session,
              startGuidedVoiceSale: true,
            ),
          ),
        );
        if (!context.mounted) return false;
        return showVoiceContinueDialog(context);
      }
      if (draft.kind == VoiceIntentKind.createProduct) {
        if (!context.mounted) return false;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductFormPage(
              session: session,
              startGuidedVoiceProduct: true,
              voiceSeed: draft is VoiceCreateProductDraft
                  ? VoiceProductSeed(
                      name: draft.name,
                      priceSell: draft.priceSell,
                      priceBuy: draft.priceBuy,
                      categoryId: draft.categoryId,
                      sku: draft.sku,
                      quantity: draft.quantity,
                      alertThreshold: draft.alertThreshold,
                    )
                  : null,
            ),
          ),
        );
        if (!context.mounted) return false;
        return showVoiceContinueDialog(context);
      }
      if (draft.kind == VoiceIntentKind.createCategory) {
        if (!context.mounted) return false;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryListPage(
              session: session,
              startGuidedVoiceCategory: true,
              voiceSeed: draft is VoiceCreateCategoryDraft
                  ? VoiceCategorySeed(
                      name: draft.name,
                      description: draft.description,
                    )
                  : null,
            ),
          ),
        );
        if (!context.mounted) return false;
        return showVoiceContinueDialog(context);
      }

      // ——— Workflows Phase 2 ———
      if (draft.kind.usesWorkflow) {
        return _runWorkflowTurn(cubit, catalogs, draft);
      }

      // ——— Écritures V1/V2 ———
      final preview = await showVoicePreviewSheet(
        context: context,
        draft: draft,
      );
      if (!context.mounted) return false;

      if (preview == null || preview == VoicePreviewAction.cancel) {
        return showVoiceContinueDialog(context);
      }

      if (preview == VoicePreviewAction.editForm) {
        await _openForm(draft);
        if (!context.mounted) return false;
        return showVoiceContinueDialog(context);
      }

      try {
        await _save(draft);
      } catch (e) {
        if (context.mounted) {
          await _fail(
            'Enregistrement impossible.\n\n${friendlyErrorMessage(e)}',
          );
        }
      }
      if (!context.mounted) return false;
      return showVoiceContinueDialog(context);
    } on SpeechCancelledException {
      await closeDialog();
      return false;
    } catch (e) {
      await closeDialog();
      if (context.mounted) {
        final msg = friendlyErrorMessage(e);
        if (!msg.toLowerCase().contains('annul')) {
          await _fail(msg);
          if (context.mounted) return showVoiceContinueDialog(context);
        }
      }
      return false;
    }
  }

  /// Clarification si confiance faible / intents proches.
  Future<VoiceDraft?> _maybeClarify(
    VoiceInputCubit cubit,
    _CatalogBundle catalogs,
    VoiceDraft draft,
  ) async {
    final detection = cubit.state.detection;
    final options = <VoiceIntentKind>[];
    if (detection.kind != VoiceIntentKind.unknown) {
      options.add(detection.kind);
    }
    for (final alt in detection.alternatives) {
      if (!options.contains(alt.kind) &&
          alt.kind != VoiceIntentKind.unknown &&
          alt.rawScore >= 2) {
        options.add(alt.kind);
      }
    }

    final shouldAsk =
        (detection.needsClarification && options.length >= 2) ||
            (draft.kind == VoiceIntentKind.unknown && options.length >= 2);

    if (!shouldAsk) {
      if (draft.kind == VoiceIntentKind.unknown && options.length == 1) {
        cubit.reparseWithKind(
          kind: options.first,
          products: catalogs.products,
          customers: catalogs.customers,
          categories: catalogs.categories,
          suppliers: catalogs.suppliers,
          openDebts: catalogs.openDebts,
          fxRates: catalogs.fxRates,
          fxSessionId: catalogs.fxSessionId,
        );
        return cubit.state.draft;
      }
      return draft;
    }

    if (!context.mounted) return null;
    final chosen = await showVoiceClarifyDialog(
      context,
      transcript: draft.transcript,
      options: options.take(4).toList(),
      confidencePercent: detection.confidencePercent,
    );
    if (chosen == null) return null;

    cubit.reparseWithKind(
      kind: chosen,
      products: catalogs.products,
      customers: catalogs.customers,
      categories: catalogs.categories,
      suppliers: catalogs.suppliers,
      openDebts: catalogs.openDebts,
      fxRates: catalogs.fxRates,
      fxSessionId: catalogs.fxSessionId,
    );
    return cubit.state.draft;
  }

  Future<VoiceDraft> _enrichQueryDraft(VoiceDraft draft) async {
    switch (draft) {
      case VoiceStockQueryDraft d:
        return d;
      case VoiceStockAdviceDraft d:
        return _enrichStockAdvice(d);
      case VoiceFxBalanceQueryDraft d:
        return _enrichFxBalance(d);
      case VoiceFxMarginDraft d:
        return _enrichFxMargin(d);
      case VoiceExpenseReportDraft d:
        return _enrichExpenseReport(d);
      case VoiceCashExplainDraft d:
        return _enrichCashExplain(d);
      case VoiceDebtCriticalDraft d:
        return _enrichDebtCritical(d);
      default:
        return draft;
    }
  }

  Future<VoiceStockAdviceDraft> _enrichStockAdvice(
    VoiceStockAdviceDraft d,
  ) async {
    try {
      final list = await sl<ListProducts>()(
        shopId: session.shop.id,
        filters: const ProductListFilters(lowStockOnly: true),
        defaultAlertThreshold: 0,
      );
      final lines = <VoiceStockAdviceLine>[];
      for (final p in list) {
        final deficit = p.alertThreshold - p.quantityInStock;
        final suggested = p.alertThreshold + (deficit > 0 ? deficit : 1);
        lines.add(
          VoiceStockAdviceLine(
            productId: p.id,
            name: p.name,
            quantityInStock: p.quantityInStock,
            alertThreshold: p.alertThreshold,
            suggestedQty: suggested < 1 ? 1 : suggested,
          ),
        );
      }
      lines.sort((a, b) {
        final da = a.alertThreshold - a.quantityInStock;
        final db = b.alertThreshold - b.quantityInStock;
        return db.compareTo(da);
      });
      return d.copyWith(
        lines: lines.take(8).toList(),
        enriched: true,
      );
    } catch (_) {
      return d.copyWith(enriched: true, lines: const []);
    }
  }

  Future<VoiceCashExplainDraft> _enrichCashExplain(
    VoiceCashExplainDraft d,
  ) async {
    try {
      ensureCashSessionDependencies();
      final open = await sl<FindOpenCashSession>()(session: session);
      if (open == null) {
        return d.copyWith(hasOpenSession: false, enriched: true);
      }
      final live = await sl<GetCashSessionLiveTotals>()(
        session: session,
        cashSession: open,
      );
      final expected = open.openingCash +
          live.salesCash +
          live.depositsCash -
          live.expensesCash -
          live.withdrawalsCash;
      final drivers = buildCashExplainDrivers(
        openingCash: open.openingCash,
        salesCash: live.salesCash,
        expensesCash: live.expensesCash,
        withdrawalsCash: live.withdrawalsCash,
        depositsCash: live.depositsCash,
        saleCount: live.saleCount,
      );
      return d.copyWith(
        hasOpenSession: true,
        openingCash: open.openingCash,
        salesCash: live.salesCash,
        expensesCash: live.expensesCash,
        depositsCash: live.depositsCash,
        withdrawalsCash: live.withdrawalsCash,
        saleCount: live.saleCount,
        expectedCash: expected,
        driverLines: drivers,
        enriched: true,
      );
    } catch (_) {
      return d.copyWith(hasOpenSession: false, enriched: true);
    }
  }

  Future<VoiceDebtCriticalDraft> _enrichDebtCritical(
    VoiceDebtCriticalDraft d,
  ) async {
    try {
      final customers = await sl<ListCustomers>()(
        session: session,
        filters: const CustomerListFilters(hasDebtOnly: true),
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      const dayMs = 24 * 60 * 60 * 1000;
      final lines = <VoiceDebtCriticalLine>[];
      for (final c in customers) {
        if (!c.isCriticalDebt) continue;
        final days = c.lastActivityAt == null
            ? null
            : ((now - c.lastActivityAt!) / dayMs).floor();
        lines.add(
          VoiceDebtCriticalLine(
            customerId: c.id,
            customerName: c.name,
            balanceDue: c.balanceDue,
            openDebtsCount: c.openDebtsCount,
            daysSinceActivity: days,
          ),
        );
      }
      lines.sort((a, b) => b.balanceDue.compareTo(a.balanceDue));
      final top = lines.take(8).toList();
      final total = top.fold<int>(0, (sum, e) => sum + e.balanceDue);
      return d.copyWith(
        lines: top,
        totalBalanceDue: total,
        enriched: true,
      );
    } catch (_) {
      return d.copyWith(enriched: true, lines: const [], totalBalanceDue: 0);
    }
  }

  Future<VoiceFxBalanceQueryDraft> _enrichFxBalance(
    VoiceFxBalanceQueryDraft d,
  ) async {
    final code = d.currencyCode;
    if (code == null) return d;
    try {
      ensureFxExchangeDependencies();
      final open = await sl<FindOpenFxSession>()(shopId: session.shop.id);
      if (open == null) {
        return d.copyWith(hasOpenSession: false);
      }
      final balances = await sl<GetFxLiveBalances>()(
        shopId: session.shop.id,
        sessionId: open.id,
      );
      return d.copyWith(
        hasOpenSession: true,
        balanceAmount: balances[code] ?? 0,
      );
    } catch (_) {
      return d.copyWith(hasOpenSession: false);
    }
  }

  Future<VoiceFxMarginDraft> _enrichFxMargin(VoiceFxMarginDraft d) async {
    try {
      ensureFxExchangeDependencies();
      final open = await sl<FindOpenFxSession>()(shopId: session.shop.id);
      if (open == null) {
        return d.copyWith(hasOpenSession: false, enriched: true);
      }
      return d.copyWith(
        hasOpenSession: true,
        totalMarginFcfa: open.totalMarginFcfa,
        operationCount: open.operationCount,
        enriched: true,
      );
    } catch (_) {
      return d.copyWith(hasOpenSession: false, enriched: true);
    }
  }

  Future<VoiceExpenseReportDraft> _enrichExpenseReport(
    VoiceExpenseReportDraft d,
  ) async {
    try {
      ensureExpensesDependencies();
      final list = await sl<ListExpenses>()(
        shopId: session.shop.id,
        filters: ExpenseListFilters(fromMs: d.fromMs, toMs: d.toMs),
      );
      var total = 0;
      final lines = <VoiceExpenseReportLine>[];
      for (final e in list) {
        total += e.amount;
        lines.add(VoiceExpenseReportLine(title: e.title, amount: e.amount));
      }
      return d.copyWith(
        totalAmount: total,
        count: list.length,
        lines: lines,
      );
    } catch (_) {
      return d;
    }
  }

  Future<void> _openQueryScreen(VoiceDraft draft) async {
    if (!context.mounted) return;
    switch (draft) {
      case VoiceStockQueryDraft d:
        if (d.productId != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(
                session: session,
                productId: d.productId!,
              ),
            ),
          );
        } else {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductListPage(session: session),
            ),
          );
        }
      case VoiceStockAdviceDraft _:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductListPage(
              session: session,
              initialLowStockOnly: true,
            ),
          ),
        );
      case VoiceFxBalanceQueryDraft _:
        ensureFxExchangeDependencies();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FxExchangePage(session: session),
          ),
        );
      case VoiceFxMarginDraft _:
        ensureFxExchangeDependencies();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FxExchangePage(session: session),
          ),
        );
      case VoiceExpenseReportDraft _:
        ensureExpensesDependencies();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExpensesPage(session: session),
          ),
        );
      case VoiceCashExplainDraft _:
        ensureCashSessionDependencies();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CashSessionsPage(session: session),
          ),
        );
      case VoiceDebtCriticalDraft _:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomerListPage(session: session),
          ),
        );
      default:
        break;
    }
  }

  bool _canAccess(VoiceIntentKind kind) {
    return switch (kind) {
      VoiceIntentKind.sale =>
        PermissionGuard.can(_perms, Permission.salesCreate),
      VoiceIntentKind.createProduct || VoiceIntentKind.createCategory =>
        PermissionGuard.can(_perms, Permission.inventoryWrite),
      VoiceIntentKind.expense =>
        PermissionGuard.can(_perms, Permission.expensesCreate),
      VoiceIntentKind.debtPayment =>
        PermissionGuard.can(_perms, Permission.debtsPayment),
      VoiceIntentKind.fxOperation =>
        PermissionGuard.can(_perms, Permission.fxExchangeOperate),
      VoiceIntentKind.procurementOrder =>
        PermissionGuard.can(_perms, Permission.procurementCreate),
      VoiceIntentKind.receivePurchase =>
        PermissionGuard.can(_perms, Permission.procurementReceive),
      VoiceIntentKind.stockQuery || VoiceIntentKind.stockAdviceQuery =>
        PermissionGuard.can(_perms, Permission.inventoryRead),
      VoiceIntentKind.fxBalanceQuery || VoiceIntentKind.fxMarginQuery =>
        PermissionGuard.can(_perms, Permission.fxExchangeRead),
      VoiceIntentKind.expenseReportQuery =>
        PermissionGuard.can(_perms, Permission.expensesRead),
      VoiceIntentKind.cashExplainQuery =>
        PermissionGuard.can(_perms, Permission.cashSessionsRead),
      VoiceIntentKind.debtCriticalQuery =>
        PermissionGuard.can(_perms, Permission.customersRead) ||
            PermissionGuard.can(_perms, Permission.debtsRead),
      VoiceIntentKind.unknown => true,
    };
  }

  Future<bool> _runWorkflowTurn(
    VoiceInputCubit cubit,
    _CatalogBundle catalogs,
    VoiceDraft seedDraft,
  ) async {
    final workflow = _createWorkflow(seedDraft, catalogs);
    if (workflow == null) {
      await _fail(
        'Workflow indisponible pour « ${seedDraft.kind.labelFr} ».',
        kind: seedDraft.kind,
      );
      if (!context.mounted) return false;
      return showVoiceContinueDialog(context);
    }

    await workflow.bootstrap(seedDraft.transcript);
    while (context.mounted &&
        workflow.status == VoiceWorkflowStatus.asking) {
      final prompt = workflow.currentPrompt;
      if (prompt == null) break;
      final answer = await showVoiceWorkflowPromptDialog(
        context: context,
        cubit: cubit,
        question: prompt.question,
        details: prompt.details,
      );
      cubit.reset();
      if (!context.mounted) return false;
      if (answer == null || answer.trim().isEmpty) {
        workflow.cancel();
        break;
      }
      await workflow.advance(answer);
    }

    if (!context.mounted) return false;

    switch (workflow.status) {
      case VoiceWorkflowStatus.cancelled:
        return showVoiceContinueDialog(context);
      case VoiceWorkflowStatus.failed:
        await _fail(
          workflow.failureMessage ?? 'Workflow interrompu.',
          kind: workflow.kind,
        );
        if (!context.mounted) return false;
        return showVoiceContinueDialog(context);
      case VoiceWorkflowStatus.openForm:
        final target = workflow.formTarget;
        if (target is PurchaseOrder) {
          await _openReceiveItemsPage(target);
        }
        if (!context.mounted) return false;
        return showVoiceContinueDialog(context);
      case VoiceWorkflowStatus.readyBatch:
        final summary = workflow.batchSummary ?? '';
        final batch = workflow.batchDrafts;
        final preview = await showVoiceBatchPreviewSheet(
          context: context,
          title: 'Prévisualisation — ${workflow.kind.labelFr}',
          summary: summary,
          transcript: seedDraft.transcript,
        );
        if (!context.mounted) return false;
        if (preview != VoicePreviewAction.save) {
          return showVoiceContinueDialog(context);
        }
        try {
          for (final d in batch) {
            await _saveDebt(d, silent: true);
          }
          if (context.mounted) {
            _snack('${batch.length} paiement(s) enregistré(s)');
          }
        } catch (e) {
          if (context.mounted) {
            await _fail(
              'Enregistrement impossible.\n\n${friendlyErrorMessage(e)}',
            );
          }
        }
        if (!context.mounted) return false;
        return showVoiceContinueDialog(context);
      case VoiceWorkflowStatus.ready:
        final draft = workflow.draft;
        if (draft == null) {
          await _fail('Brouillon workflow vide.', kind: workflow.kind);
          if (!context.mounted) return false;
          return showVoiceContinueDialog(context);
        }
        // Toute vente passe par le panier / formulaire — sans exception.
        if (draft is VoiceSaleDraft) {
          await _openForm(draft);
          if (!context.mounted) return false;
          return showVoiceContinueDialog(context);
        }
        // FX : confirmation vocale déjà faite → enregistrer après preview UI.
        final preview = await showVoicePreviewSheet(
          context: context,
          draft: draft,
        );
        if (!context.mounted) return false;
        if (preview == null || preview == VoicePreviewAction.cancel) {
          return showVoiceContinueDialog(context);
        }
        if (preview == VoicePreviewAction.editForm) {
          await _openForm(draft);
          if (!context.mounted) return false;
          return showVoiceContinueDialog(context);
        }
        try {
          await _save(draft);
        } catch (e) {
          if (context.mounted) {
            await _fail(
              'Enregistrement impossible.\n\n${friendlyErrorMessage(e)}',
            );
          }
        }
        if (!context.mounted) return false;
        return showVoiceContinueDialog(context);
      case VoiceWorkflowStatus.asking:
        return showVoiceContinueDialog(context);
    }
  }

  VoiceWorkflow? _createWorkflow(VoiceDraft seed, _CatalogBundle catalogs) {
    switch (seed.kind) {
      case VoiceIntentKind.debtPayment:
        return DebtPaymentWorkflow(
          loadOpenDebts: (customerId) => sl<ListCustomerDebts>()(
            session: session,
            customerId: customerId,
            openOnly: true,
          ),
          customers: catalogs.customers,
        );
      case VoiceIntentKind.fxOperation:
        ensureFxExchangeDependencies();
        return FxExchangeWorkflow(
          shopId: session.shop.id,
          findOpenFxSession: ({required int shopId}) =>
              sl<FindOpenFxSession>()(shopId: shopId),
          previewFxOperation: ({
            required int shopId,
            required CreateFxOperationInput input,
            int? sessionId,
          }) =>
              sl<PreviewFxOperation>()(
            shopId: shopId,
            input: input,
            sessionId: sessionId,
          ),
          fxRates: catalogs.fxRates,
          seed: seed is VoiceFxDraft ? seed : null,
        );
      case VoiceIntentKind.receivePurchase:
        ensureProcurementDependencies();
        final repo = sl<ProcurementRepository>();
        return ReceivePoWorkflow(
          shopId: session.shop.id,
          listOrders: () => repo.listPurchaseOrders(shopId: session.shop.id),
          findOrder: (id) =>
              repo.findPurchaseOrder(shopId: session.shop.id, id: id),
        );
      default:
        return null;
    }
  }

  Future<void> _openReceiveItemsPage(PurchaseOrder po) async {
    if (!context.mounted) return;
    ensureProcurementDependencies();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => ProcurementBloc(
            repository: sl<ProcurementRepository>(),
            session: session,
          ),
          child: ReceiveItemsPage(po: po),
        ),
      ),
    );
  }

  Future<_CatalogBundle> _loadCatalogs() async {
    final products = <VoiceCatalogProduct>[];
    final customers = <VoiceCatalogCustomer>[];
    final categories = <VoiceCatalogCategory>[];
    final suppliers = <VoiceCatalogSupplier>[];
    final openDebts = <VoiceCatalogOpenDebt>[];
    final fxRates = <VoiceFxRateInfo>[];
    int? fxSessionId;

    try {
      final list = await sl<ListProducts>()(
        shopId: session.shop.id,
        filters: const ProductListFilters(),
      );
      for (final p in list) {
        products.add(
          VoiceCatalogProduct(
            id: p.id,
            name: p.name,
            priceSell: p.priceSell,
            quantityInStock: p.quantityInStock,
          ),
        );
      }
    } catch (_) {}

    try {
      final list = await sl<ListSaleCustomers>()(session: session);
      for (final c in list) {
        customers.add(VoiceCatalogCustomer(id: c.id, name: c.name));
      }
    } catch (_) {}

    try {
      ensureExpensesDependencies();
      final list = await sl<ListExpenseCategories>()(shopId: session.shop.id);
      for (final c in list) {
        categories.add(VoiceCatalogCategory(id: c.id, name: c.name));
      }
    } catch (_) {}

    try {
      ensureProcurementDependencies();
      final list =
          await sl<ProcurementRepository>().listSuppliers(shopId: session.shop.id);
      for (final s in list) {
        suppliers.add(VoiceCatalogSupplier(id: s.id, name: s.name));
      }
    } catch (_) {}

    // Dettes ouvertes par client (échantillon catalogue clients)
    try {
      for (final c in customers) {
        final debts = await sl<ListCustomerDebts>()(
          session: session,
          customerId: c.id,
          openOnly: true,
        );
        for (final d in debts) {
          if (!d.isRepayable) continue;
          openDebts.add(
            VoiceCatalogOpenDebt(
              id: d.id,
              customerId: d.customerId,
              customerName: c.name,
              amountRemaining: d.amountRemaining,
            ),
          );
        }
      }
    } catch (_) {}

    try {
      ensureFxExchangeDependencies();
      final sessionFx =
          await sl<FindOpenFxSession>()(shopId: session.shop.id);
      fxSessionId = sessionFx?.id;
      if (fxSessionId != null) {
        final rates = await sl<ListFxSessionRates>()(
          shopId: session.shop.id,
          sessionId: fxSessionId,
        );
        for (final r in rates) {
          fxRates.add(
            VoiceFxRateInfo(
              quoteCurrency: r.quoteCurrency,
              buyNumerator: r.buyRateNumerator,
              buyDenominator: r.buyRateDenominator,
              sellNumerator: r.sellRateNumerator,
              sellDenominator: r.sellRateDenominator,
            ),
          );
        }
      } else {
        final rates =
            await sl<ListFxLatestRates>()(shopId: session.shop.id);
        for (final r in rates) {
          fxRates.add(
            VoiceFxRateInfo(
              quoteCurrency: r.quoteCurrency,
              buyNumerator: r.buyRateNumerator,
              buyDenominator: r.buyRateDenominator,
              sellNumerator: r.sellRateNumerator,
              sellDenominator: r.sellRateDenominator,
            ),
          );
        }
      }
    } catch (_) {}

    return _CatalogBundle(
      products: products,
      customers: customers,
      categories: categories,
      suppliers: suppliers,
      openDebts: openDebts,
      fxRates: fxRates,
      fxSessionId: fxSessionId,
    );
  }

  Future<void> _save(VoiceDraft draft) async {
    if (!draft.canSave) {
      await _openForm(draft);
      return;
    }

    switch (draft) {
      case VoiceSaleDraft d:
        await _saveSale(d);
      case VoiceExpenseDraft d:
        await _saveExpense(d);
      case VoiceDebtPaymentDraft d:
        await _saveDebt(d);
      case VoiceFxDraft d:
        await _saveFx(d);
      case VoiceReceivePurchaseDraft d:
        await _saveReceive(d);
      case VoiceProcurementDraft _:
        await _openForm(draft);
      case VoiceCreateProductDraft _:
      case VoiceCreateCategoryDraft _:
        await _openForm(draft);
      case VoiceUnknownDraft d:
        await _fail(explainVoiceDraftFailure(d), kind: d.kind);
      case VoiceStockQueryDraft _:
      case VoiceStockAdviceDraft _:
      case VoiceFxBalanceQueryDraft _:
      case VoiceFxMarginDraft _:
      case VoiceExpenseReportDraft _:
      case VoiceCashExplainDraft _:
      case VoiceDebtCriticalDraft _:
        break;
    }
  }

  Future<void> _saveReceive(VoiceReceivePurchaseDraft draft) async {
    ensureProcurementDependencies();
    final poId = draft.poId;
    final itemId = draft.purchaseOrderItemId;
    final productId = draft.productId;
    final qty = draft.quantityReceived;
    final cost = draft.unitCost;
    if (poId == null ||
        itemId == null ||
        productId == null ||
        qty == null ||
        cost == null) {
      await _fail(explainVoiceDraftFailure(draft), kind: draft.kind);
      return;
    }
    final repo = sl<ProcurementRepository>();
    final receiptNumber = await repo.nextOrderReceiptNumber(
      shopId: session.shop.id,
    );
    await repo.receiveItems(
      shopId: session.shop.id,
      poId: poId,
      userId: session.user.id,
      receiptNumber: receiptNumber,
      receivedAt: DateTime.now().millisecondsSinceEpoch,
      notes: 'Réception vocale',
      items: [
        {
          'purchaseOrderItemId': itemId,
          'productId': productId,
          'quantityReceived': qty,
          'unitCost': cost,
        },
      ],
    );
    if (context.mounted) {
      _snack('Réception enregistrée (${draft.poNumber ?? poId})');
    }
  }

  Future<void> _saveSale(VoiceSaleDraft draft) async {
    final items = <SaleLineDraft>[];
    for (final line in draft.lines) {
      final unit = line.resolvedUnitPrice;
      final qty = line.quantity;
      final productId = line.productId;
      if (unit == null || qty == null || productId == null) {
        await _openForm(draft);
        return;
      }
      items.add(
        SaleLineDraft(
          productId: productId,
          quantity: qty,
          unitPrice: unit,
        ),
      );
    }
    if (items.isEmpty) {
      await _openForm(draft);
      return;
    }
    final total = draft.cartTotal ??
        items.fold<int>(0, (s, i) => s + i.unitPrice * i.quantity);
    final sale = await sl<CreateStandardSale>()(
      session: session,
      input: CreateStandardSaleInput(
        items: items,
        payment: PaymentDraft(
          method: PaymentMethod.cash,
          amountCash: total,
        ),
        customerId: draft.customerId,
        note: 'Saisie vocale',
      ),
    );
    await recordVoiceSaleAudit(
      shopId: session.shop.id,
      userId: session.user.id,
      saleId: sale.id,
      transcript: draft.transcript,
    );
    if (context.mounted) {
      _snack(
        items.length > 1
            ? 'Vente enregistrée (${items.length} produits)'
            : 'Vente enregistrée',
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NewSalePage(session: session),
        ),
      );
    }
  }

  Future<void> _saveExpense(VoiceExpenseDraft draft) async {
    ensureExpensesDependencies();
    final expense = await sl<CreateExpense>()(
      shopId: session.shop.id,
      userId: session.user.id,
      input: CreateExpenseInput(
        categoryId: draft.categoryId,
        title: draft.title!,
        amount: draft.amount!,
        expenseDate: DateTime.now().millisecondsSinceEpoch,
        paymentMethod: ExpensePaymentMethod.cash,
      ),
    );
    await recordVoiceExpenseAudit(
      shopId: session.shop.id,
      userId: session.user.id,
      expenseId: expense.id,
      transcript: draft.transcript,
    );
    if (context.mounted) _snack('Dépense enregistrée');
  }

  Future<void> _saveDebt(
    VoiceDebtPaymentDraft draft, {
    bool silent = false,
  }) async {
    final debtId = draft.debtId;
    final amount = draft.amount;
    if (debtId == null || amount == null) {
      await _openForm(draft);
      return;
    }
    final debt = await sl<GetDebt>()(session: session, debtId: debtId);
    final result = await sl<RecordDebtPayment>()(
      session: session,
      debtId: debtId,
      input: RecordDebtPaymentInput(
        amount: amount,
        method: DebtRepaymentMethod.cash,
        amountTendered: amount,
        note: 'Saisie vocale',
      ),
    );
    await recordVoiceDebtPaymentAudit(
      shopId: session.shop.id,
      userId: session.user.id,
      debtId: debt.id,
      transcript: draft.transcript,
      amount: result.amount,
    );
    if (!silent && context.mounted) _snack('Paiement de dette enregistré');
  }

  Future<void> _saveFx(VoiceFxDraft draft) async {
    final sessionId = draft.sessionId;
    if (sessionId == null ||
        draft.fromAmount == null ||
        draft.toAmount == null ||
        draft.fromCurrency == null ||
        draft.toCurrency == null ||
        draft.operationTypeCode == null) {
      await _openForm(draft);
      return;
    }
    final op = draft.operationTypeCode == 'buy'
        ? FxOperationType.buy
        : FxOperationType.sell;
    final canAdjust = PermissionGuard.can(
      _perms,
      Permission.fxExchangeAdjust,
    );
    final created = await sl<CreateFxOperation>()(
      shopId: session.shop.id,
      userId: session.user.id,
      sessionId: sessionId,
      allowNegativeBalance: canAdjust,
      input: CreateFxOperationInput(
        operationType: op,
        fromCurrency: draft.fromCurrency!,
        fromAmount: draft.fromAmount!,
        toCurrency: draft.toCurrency!,
        toAmount: draft.toAmount!,
        note: 'Saisie vocale',
      ),
    );
    await recordVoiceFxAudit(
      shopId: session.shop.id,
      userId: session.user.id,
      operationId: created.id,
      transcript: draft.transcript,
    );
    if (context.mounted) _snack('Opération de change enregistrée');
  }

  Future<void> _openForm(VoiceDraft draft) async {
    if (!context.mounted) return;
    switch (draft) {
      case VoiceSaleDraft d:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NewSalePage(
              session: session,
              voiceSeed: VoiceSaleSeed(
                customerId: d.customerId,
                lines: [
                  for (final line in d.lines)
                    if (line.productId != null)
                      VoiceSaleLineSeed(
                        productId: line.productId,
                        quantity: line.quantity,
                        unitPrice: line.resolvedUnitPrice,
                      ),
                ],
                productId: d.productId,
                quantity: d.quantity,
                unitPrice: d.resolvedUnitPrice,
              ),
            ),
          ),
        );
      case VoiceExpenseDraft d:
        ensureExpensesDependencies();
        final cats =
            await sl<ListExpenseCategories>()(shopId: session.shop.id);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExpenseFormPage(
              session: session,
              categories: cats,
              voiceSeed: VoiceExpenseSeed(
                title: d.title,
                amount: d.amount,
                categoryId: d.categoryId,
              ),
            ),
          ),
        );
      case VoiceDebtPaymentDraft d:
        if (d.debtId != null) {
          final debt = await sl<GetDebt>()(session: session, debtId: d.debtId!);
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RecordDebtPaymentPage(
                session: session,
                debt: debt,
                customerName: d.customerName ?? 'Client',
                voiceSeed: VoiceDebtPaymentSeed(amount: d.amount),
              ),
            ),
          );
        } else {
          await _fail(explainVoiceDraftFailure(d), kind: d.kind);
        }
      case VoiceFxDraft d:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FxExchangePage(
              session: session,
              voiceSeed: VoiceFxSeed(
                operationTypeCode: d.operationTypeCode,
                foreignCurrency: d.foreignCurrency,
                fromAmount: d.fromAmount,
              ),
            ),
          ),
        );
      case VoiceProcurementDraft d:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProcurementPage(
              session: session,
              voicePoPrefill: d.productId == null
                  ? null
                  : PoFormPrefill(
                      productId: d.productId!,
                      productName: d.productName ?? 'Produit',
                      suggestedQuantity: d.quantity ?? 1,
                      supplierId: d.supplierId,
                    ),
            ),
          ),
        );
      case VoiceReceivePurchaseDraft d:
        if (d.poId != null) {
          ensureProcurementDependencies();
          final po = await sl<ProcurementRepository>().findPurchaseOrder(
            shopId: session.shop.id,
            id: d.poId!,
          );
          if (po != null && context.mounted) {
            await _openReceiveItemsPage(po);
            return;
          }
        }
        await _fail(explainVoiceDraftFailure(d), kind: d.kind);
      case VoiceCreateProductDraft d:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductFormPage(
              session: session,
              startGuidedVoiceProduct: d.name == null,
              voiceSeed: VoiceProductSeed(
                name: d.name,
                priceSell: d.priceSell,
                priceBuy: d.priceBuy,
                categoryId: d.categoryId,
                sku: d.sku,
                quantity: d.quantity,
                alertThreshold: d.alertThreshold,
              ),
            ),
          ),
        );
      case VoiceCreateCategoryDraft d:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryListPage(
              session: session,
              startGuidedVoiceCategory: d.name == null,
              voiceSeed: VoiceCategorySeed(
                name: d.name,
                description: d.description,
              ),
            ),
          ),
        );
      case VoiceUnknownDraft d:
        await _fail(explainVoiceDraftFailure(d), kind: d.kind);
      case VoiceStockQueryDraft _:
      case VoiceStockAdviceDraft _:
      case VoiceFxBalanceQueryDraft _:
      case VoiceFxMarginDraft _:
      case VoiceExpenseReportDraft _:
      case VoiceCashExplainDraft _:
      case VoiceDebtCriticalDraft _:
        await _openQueryScreen(draft);
    }
  }

  void _snack(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _fail(
    String message, {
    VoiceIntentKind kind = VoiceIntentKind.unknown,
  }) async {
    if (!context.mounted) return;
    await showVoiceAssistantFailureDialog(
      context,
      message: message,
      kind: kind,
    );
  }
}

class _CatalogBundle {
  const _CatalogBundle({
    required this.products,
    required this.customers,
    required this.categories,
    required this.suppliers,
    required this.openDebts,
    required this.fxRates,
    this.fxSessionId,
  });

  final List<VoiceCatalogProduct> products;
  final List<VoiceCatalogCustomer> customers;
  final List<VoiceCatalogCategory> categories;
  final List<VoiceCatalogSupplier> suppliers;
  final List<VoiceCatalogOpenDebt> openDebts;
  final List<VoiceFxRateInfo> fxRates;
  final int? fxSessionId;
}

class _VoiceListeningDialog extends StatefulWidget {
  const _VoiceListeningDialog({
    required this.onReady,
    required this.onCancel,
  });

  final Future<void> Function() onReady;
  final Future<void> Function() onCancel;

  @override
  State<_VoiceListeningDialog> createState() => _VoiceListeningDialogState();
}

class _VoiceListeningDialogState extends State<_VoiceListeningDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReady());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assistant ARIKE'),
      content: BlocBuilder<VoiceInputCubit, VoiceInputState>(
        builder: (context, state) {
          return VoiceListenStatusPanel(
            status: state.status,
            partialText: state.partialText,
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => widget.onCancel(),
          child: const Text('Annuler'),
        ),
        BlocBuilder<VoiceInputCubit, VoiceInputState>(
          buildWhen: (p, c) => p.status != c.status,
          builder: (context, state) {
            if (state.status != VoiceInputStatus.listening) {
              return const SizedBox.shrink();
            }
            return FilledButton(
              onPressed: () =>
                  context.read<VoiceInputCubit>().finishListening(),
              child: const Text('J\'ai fini'),
            );
          },
        ),
      ],
    );
  }
}
