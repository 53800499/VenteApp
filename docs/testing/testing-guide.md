# Guide des Tests Automatisés du Client Flutter

Ce document décrit l'écriture et l'exécution des tests automatisés sur l'application ARIKE.

---

## 1. Types de Tests Implémentés

1. **Tests Unitaires de Cas d'Utilisation (`usecase_test.dart`)** :
   Vérifient la logique métier pure en injectant des faux dépôts (Mocks créés avec `mocktail`).
2. **Tests de BLoC (`bloc_test.dart`)** :
   Testent les transitions d'état en réponse à des événements à l'aide de la bibliothèque officielle `bloc_test`.
3. **Tests de Base de Données Drift en Mémoire (`database_test.dart`)** :
   Instancient une base SQLite temporaire en mémoire RAM (`NativeDatabase.memory()`) pour tester les requêtes SQL locales sans écrire sur le disque physique.

---

## 2. Commandes de Test

```bash
cd frontend

# Exécuter l'ensemble des tests de la suite
flutter test

# Exécuter les tests avec couverture de code
flutter test --coverage
```

---

## 3. Exemple de Test de BLoC (`cash_sessions_bloc_test.dart`)

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('CashSessionsBloc', () {
    late MockCloseCashSessionUseCase mockCloseCashSessionUseCase;
    late CashSessionsBloc bloc;

    setUp(() {
      mockCloseCashSessionUseCase = MockCloseCashSessionUseCase();
      bloc = CashSessionsBloc(closeCashSessionUseCase: mockCloseCashSessionUseCase);
    });

    blocTest<CashSessionsBloc, CashSessionsState>(
      'émet [isLoading: true, successMessage: ...] lorsque la clôture réussit',
      build: () {
        when(() => mockCloseCashSessionUseCase.execute(any()))
            .thenAnswer((_) async => const Right(sampleClosedSession));
        return bloc;
      },
      act: (b) => b.add(const CloseCashSessionRequested(actualCash: 50000)),
      expect: () => [
        const CashSessionsState(isLoading: true),
        const CashSessionsState(isLoading: false, successMessage: 'Caisse clôturée avec succès !'),
      ],
    );
  });
}
```

