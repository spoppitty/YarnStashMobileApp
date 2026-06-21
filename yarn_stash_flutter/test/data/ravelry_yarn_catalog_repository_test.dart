import 'dart:collection';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yarn_stash/data/repositories/ravelry_yarn_catalog_repository.dart';

class _FakeCatalogAuth implements RavelryCatalogAuth {
  _FakeCatalogAuth({this.hasSignedInUser = true});

  @override
  bool hasSignedInUser;

  final ensureIdTokenCalls = <bool>[];

  @override
  Future<void> ensureIdToken({bool forceRefresh = false}) async {
    ensureIdTokenCalls.add(forceRefresh);
  }
}

class _FakeCatalogFunctions implements RavelryYarnCatalogFunctions {
  _FakeCatalogFunctions(Iterable<Object> responses)
    : _responses = Queue<Object>.from(responses);

  final Queue<Object> _responses;
  final calls = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> call(Map<String, Object?> data) async {
    calls.add(data);
    final response = _responses.removeFirst();
    if (response is Exception) {
      throw response;
    }

    return Map<String, dynamic>.from(response as Map);
  }
}

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException({
    required super.code,
    required super.message,
  });
}

void main() {
  group('RavelryYarnCatalogRepository', () {
    test(
      'ensures an auth token before searching the callable catalog',
      () async {
        final auth = _FakeCatalogAuth();
        final functions = _FakeCatalogFunctions([
          {'yarns': []},
        ]);
        final repository = RavelryYarnCatalogRepository(
          auth: auth,
          functions: functions,
        );

        final results = await repository.searchYarns(query: 'rios');

        expect(results, isEmpty);
        expect(auth.ensureIdTokenCalls, [false]);
        expect(functions.calls.single, {
          'action': 'searchYarns',
          'query': 'rios',
          'page': 1,
          'pageSize': 20,
        });
      },
    );

    test(
      'refreshes the auth token once after an unauthenticated error',
      () async {
        final auth = _FakeCatalogAuth();
        final functions = _FakeCatalogFunctions([
          _TestFirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'Missing auth token.',
          ),
          {'yarns': []},
        ]);
        final repository = RavelryYarnCatalogRepository(
          auth: auth,
          functions: functions,
        );

        final results = await repository.searchYarns(query: 'rios');

        expect(results, isEmpty);
        expect(auth.ensureIdTokenCalls, [false, true]);
        expect(functions.calls, hasLength(2));
      },
    );

    test(
      'searches the catalog without a signed-in user',
      () async {
        final auth = _FakeCatalogAuth(hasSignedInUser: false);
        final functions = _FakeCatalogFunctions([
          {'yarns': []},
        ]);
        final repository = RavelryYarnCatalogRepository(
          auth: auth,
          functions: functions,
        );

        final results = await repository.searchYarns(query: 'rios');

        expect(results, isEmpty);
        expect(auth.ensureIdTokenCalls, [false]);
        expect(functions.calls.single, {
          'action': 'searchYarns',
          'query': 'rios',
          'page': 1,
          'pageSize': 20,
        });
      },
    );
  });
}
