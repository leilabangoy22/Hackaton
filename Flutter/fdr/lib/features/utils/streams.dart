import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rxdart_ext/rxdart_ext.dart';
import './unit.dart';
import 'package:dart_either/dart_either.dart';

extension AsUnitSingleExtension<L, R> on Single<Either<L, R>> {
  Single<Either<L, Unit>> asUnit() => map((r) => r.map((_) => unit));
}

extension DebugMapStreamsExtension on Map<String, Stream<dynamic>> {
  List<StreamSubscription<dynamic>> debug() => entries
      .map((entry) => entry.value
          .listen((data) => debugPrint('[DEBUG] [${entry.key}] = $data')))
      .toList();
}

extension CastAsNullableStreamExtension<T> on Stream<T> {
  Stream<T?> castAsNullable() => cast<T?>();
}

extension CastAsNullableSingleExtension<T> on Single<T> {
  Single<T?> castAsNullable() => cast<T?>();
}

extension EitherExtensions<L, R> on Either<L, R> {
  Either<L, Unit> asUnit() => map((_) => unit);
}

extension StreamEitherExtensions<L, R> on Stream<Either<L, R>> {
  Stream<Either<L, Unit>> asUnit() => map((either) => either.asUnit());
}

extension SingleEitherExtensions<L, R> on Single<Either<L, R>> {
  Single<Either<L, Unit>> toUnit() => map((either) => either.asUnit());
}