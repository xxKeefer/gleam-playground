import cors_builder as cors
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/list
import gleam/pair
import gleam/result
import gleam/string
import gwt
import pog
import wisp

pub type Context {
  Context(db: pog.Connection, secret: String)
  Authenticated(db: pog.Connection, secret: String, user: UserClaim)
}

pub type UserClaim {
  UserClaim(id: String, email: String)
}

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use req <- cors.wisp_middleware(req, cors())
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  handle_request(req)
}

pub fn auth_middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request, Context) -> wisp.Response,
) -> wisp.Response {
  let from_auth_header =
    req.headers
    |> list.find(fn(header) {
      case header {
        #("Authorization", "Bearer " <> _) -> True
        _ -> False
      }
    })
    |> result.then(fn(auth) {
      let #(_, bearer) = auth
      string.split_once(bearer, " ") |> result.map(pair.second)
    })
  let user_claim =
    wisp.get_cookie(req, "auth_token", wisp.Signed)
    |> result.or(from_auth_header)
    |> result.then(fn(token) {
      gwt.from_signed_string(token, ctx.secret) |> result.replace_error(Nil)
    })
    |> result.then(fn(verified) {
      gwt.get_header_claim(verified, "user", user_claim_decoder)
    })

  case user_claim {
    Error(Nil) -> wisp.response(401)
    Ok(user) -> handle_request(req, Authenticated(ctx.db, ctx.secret, user))
  }
}

fn cors() {
  cors.new()
  |> cors.allow_origin("http://localhost:3000")
  |> cors.allow_origin("http://localhost:4000")
  |> cors.allow_method(http.Get)
  |> cors.allow_method(http.Post)
}

fn user_claim_decoder(
  json: dynamic.Dynamic,
) -> Result(UserClaim, List(decode.DecodeError)) {
  decode.run(json, {
    use id <- decode.field("id", decode.string)
    use email <- decode.field("email", decode.string)
    decode.success(UserClaim(id, email))
  })
}
