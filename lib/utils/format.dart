/// Formatte un entier XOF avec séparateurs de milliers : 61599900 -> "61 599 900 FCFA".
String fcfa(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '$buf FCFA';
}
