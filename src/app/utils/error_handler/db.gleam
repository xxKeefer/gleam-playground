import gleam/int
import gleam/io
import gleam/string
import pog
import wisp.{type Response}

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
