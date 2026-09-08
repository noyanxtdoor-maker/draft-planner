import 'package:drift/drift.dart';

/// Test-only [QueryExecutor] that delegates every call to an inner executor
/// while recording each SQL statement issued through it.
///
/// Used by the S1A query-count tests to prove the Planner day read runs a
/// bounded number of set-based statements instead of one query per row.
final class CountingQueryExecutor implements QueryExecutor {
  CountingQueryExecutor(this._inner);

  final QueryExecutor _inner;

  /// Every SQL statement issued through this executor since construction or
  /// the last [clear] call, in execution order.
  final List<String> statements = <String>[];

  int get statementCount => statements.length;

  void clear() {
    statements.clear();
  }

  @override
  SqlDialect get dialect => _inner.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _inner.ensureOpen(user);

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) {
    statements.add(statement);
    return _inner.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    statements.add(statement);
    return _inner.runInsert(statement, args);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    statements.add(statement);
    return _inner.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    statements.add(statement);
    return _inner.runDelete(statement, args);
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    statements.add(statement);
    return _inner.runCustom(statement, args);
  }

  @override
  Future<void> runBatched(BatchedStatements statements) {
    return _inner.runBatched(statements);
  }

  @override
  TransactionExecutor beginTransaction() => _inner.beginTransaction();

  @override
  QueryExecutor beginExclusive() => _inner.beginExclusive();

  @override
  Future<void> close() => _inner.close();
}
