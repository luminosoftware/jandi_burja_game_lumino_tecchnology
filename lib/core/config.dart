/// Central, tunable configuration for the whole game.
///
/// Everything a designer or a playtester is likely to want to adjust lives
/// here rather than being scattered through the code. In particular the
/// payout table and the ad identifiers are the two values most likely to
/// change between builds.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Jhandi Munda';

  // ---------------------------------------------------------------- company
  /// The studio behind the game, named on the About screen.
  static const String companyName = 'Lumino Technology Pvt. Ltd.';

  /// Where the company is based, as shown on the About screen.
  static const String companyAddress = 'Pokhara, Srijana Chowk, Nepal';

  /// The address the About screen's "contact us" row opens.
  static const String supportEmail = 'luminotechnologyapp@gmail.com';

  // ---------------------------------------------------------------- economy
  /// Coins a brand new player starts with.
  static const int startingCoins = 5000;

  /// Coins granted for watching one rewarded video to completion.
  ///
  /// This is the *only* authority on the reward. The ad SDK does report a
  /// `RewardItem`, and AdMob's own test unit reports 10, but that number is a
  /// test artifact rather than a payout: acting on it credited 10 coins against
  /// a button that promises this figure.
  static const int coinsPerRewardedAd = 500;

  /// Smallest legal wager on a single symbol.
  static const int minBet = 10;

  /// Largest legal wager on a single symbol.
  static const int maxBetPerSymbol = 2000;

  /// Largest legal sum across all symbols in a single round.
  static const int maxTotalBet = 6000;

  /// Chip the player starts with selected.
  static const int defaultChip = 50;

  /// Selectable chip denominations, ascending.
  static const List<int> chipDenominations = <int>[10, 50, 100, 500, 1000];

  // ------------------------------------------------------------------- dice
  /// Number of dice thrown per round.
  static const int diceCount = 6;

  /// How many dice must show the bet symbol for the bet to win.
  ///
  /// This value is the single most important number in the game. At 2 it gives
  /// a return-to-player of 86.13% (house edge 13.87%), which is what makes the
  /// coin economy work: a player genuinely runs out of coins over time.
  ///
  /// Setting this to 1 would pay k x the stake for a single matching die and
  /// hand the player a 166% return, so the balance would grow without bound and
  /// the watch-an-ad refill would never be needed. See docs/rules.md.
  static const int minDiceToWin = 2;

  // -------------------------------------------------------------------- ads
  /// AdMob rewarded-video ad unit.
  ///
  /// Rewarded unit registered in the publisher's AdMob account. During testing,
  /// use Google's demo unit or a registered test device instead.
  static const String admobRewardedUnitId =
      'ca-app-pub-2829352214511086/6206737074';

  /// True only when Google's official demo ad units are configured.
  static const bool usingTestAdIds = false;

  /// Banner unit registered in the publisher's AdMob account.
  static const String admobBannerHomeUnitId =
      'ca-app-pub-2829352214511086/5999776955';

  // ------------------------------------------------------------------ audio
  static const bool soundEnabledByDefault = true;

  // ------------------------------------------------------------------- throw
  /// Whether the throw screen starts in its 3D dice mode.
  ///
  /// The player can switch this at any time with the 2D/3D toggle in the top
  /// bar; this is only the value a fresh install opens on.
  static const bool throw3dByDefault = false;
}
