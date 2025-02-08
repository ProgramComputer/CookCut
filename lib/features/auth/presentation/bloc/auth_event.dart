import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthStatus extends AuthEvent {
  const CheckAuthStatus();
}

class SignInWithEmailAndPasswordRequested extends AuthEvent {
  final String email;
  final String password;

  const SignInWithEmailAndPasswordRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}

class SignUpWithEmailAndPasswordRequested extends AuthEvent {
  final String email;
  final String password;

  const SignUpWithEmailAndPasswordRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}

class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}
