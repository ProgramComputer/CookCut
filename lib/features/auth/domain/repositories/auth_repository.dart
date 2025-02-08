import '../entities/user.dart';

abstract class AuthRepository {
  Future<User?> getCurrentUser();

  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<User> signUpWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
  Stream<bool> get authStateChanges;
}
