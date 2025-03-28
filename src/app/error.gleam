import gleam/dynamic/decode
import gleam/io
import gleam/json
import pog
import wisp.{type Response}

import gleam/int
import gleam/string

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

pub fn handle_db_error(error: pog.QueryError) -> Response {
  case error {
    pog.ConstraintViolated(msg, constraint, detail) ->
      constraint_violated(msg, constraint, detail)
    pog.UnexpectedArgumentCount(_, _) -> handle_unexpected(error)
    pog.UnexpectedArgumentType(_, _) -> handle_unexpected(error)
    pog.UnexpectedResultType(_) -> handle_unexpected(error)
    _ -> wisp.internal_server_error()
  }
}

fn handle_unexpected(error: pog.QueryError) -> Response {
  case error {
    pog.UnexpectedArgumentCount(expected, got) ->
      io.debug(
        "UnexpectedArgumentCount: expected "
        <> int.to_string(expected)
        <> ", got "
        <> int.to_string(got),
      )
    pog.UnexpectedArgumentType(expected, got) ->
      io.debug(
        "UnexpectedArgumentType: expected " <> expected <> ", got " <> got,
      )
    pog.UnexpectedResultType(_) -> io.debug("UnexpectedResultType")

    _ -> io.debug("fn = handle_unexpected, should not be here")
  }

  wisp.bad_request()
}

fn constraint_violated(msg: String, _: String, detail: String) {
  let body = string.join([msg, detail], "\n")
  wisp.response(409) |> wisp.string_body(body)
}
