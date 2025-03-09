pub type Config {
  Config(token_expiry: Int)
}

/// 60 * 60 * 24 * 30
const thirty_days: Int = 2_592_000

/// Config Values
/// token_expiry: thirty days (60 * 60 * 24 * 30)
pub const config = Config(token_expiry: thirty_days)
