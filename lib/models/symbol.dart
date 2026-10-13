/// The six symbols printed on the faces of every die.
///
/// Order is deliberate and load-bearing: the betting board renders symbols in
/// this order, and [Symbol.values] indexes into per-symbol state maps. Do not
/// reorder without updating those maps.
enum Symbol {
  /// Burja - the crown, one of the six traditional symbols.
  crown('Crown', 'burja'),

  /// Jhanda / Jandi - the flag, the second non-card-suit symbol.
  ///
  /// The English name is "flag", not "anchor": the traditional name for it,
  /// jhanda, means flag, and it is the symbol the game is named after.
  flag('Flag', 'jhanda'),

  heart('Heart', 'paan'),
  diamond('Diamond', 'itta'),
  club('Club', 'chidi'),
  spade('Spade', 'hukum');

  const Symbol(this.label, this.localName);

  /// English name, shown on the betting board and rules screen.
  final String label;

  /// Traditional name in the game's native vocabulary, shown alongside
  /// [label] so the game reads as Jhandi Munda rather than a generic casino
  /// dice game. These are the names used in Nepal and northern India.
  final String localName;

  /// The number printed on this symbol's die face.
  ///
  /// This is a contract with the 3D page, not a game rule: `SYMBOLS` in
  /// `ui/screens/dice_lab_web.dart` maps 1 to the heart, 2 to the crown, 3 to
  /// the spade, 4 to the club, 5 to the flag and 6 to the diamond, and the
  /// real-money throw sends these numbers to the page so the dice the player
  /// watches are the dice that get scored. A mismatch here would settle one
  /// symbol against another's faces, so it is asserted value by value in
  /// `test/symbol_test.dart`.
  int get dieNumber => switch (this) {
    Symbol.heart => 1,
    Symbol.crown => 2,
    Symbol.spade => 3,
    Symbol.club => 4,
    Symbol.flag => 5,
    Symbol.diamond => 6,
  };

  /// The bundled artwork for this symbol, for the throw result grid.
  ///
  /// These are the painted assets in `assets/images/`, named after both the
  /// English symbol and its local name. Kept apart from [dieNumber] so the
  /// number contract with the 3D page is not disturbed by art changes.
  String get imageAsset => switch (this) {
    Symbol.crown => 'assets/images/crown-burja.png',
    Symbol.flag => 'assets/images/flag-jhanda.png',
    Symbol.heart => 'assets/images/love-paan.png',
    Symbol.diamond => 'assets/images/diamond-itta.png',
    Symbol.club => 'assets/images/club-chidi.png',
    Symbol.spade => 'assets/images/spade-hukum.png',
  };

  /// Yellow background artwork for the betting board.
  String get whiteBgImageAsset => switch (this) {
    Symbol.crown => 'assets/images/burja-white-bg.png',
    Symbol.flag => 'assets/images/jhanda-white-bg.png',
    Symbol.heart => 'assets/images/paan-white-bg.png',
    Symbol.diamond => 'assets/images/itta-white-bg.png',
    Symbol.club => 'assets/images/chidi-white-bg.png',
    Symbol.spade => 'assets/images/hukkum-white-bg.png',
  };
}
