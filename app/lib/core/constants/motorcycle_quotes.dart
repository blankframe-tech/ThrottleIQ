/// Short taglines for the record screen's quote block — one is picked at
/// random once per app session (see `dashboardQuoteProvider`) instead of
/// always showing the same "Your ride, smarter." line. Kept as plain,
/// unattributed lines (not quotes borrowed from a named person) so nothing
/// here risks being a misquote or misattribution.
///
/// Stored as a `(setup, payoff)` pair: the record screen joins them with a
/// space into one compact line, but the split is kept so a caller that wants
/// the old two-line stacked treatment can still render them separately.
const List<(String, String)> motorcycleQuotes = [
  ('Your ride,', 'smarter.'),
  ('Two wheels,', 'one heartbeat.'),
  ('Every ride,', 'a story worth logging.'),
  ('Trust the throttle,', 'respect the road.'),
  ('The road ahead', 'is the only plan you need.'),
  ('Ride the wind,', 'own the road.'),
  ('Smooth is fast.', 'Fast is smooth.'),
  ('Some roads', "you don't forget."),
  ('Chase the horizon,', 'not the redline.'),
  ('Miles make', 'the machine yours.'),
  ('Every gear change', 'is a decision.'),
  ('Ride far.', 'Ride smart.'),
  ('The best rides', 'start with no plan.'),
  ('Two wheels,', 'infinite roads.'),
  ('Momentum is', 'a kind of freedom.'),
  ('Read the road', 'before it reads you.'),
];
