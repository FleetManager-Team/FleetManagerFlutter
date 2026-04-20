import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:mocktail/mocktail.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}
class MockStorageFileApi extends Mock implements StorageFileApi {}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  FakePostgrestFilterBuilder(this._future);

  final Future<T> _future;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return _future.then(onValue, onError: onError);
  }

  @override
  PostgrestFilterBuilder<T> eq(String column, dynamic value) => this;

  @override
  PostgrestFilterBuilder<T> neq(String column, dynamic value) => this;

  @override
  PostgrestFilterBuilder<T> order(String column,
          {bool ascending = false,
          bool nullsFirst = false,
          String? foreignTable}) =>
      this;

  @override
  PostgrestTransformBuilder<T> maybeSingle() => this;

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? foreignTable}) => this;
}

FakePostgrestFilterBuilder<T> futureBuilder<T>(T value) {
  return FakePostgrestFilterBuilder<T>(Future<T>.value(value));
}

class FakeXFile extends Fake implements XFile {
  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);
}
