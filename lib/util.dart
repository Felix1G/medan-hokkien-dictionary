String charAtUni(String text, int index) {
  return String.fromCharCode(text.runes.elementAt(index));
}

String charAtUniRunes(Runes runes, int index) {
  return String.fromCharCode(runes.elementAt(index));
}

double minDouble(double a, double b) {
  return a < b ? a : b;
}

int minInt(int a, int b) {
  return a < b ? a : b;
}