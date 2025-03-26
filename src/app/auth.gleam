import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/pair
import gleam/result
import gleam/string
import gwt
import pog
import wisp.{type Request, type Response}
import youid/uuid

pub type Context {
  Unauthenticated(db: pog.Connection, secret: String)
  Authenticated(db: pog.Connection, secret: String, user: UserClaim)
}

pub type UserClaim {
  UserClaim(id: uuid.Uuid, email: String)
}

pub fn middleware(
  req: Request,
  ctx: Context,
  handle_request: fn(Request, Context) -> Response,
) -> Response {
  let claim =
    collect_token(req)
    |> result.then(fn(token) {
      gwt.from_signed_string(token, ctx.secret) |> result.replace_error(Nil)
    })
    |> result.then(fn(verified) {
      gwt.get_header_claim(verified, "user", user_claim_decoder)
    })

  case claim {
    Error(Nil) -> handle_request(req, Unauthenticated(ctx.db, ctx.secret))
    Ok(user) -> handle_request(req, Authenticated(ctx.db, ctx.secret, user))
  }
}

pub fn require_authentication(
  context: Context,
  next: fn(UserClaim) -> Response,
) -> Response {
  let reject = fn() { wisp.response(401) |> wisp.string_body("UNAUTHORIZED") }

  case context {
    Unauthenticated(_, _) -> reject()
    Authenticated(_, _, claim) -> next(claim)
  }
}

pub fn collect_token(req: Request) -> Result(String, Nil) {
  let cookie = wisp.get_cookie(req, "auth_token", wisp.Signed)
  req |> token_from_header |> result.or(cookie)
}

fn token_from_header(req: Request) -> Result(String, Nil) {
  let extract = fn(x) {
    pair.second(x) |> string.split_once(" ") |> result.map(pair.second)
  }

  let auth_header = {
    use header <- list.find(req.headers)
    case header {
      #("Authorization", "Bearer " <> _) -> True
      _ -> False
    }
  }

  auth_header |> result.then(extract)
}

fn user_claim_decoder(
  json: dynamic.Dynamic,
) -> Result(UserClaim, List(decode.DecodeError)) {
  decode.run(json, {
    use id <- decode.field("id", uuid_decoder())
    use email <- decode.field("email", decode.string)
    decode.success(UserClaim(id, email))
  })
}

pub fn uuid_decoder() {
  use str <- decode.then(decode.string)
  case uuid.from_string(str) {
    Ok(uuid) -> decode.success(uuid)
    Error(_) -> decode.failure(uuid.v7(), "uuid")
  }
}

pub fn json_uuid(raw: uuid.Uuid) -> json.Json {
  raw |> uuid.to_string |> json.string
}
