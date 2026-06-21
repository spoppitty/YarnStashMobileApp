import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ravelry_yarn.dart';

class RavelryCatalogException implements Exception {
  const RavelryCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RavelryCatalogNotConfiguredException extends RavelryCatalogException {
  const RavelryCatalogNotConfiguredException()
    : super(
        'Configure Ravelry API credentials as Firebase Functions secrets and '
        'redeploy the function.',
      );
}

abstract interface class RavelryYarnCatalogFunctions {
  Future<Map<String, dynamic>> call(Map<String, Object?> data);
}

abstract interface class RavelryCatalogAuth {
  bool get hasSignedInUser;

  Future<void> ensureIdToken({bool forceRefresh = false});
}

class FirebaseRavelryCatalogAuth implements RavelryCatalogAuth {
  FirebaseRavelryCatalogAuth({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  bool get hasSignedInUser => _firebaseAuth.currentUser != null;

  @override
  Future<void> ensureIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }

    await user.getIdToken(forceRefresh);
  }
}

class FirebaseRavelryYarnCatalogFunctions
    implements RavelryYarnCatalogFunctions {
  FirebaseRavelryYarnCatalogFunctions({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _functionsRegion);

  static const _functionsRegion = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, dynamic>> call(Map<String, Object?> data) async {
    final result = await _functions
        .httpsCallable('ravelryYarnCatalog')
        .call(data);
    final responseData = result.data;
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }

    throw const RavelryCatalogException(
      'Ravelry catalog returned an unexpected response.',
    );
  }
}

class RavelryYarnCatalogRepository {
  RavelryYarnCatalogRepository({
    RavelryYarnCatalogFunctions? functions,
    RavelryCatalogAuth? auth,
  }) : _functions = functions ?? FirebaseRavelryYarnCatalogFunctions(),
       _auth = auth ?? FirebaseRavelryCatalogAuth();

  final RavelryYarnCatalogFunctions _functions;
  final RavelryCatalogAuth _auth;

  Future<List<RavelryYarnCatalogItem>> searchYarns({
    required String query,
    int page = 1,
    int pageSize = 20,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }

    final data = await _callFunction({
      'action': 'searchYarns',
      'query': trimmedQuery,
      'page': page,
      'pageSize': pageSize,
    });
    final yarns = data['yarns'];
    if (yarns is! List) {
      return const [];
    }

    return yarns
        .whereType<Map>()
        .map(
          (yarn) =>
              RavelryYarnCatalogItem.fromJson(Map<String, dynamic>.from(yarn)),
        )
        .toList(growable: false);
  }

  Future<RavelryYarnCatalogItem> getYarn(int id) async {
    final data = await _callFunction({'action': 'getYarn', 'id': id});
    final yarn = data['yarn'];
    if (yarn is! Map) {
      throw const RavelryCatalogException(
        'Ravelry returned an unexpected yarn payload.',
      );
    }

    return RavelryYarnCatalogItem.fromJson(Map<String, dynamic>.from(yarn));
  }

  Future<Map<String, dynamic>> _callFunction(Map<String, Object?> data) async {
    try {
      await _auth.ensureIdToken();
      return await _functions.call(data);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated' && _auth.hasSignedInUser) {
        return _retryWithFreshToken(data);
      }

      throw _exceptionFromFunctionError(error);
    } on RavelryCatalogException {
      rethrow;
    } on FirebaseAuthException {
      throw const RavelryCatalogException(
        'Unable to verify your sign-in status. Sign out and sign back in.',
      );
    } catch (_) {
      throw const RavelryCatalogException(
        'Unable to reach the Ravelry catalog function.',
      );
    }
  }

  Future<Map<String, dynamic>> _retryWithFreshToken(
    Map<String, Object?> data,
  ) async {
    try {
      await _auth.ensureIdToken(forceRefresh: true);
      return await _functions.call(data);
    } on FirebaseFunctionsException catch (error) {
      throw _exceptionFromFunctionError(error);
    } on RavelryCatalogException {
      rethrow;
    } on FirebaseAuthException {
      throw const RavelryCatalogException(
        'Unable to verify your sign-in status. Sign out and sign back in.',
      );
    } catch (_) {
      throw const RavelryCatalogException(
        'Unable to reach the Ravelry catalog function.',
      );
    }
  }

  RavelryCatalogException _exceptionFromFunctionError(
    FirebaseFunctionsException error,
  ) {
    return switch (error.code) {
      'failed-precondition' => const RavelryCatalogNotConfiguredException(),
      'unauthenticated' => const RavelryCatalogException(
        'Unable to search the Ravelry catalog right now.',
      ),
      'permission-denied' => const RavelryCatalogException(
        'Ravelry rejected the configured API credentials.',
      ),
      'invalid-argument' => RavelryCatalogException(
        error.message ?? 'The Ravelry catalog request was invalid.',
      ),
      'unavailable' || 'deadline-exceeded' => const RavelryCatalogException(
        'Unable to search the Ravelry catalog right now.',
      ),
      _ => RavelryCatalogException(
        error.message ?? 'Ravelry catalog request failed.',
      ),
    };
  }
}
