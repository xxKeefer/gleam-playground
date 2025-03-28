import birl
import birl/duration
import gleam/string
import pog

pub fn from_pog_timestamp(stamp: pog.Timestamp) -> birl.Time {
  let pog.Timestamp(
    pog.Date(year, month, day),
    pog.Time(hour, minute, second, _),
  ) = stamp
  birl.from_erlang_universal_datetime(
    #(#(year, month, day), #(hour, minute, second)),
  )
}

pub fn to_pog_timestamp(stamp: birl.Time) -> pog.Timestamp {
  let #(#(year, month, day), #(hour, minute, second)) =
    birl.to_erlang_universal_datetime(stamp)
  pog.Timestamp(pog.Date(year, month, day), pog.Time(hour, minute, second, 0))
}

pub fn from_seconds(seconds: Int) -> birl.Time {
  birl.now() |> birl.add(duration.seconds(seconds))
}

pub fn slugify(raw: String) -> String {
  raw |> string.lowercase |> string.split(" ") |> string.join("-")
}
