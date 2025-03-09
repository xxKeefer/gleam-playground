import antigone
import app/auth.{type Context, type UserClaim}
import app/config.{config as app_config}
import app/queries/sql
import birl
import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/result
import gleam/string
import gwt
import pog
import wisp.{type Request, type Response}
import youid/uuid

pub type UserRouteError {
  InvalidUuid
  UnprocessableEntity(List(decode.DecodeError))
  DatabaseError(pog.QueryError)
  UnknownError
  RejectedPassword
  UserAlreadyExists
}

pub type EmailCredentials {
  EmailCredentials(email: String, password: String)
}

fn handle_errors(error: UserRouteError) -> Response {
  case error {
    UnknownError -> send_error(500, "something went wrong")
    RejectedPassword | InvalidUuid -> send_error(401, "UNAUTHORIZED")
    UserAlreadyExists -> send_error(409, "user with same email already exists")
    DatabaseError(e) -> handle_db_error(e)
    UnprocessableEntity(errs) -> {
      io.debug(decoder_errors_to_json(errs))
      wisp.bad_request()
    }
  }
}

fn decoder_errors_to_json(errors: List(decode.DecodeError)) -> json.Json {
  let of_errors = fn(e: decode.DecodeError) -> json.Json {
    json.object([
      #("expected", json.string(e.expected)),
      #("found", json.string(e.found)),
      #("path", json.array(e.path, of: json.string)),
    ])
  }

  json.object([#("errors", json.array(errors, of_errors))])
}

fn send_error(code: Int, msg: String) -> Response {
  wisp.response(code) |> wisp.string_body(msg)
}

fn handle_db_error(error: pog.QueryError) -> Response {
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

fn constraint_violated(msg: String, constraint: String, detail: String) {
  io.debug([msg, constraint, detail] |> string.join("\n"))
  wisp.internal_server_error()
}

fn send(response: Result(Response, UserRouteError)) -> Response {
  case response {
    Ok(success) -> success
    Error(error) -> handle_errors(error)
  }
}

fn email_credentials_decoder(
  json: dynamic.Dynamic,
) -> Result(EmailCredentials, UserRouteError) {
  decode.run(json, {
    use email <- decode.field("email", decode.string)
    use password <- decode.field("password", decode.string)
    let payload = EmailCredentials(email, password)
    decode.success(payload)
  })
  |> result.map_error(fn(errs) { UnprocessableEntity(errs) })
}

fn register_user(
  user: EmailCredentials,
  ctx: Context,
) -> Result(UserFrom, UserRouteError) {
  let bits = bit_array.from_string(user.password)
  let hashed = antigone.hash(antigone.hasher(), bits)
  case sql.user_create(ctx.db, user.email, hashed) {
    Ok(pog.Returned(_, [created])) -> Ok(Created(created))
    Error(pog.ConstraintViolated(_, "users_email_key", _)) ->
      Error(UserAlreadyExists)
    Error(err) -> Error(DatabaseError(err))
    _ -> Error(UnknownError)
  }
}

fn create_response(payload: #(UserClaim, String, Int), req: Request) -> Response {
  let #(user, token, expires_in) = payload

  json.object([
    #("id", json.string(user.id)),
    #("email", json.string(user.email)),
  ])
  |> json.to_string_tree
  |> wisp.json_response(200)
  |> wisp.set_cookie(req, "auth_token", token, wisp.Signed, expires_in)
  |> wisp.set_header("Authorization", "Bearer " <> token)
}

pub fn create_user(
  json: dynamic.Dynamic,
  req: Request,
  ctx: Context,
) -> Response {
  email_credentials_decoder(json)
  |> result.then(register_user(_, ctx))
  |> result.map(mint_token(_, ctx))
  |> result.map(create_response(_, req))
  |> send
}

fn read_to_json(user: sql.UserByIdRow) {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("email", json.string(user.email)),
  ])
}

pub fn read_user(user_id: String, ctx: Context) -> Response {
  uuid.from_string(user_id)
  |> result.replace_error(InvalidUuid)
  |> result.then(fn(id) {
    case sql.user_by_id(ctx.db, id) {
      Ok(pog.Returned(_, [user])) -> {
        let object = read_to_json(user)
        let payload = json.to_string_tree(object)
        Ok(wisp.json_response(payload, 200))
      }
      Error(err) -> Error(DatabaseError(err))
      _ -> Error(UnknownError)
    }
  })
  |> send
}

fn list_to_json(user: sql.UserListRow) {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("email", json.string(user.email)),
  ])
}

pub fn list_user(ctx: Context) -> Response {
  case sql.user_list(ctx.db) {
    Ok(pog.Returned(_, users)) -> {
      let object = json.array(users, list_to_json)
      let payload = json.to_string_tree(object)
      Ok(wisp.json_response(payload, 200))
    }
    Error(err) -> Error(DatabaseError(err))
  }
  |> send
}

fn authenticate_user(
  auth: EmailCredentials,
  ctx: Context,
) -> Result(UserFrom, UserRouteError) {
  case sql.user_by_email(ctx.db, auth.email) {
    Ok(pog.Returned(_, [user])) -> {
      let bits = bit_array.from_string(auth.password)

      case antigone.verify(bits, user.password_hash) {
        False -> Error(RejectedPassword)
        True -> Ok(LoggedIn(user))
      }
    }
    Error(err) -> Error(DatabaseError(err))
    _ -> Error(UnknownError)
  }
}

type UserFrom {
  Created(user: sql.UserCreateRow)
  LoggedIn(user: sql.UserByEmailRow)
}

fn mint_token(user: UserFrom, ctx: Context) -> #(UserClaim, String, Int) {
  let claim = case user {
    Created(u) -> auth.UserClaim(id: uuid.to_string(u.id), email: u.email)
    LoggedIn(u) -> auth.UserClaim(id: uuid.to_string(u.id), email: u.email)
  }
  let payload =
    json.object([
      #("id", json.string(claim.id)),
      #("email", json.string(claim.email)),
    ])
  let iat = birl.to_unix(birl.now())
  let exp = iat + app_config.token_expiry
  let token =
    gwt.new()
    |> gwt.set_jwt_id(claim.id)
    |> gwt.set_header_claim("user", payload)
    |> gwt.set_issued_at(iat)
    |> gwt.set_expiration(exp)
    |> gwt.to_signed_string(gwt.HS256, ctx.secret)
  #(claim, token, exp)
}

fn login_response(payload: #(UserClaim, String, Int), req: Request) -> Response {
  let #(user, token, expires_in) = payload

  json.object([#("user_id", json.string(user.id))])
  |> json.to_string_tree
  |> wisp.json_response(200)
  |> wisp.set_cookie(req, "auth_token", token, wisp.Signed, expires_in)
  |> wisp.set_header("Authorization", "Bearer " <> token)
}

pub fn login_user(json: dynamic.Dynamic, req: Request, ctx: Context) -> Response {
  email_credentials_decoder(json)
  |> result.then(authenticate_user(_, ctx))
  |> result.map(mint_token(_, ctx))
  |> result.map(login_response(_, req))
  |> send
}

pub fn logout_user(req: Request) -> Response {
  case auth.collect_token(req) {
    Error(_) -> wisp.not_found()
    Ok(token) ->
      wisp.no_content()
      |> wisp.set_cookie(req, "auth_token", token, wisp.Signed, 0)
      |> wisp.set_header("Authorization", "")
  }
}
