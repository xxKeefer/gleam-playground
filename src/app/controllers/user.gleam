import antigone
import app/queries/sql
import app/web.{type Context}
import birl
import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/result
import gwt
import pog
import wisp.{type Request, type Response}
import youid/uuid

pub type UserError {
  InvalidUuid
  UnprocessableEntity(List(decode.DecodeError))
  DatabaseError(pog.QueryError)
  UnknownError
  RejectedPassword
}

pub type EmailCredentials {
  EmailCredentials(email: String, password: String)
}

fn constraint_violated(msg: String, constraint: String, detail: String) {
  json.object([
    #("msg", json.string(msg)),
    #("constraint", json.string(constraint)),
    #("detail", json.string(detail)),
  ])
  |> json.to_string_tree
  |> wisp.json_response(500)
}

fn pog_to_wisp(pog_error: pog.QueryError) -> Response {
  //TODO: build response bodies from record fields
  case pog_error {
    pog.ConstraintViolated(msg, constraint, detail) ->
      constraint_violated(msg, constraint, detail)
    pog.UnexpectedArgumentCount(_, _) -> wisp.bad_request()
    pog.UnexpectedArgumentType(_, _) -> wisp.bad_request()
    pog.UnexpectedResultType(_) -> wisp.bad_request()
    _ -> wisp.internal_server_error()
  }
}

fn send(response: Result(Response, UserError)) -> Response {
  case response {
    Ok(success) -> success
    Error(DatabaseError(err)) -> pog_to_wisp(err)
    wtf ->
      case wtf {
        Ok(_) -> {
          wisp.log_debug("something borked real good")
          wisp.response(419)
        }
        Error(_) -> {
          wisp.log_debug("something borked")
          wisp.internal_server_error()
        }
      }
  }
}

fn email_credentials_decoder(
  json: dynamic.Dynamic,
) -> Result(EmailCredentials, UserError) {
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
  ctx: web.Context,
) -> Result(UserFrom, UserError) {
  let bits = bit_array.from_string(user.password)
  let hashed = antigone.hash(antigone.hasher(), bits)
  case sql.user_create(ctx.db, user.email, hashed) {
    Ok(pog.Returned(_, [created])) -> Ok(Created(created))
    Error(err) -> Error(DatabaseError(err))
    _ -> Error(UnknownError)
  }
}

fn create_response(
  payload: #(web.UserClaim, String, Int),
  req: Request,
) -> Response {
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
  ctx: web.Context,
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

pub fn read_user(user_id: String, ctx: web.Context) -> Response {
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
  ctx: web.Context,
) -> Result(UserFrom, UserError) {
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

fn mint_token(user: UserFrom, ctx: Context) -> #(web.UserClaim, String, Int) {
  let claim = case user {
    Created(u) -> web.UserClaim(id: uuid.to_string(u.id), email: u.email)
    LoggedIn(u) -> web.UserClaim(id: uuid.to_string(u.id), email: u.email)
  }
  let payload =
    json.object([
      #("id", json.string(claim.id)),
      #("email", json.string(claim.email)),
    ])
  let iat = birl.to_unix(birl.now())
  let in_30_days = 60 * 60 * 24 * 30
  let exp = iat + in_30_days
  let token =
    gwt.new()
    |> gwt.set_jwt_id(claim.id)
    |> gwt.set_header_claim("user", payload)
    |> gwt.set_issued_at(iat)
    |> gwt.set_expiration(exp)
    |> gwt.to_signed_string(gwt.HS256, ctx.secret)
  #(claim, token, exp)
}

fn login_response(
  payload: #(web.UserClaim, String, Int),
  req: Request,
) -> Response {
  let #(user, token, expires_in) = payload

  json.object([#("user_id", json.string(user.id))])
  |> json.to_string_tree
  |> wisp.json_response(200)
  |> wisp.set_cookie(req, "auth_token", token, wisp.Signed, expires_in)
  |> wisp.set_header("Authorization", "Bearer " <> token)
}

pub fn login_user(
  json: dynamic.Dynamic,
  req: Request,
  ctx: web.Context,
) -> Response {
  email_credentials_decoder(json)
  |> result.then(authenticate_user(_, ctx))
  |> result.map(mint_token(_, ctx))
  |> result.map(login_response(_, req))
  |> send
}

pub fn logout_user(req: Request) -> Response {
  case wisp.get_cookie(req, "s.id", wisp.Signed) {
    Error(_) -> wisp.not_found()
    Ok(session) ->
      wisp.no_content()
      |> wisp.set_cookie(req, "auth_token", session, wisp.Signed, 0)
  }
}
