import antigone
import app/auth.{type Context}
import app/config.{config as app_config}
import app/error.{type AppError}
import app/queries/sql
import birl
import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Delete, Get, Post}
import gleam/json
import gleam/result
import gwt
import pog
import wisp.{type Request, type Response}
import youid/uuid

// Endpoints

pub fn all(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> list(ctx)
    Post -> create(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn one(req: Request, ctx: Context, id: String) -> Response {
  case req.method {
    Get -> read(ctx, id)
    _ -> wisp.method_not_allowed([Get])
  }
}

pub fn create(req: Request, ctx: Context) -> Response {
  use json <- wisp.require_json(req)
  create_user(json, req, ctx)
}

pub fn list(ctx: Context) -> Response {
  list_user(ctx)
}

pub fn read(ctx: Context, id: String) -> Response {
  read_user(id, ctx)
}

pub fn login(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)
  login_user(json, req, ctx)
}

pub fn logout(req: Request) -> Response {
  use <- wisp.require_method(req, Delete)
  logout_user(req)
}

pub fn example_protected(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Get)
  use claim <- auth.require_authentication(ctx)
  wisp.response(200)
  |> wisp.string_body("cool kids club member - " <> claim.email)
}

// Controllers

pub type EmailCredentials {
  EmailCredentials(email: String, password: String)
}

fn send(response: Result(Response, AppError)) -> Response {
  case response {
    Ok(success) -> success
    Error(e) -> error.handle(e)
  }
}

fn email_credentials_decoder(
  json: dynamic.Dynamic,
) -> Result(EmailCredentials, AppError) {
  decode.run(json, {
    use email <- decode.field("email", decode.string)
    use password <- decode.field("password", decode.string)
    let payload = EmailCredentials(email, password)
    decode.success(payload)
  })
  |> result.map_error(fn(errs) { error.PayloadSensitive(errs) })
}

fn register_user(
  user: EmailCredentials,
  ctx: Context,
) -> Result(UserFrom, AppError) {
  let bits = bit_array.from_string(user.password)
  let hashed = antigone.hash(antigone.hasher(), bits)
  case sql.user_create(ctx.db, user.email, hashed) {
    Ok(pog.Returned(_, [created])) -> Ok(Created(created))
    Error(pog.ConstraintViolated(_, "users_email_key", _)) ->
      Error(error.Auth(error.UserAlreadyExists))
    Error(err) -> Error(error.Database(err))
    _ -> Error(error.Unknown)
  }
}

fn create_response(
  payload: #(auth.UserClaim, String, Int),
  req: Request,
) -> Response {
  let #(user, token, expires_in) = payload

  json.object([
    #("id", auth.json_uuid(user.id)),
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
  let assert Ok(id) = uuid.from_string(user_id)
  case sql.user_by_id(ctx.db, id) {
    Ok(pog.Returned(_, [user])) -> {
      let object = read_to_json(user)
      let payload = json.to_string_tree(object)
      Ok(wisp.json_response(payload, 200))
    }
    Error(e) -> Error(error.Database(e))
    _ -> Error(error.Unknown)
  }
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
    Error(e) -> Error(error.Database(e))
  }
  |> send
}

fn authenticate_user(
  auth: EmailCredentials,
  ctx: Context,
) -> Result(UserFrom, AppError) {
  case sql.user_by_email(ctx.db, auth.email) {
    Ok(pog.Returned(_, [user])) -> {
      let bits = bit_array.from_string(auth.password)

      case antigone.verify(bits, user.password_hash) {
        False -> Error(error.Auth(error.RejectedPassword))
        True -> Ok(LoggedIn(user))
      }
    }
    Error(e) -> Error(error.Database(e))
    _ -> Error(error.Unknown)
  }
}

type UserFrom {
  Created(user: sql.UserCreateRow)
  LoggedIn(user: sql.UserByEmailRow)
}

fn mint_token(user: UserFrom, ctx: Context) -> #(auth.UserClaim, String, Int) {
  let claim = case user {
    Created(u) -> auth.UserClaim(id: u.id, email: u.email)
    LoggedIn(u) -> auth.UserClaim(id: u.id, email: u.email)
  }
  let payload =
    json.object([
      #("id", auth.json_uuid(claim.id)),
      #("email", json.string(claim.email)),
    ])
  let iat = birl.to_unix(birl.now())
  let exp = iat + app_config.token_expiry
  let token =
    gwt.new()
    |> gwt.set_jwt_id(uuid.to_string(claim.id))
    |> gwt.set_header_claim("user", payload)
    |> gwt.set_issued_at(iat)
    |> gwt.set_expiration(exp)
    |> gwt.to_signed_string(gwt.HS256, ctx.secret)
  #(claim, token, exp)
}

fn login_response(
  payload: #(auth.UserClaim, String, Int),
  req: Request,
) -> Response {
  let #(user, token, expires_in) = payload

  json.object([#("user_id", auth.json_uuid(user.id))])
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
