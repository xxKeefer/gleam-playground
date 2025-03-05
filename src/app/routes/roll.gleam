import app/web
import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import wisp.{type Request, type Response}

pub type RollResult {
  RollResult(total: Int, modifier: Int, kept: List(Int), results: List(Int))
}

pub type RollRequest {
  RollRequest(modifier: Int, roll: List(Int), keep: List(Int), boost: Boost)
}

pub type Boost {
  Ambitious
  Hard
  Normal
  Easy
  Trivial
}

fn boost_decoder() -> decode.Decoder(Boost) {
  use decoded_string <- decode.then(decode.string)
  case decoded_string {
    "ambitious" -> decode.success(Ambitious)
    "hard" -> decode.success(Hard)
    "easy" -> decode.success(Easy)
    "trivial" -> decode.success(Trivial)
    "normal" -> decode.success(Normal)
    _ -> decode.failure(Normal, "boost")
  }
}

fn roll_request_decoder() -> decode.Decoder(RollRequest) {
  use modifier <- decode.field("modifier", decode.int)
  use keep <- decode.optional_field("keep", [], decode.list(decode.int))
  use roll <- decode.optional_field("roll", [], decode.list(decode.int))
  use boost <- decode.optional_field("boost", Normal, boost_decoder())
  let payload =
    RollRequest(modifier: modifier, roll: roll, keep: keep, boost: boost)
  decode.success(payload)
}

fn order_dice(dice: List(Int), boost: Boost) {
  case boost {
    Ambitious | Hard -> dice
    _ -> dice |> list.reverse
  }
}

fn roll_dice(params: RollRequest) -> RollResult {
  let results =
    params.roll
    |> list.map(fn(_) { int.random(6) + 1 })
    |> list.append(params.keep)
  let kept =
    list.sort(results, int.compare)
    |> order_dice(params.boost)
    |> list.take(2)
  let total = int.sum(kept) + params.modifier

  RollResult(total, params.modifier, kept, results)
}

pub fn handle_roll_dice(req: Request) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)

  let result = {
    use roll_request <- result.try(decode.run(json, roll_request_decoder()))
    let roll = roll_dice(roll_request)

    let object =
      json.object([
        #("total", json.int(roll.total)),
        #("modifier", json.int(roll.modifier)),
        #("kept", json.array(roll.kept, json.int)),
        #("results", json.array(roll.results, json.int)),
      ])
    Ok(json.to_string_tree(object))
  }

  case result {
    Ok(json) -> wisp.json_response(json, 201)

    // In a real application we would probably want to return some JSON error
    // object, but for this example we'll just return an empty response.
    Error(_) -> wisp.unprocessable_entity()
  }
}
