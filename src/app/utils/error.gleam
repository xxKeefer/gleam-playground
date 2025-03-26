import app/utils/error_handler/db.{handle_db_error}
import gleam/dynamic/decode
import gleam/io
import gleam/json
import pog
import wisp.{type Response}

pub type AppError {
  PayloadIdInvalid
  Payload(List(decode.DecodeError))
  PayloadSensitive(List(decode.DecodeError))
  Database(pog.QueryError)
  NotFound
  UnexpectedShape
  Unknown
  Auth(AuthenticationError)
}

pub type AuthenticationError {
  RejectedPassword
  UserAlreadyExists
  UserNotAuthenticated
  UserLacksPermission
}

pub fn send(code: Int, msg: String) -> Response {
  wisp.response(code) |> wisp.string_body(msg)
}

pub fn handle(error: AppError) -> Response {
  case error {
    Database(error) -> handle_db_error(error)
    NotFound -> send(404, "Had a look, nothing was there.")
    UnexpectedShape -> send(500, "Something borked.")
    PayloadIdInvalid -> send(400, "Could not parse resource id")
    Payload(errors) -> handle_payload_error(errors)
    PayloadSensitive(errors) -> handle_sensitive_payload_error(errors)
    Auth(error) -> handle_auth_error(error)

    Unknown -> send(500, "something went wrong")
  }
}

fn handle_payload_error(errors: List(decode.DecodeError)) -> Response {
  let of_errors = fn(e: decode.DecodeError) -> json.Json {
    json.object([
      #("expected", json.string(e.expected)),
      #("found", json.string(e.found)),
      #("path", json.array(e.path, of: json.string)),
    ])
  }

  json.object([#("errors", json.array(errors, of_errors))])
  |> json.to_string_tree
  |> wisp.json_response(400)
}

fn handle_sensitive_payload_error(errors: List(decode.DecodeError)) -> Response {
  let of_errors = fn(e: decode.DecodeError) -> json.Json {
    json.object([
      #("expected", json.string(e.expected)),
      #("found", json.string(e.found)),
      #("path", json.array(e.path, of: json.string)),
    ])
  }

  json.object([#("errors", json.array(errors, of_errors))]) |> io.debug
  send(400, "Payload was malformed.")
}

fn handle_auth_error(error: AuthenticationError) -> Response {
  case error {
    RejectedPassword | UserNotAuthenticated -> send(401, "UNAUTHORISED")
    UserLacksPermission -> send(403, "UNAUTHORIZED")
    UserAlreadyExists -> send(409, "user with that email already exits.")
  }
}
