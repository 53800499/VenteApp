import 'package:bcrypt/bcrypt.dart';

class PinHasher {
  PinHasher({this.cost = 10});

  final int cost;

  String hash(String value) => BCrypt.hashpw(value, BCrypt.gensalt(logRounds: cost));

  bool compare(String value, String hash) => BCrypt.checkpw(value, hash);
}
