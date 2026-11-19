# Référentiel des Tables Locales Drift

Ce document recense les tables locales déclarées dans la base de données Drift SQLite (`app_database.dart`) de l'application cliente.

---

## 1. Table `ProductsTable`
- `id` : `TextColumn` (UUID)
- `shopId` : `TextColumn`
- `name` : `TextColumn`
- `barcode` : `TextColumn.nullable()`
- `purchasePrice` : `RealColumn`
- `sellingPrice` : `RealColumn`
- `currentStock` : `RealColumn`
- `minStockAlert` : `IntColumn`
- `isSynced` : `BoolColumn`
- `updatedAt` : `DateTimeColumn`

---

## 2. Table `SalesTable`
- `id` : `TextColumn` (UUID)
- `shopId` : `TextColumn`
- `cashSessionId` : `TextColumn.nullable()`
- `customerId` : `TextColumn.nullable()`
- `receiptNumber` : `TextColumn` (ex : `#VT-2026-089`)
- `totalAmount` : `RealColumn`
- `discountAmount` : `RealColumn`
- `finalAmount` : `RealColumn`
- `paidAmount` : `RealColumn`
- `debtAmount` : `RealColumn`
- `paymentMethod` : `TextColumn` (`CASH`, `MOMO`, `CREDIT`, etc.)
- `createdAt` : `DateTimeColumn`
- `isSynced` : `BoolColumn`

---

## 3. Table `CashMovementsTable`
- `id` : `TextColumn` (UUID)
- `sessionId` : `TextColumn`
- `type` : `TextColumn` (`INTAKE`, `DROP`, `EXPENSE`)
- `amount` : `RealColumn`
- `reason` : `TextColumn`
- `createdAt` : `DateTimeColumn`
- `isSynced` : `BoolColumn`

