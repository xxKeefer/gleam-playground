import antigone
import app/queries/sql
import app/utils/temporal
import app/web.{type Context}
import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/result
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

pub fn pog_to_wisp(pog_error: pog.QueryError) -> Response {
  //TODO: build response bodies from record fields
  case pog_error {
    pog.ConstraintViolated(_, _, _) -> wisp.unprocessable_entity()
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
    _ -> wisp.unprocessable_entity()
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
) -> Result(sql.CreateUserRow, UserError) {
  let bits = bit_array.from_string(user.password)
  let hashed = antigone.hash(antigone.hasher(), bits)
  case sql.create_user(ctx.db, user.email, hashed) {
    Ok(pog.Returned(_, [created])) -> Ok(created)
    Error(err) -> Error(DatabaseError(err))
    _ -> Error(UnknownError)
  }
}

fn create_response(
  user: sql.CreateUserRow,
  req: Request,
  ctx: Context,
) -> Result(Response, UserError) {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("email", json.string(user.email)),
  ])
  |> json.to_string_tree
  |> wisp.json_response(201)
  |> create_session(req, ctx, user.id)
}

pub fn create_user(
  json: dynamic.Dynamic,
  req: Request,
  ctx: web.Context,
) -> Response {
  email_credentials_decoder(json)
  |> result.then(register_user(_, ctx))
  |> result.then(create_response(_, req, ctx))
  |> send
}

type NewSessionReq {
  NewSessionReq(
    user: uuid.Uuid,
    id: String,
    expiry: pog.Timestamp,
    expires_in: Int,
  )
}

fn create_session(
  res: Response,
  req: Request,
  ctx: web.Context,
  user: uuid.Uuid,
) -> Result(Response, UserError) {
  let NewSessionReq(user, id, expiry, expires_in) = new_session(user)
  case sql.create_session(ctx.db, user, id, expiry) {
    Ok(pog.Returned(_, [created])) ->
      Ok(wisp.set_cookie(
        res,
        req,
        "s.id",
        created.session_token,
        wisp.Signed,
        expires_in,
      ))

    Error(err) -> Error(DatabaseError(err))
    _ -> Error(UnknownError)
  }
}

fn new_session(user: uuid.Uuid) -> NewSessionReq {
  let session_id = uuid.v4_string()
  // number of seconds in 30 days
  let expires_in = 60 * 60 * 24 * 30
  let stamp =
    temporal.from_seconds(expires_in)
    |> temporal.to_pog_timestamp
  NewSessionReq(user, id: session_id, expiry: stamp, expires_in: expires_in)
}

fn read_to_json(user: sql.ReadUserByIdRow) {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("email", json.string(user.email)),
  ])
}

pub fn read_user(user_id: String, ctx: web.Context) -> Response {
  uuid.from_string(user_id)
  |> result.map_error(fn(_) { InvalidUuid })
  |> result.then(fn(id) {
    case sql.read_user_by_id(ctx.db, id) {
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

fn list_to_json(user: sql.ListUsersRow) {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("email", json.string(user.email)),
  ])
}

pub fn list_user(ctx: Context) -> Response {
  case sql.list_users(ctx.db) {
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
) -> Result(sql.ReadUserByEmailRow, UserError) {
  case sql.read_user_by_email(ctx.db, auth.email) {
    Ok(pog.Returned(_, [user])) -> {
      let bits = bit_array.from_string(auth.password)

      case antigone.verify(bits, user.password_hash) {
        False -> Error(RejectedPassword)
        True -> Ok(user)
      }
    }
    Error(err) -> Error(DatabaseError(err))
    _ -> Error(UnknownError)
  }
}

fn login_response(
  user: sql.ReadUserByEmailRow,
  req: Request,
  ctx: Context,
) -> Result(Response, UserError) {
  json.object([#("user_id", json.string(uuid.to_string(user.id)))])
  |> json.to_string_tree
  |> wisp.json_response(200)
  |> create_session(req, ctx, user.id)
}

pub fn login_user(
  json: dynamic.Dynamic,
  req: Request,
  ctx: web.Context,
) -> Response {
  email_credentials_decoder(json)
  |> result.then(authenticate_user(_, ctx))
  |> result.then(login_response(_, req, ctx))
  |> send
}

type LogoutRequest {
  LogoutRequest(user: uuid.Uuid)
}

fn logout_request_decoder(
  json: dynamic.Dynamic,
) -> Result(LogoutRequest, UserError) {
  decode.run(json, {
    use user <- decode.field("user", decode.string)
    case uuid.from_string(user) {
      Ok(id) -> decode.success(LogoutRequest(user: id))
      Error(_) -> decode.failure(LogoutRequest(uuid.v7()), "user_id")
    }
  })
  |> result.map_error(fn(errs) { UnprocessableEntity(errs) })
}

fn delete_session(
  user: LogoutRequest,
  session: String,
  ctx: web.Context,
) -> Result(pog.Returned(Nil), UserError) {
  sql.delete_session(ctx.db, user.user, session)
  |> result.map_error(fn(err) { DatabaseError(err) })
}

fn logout_response() -> Result(Response, UserError) {
  json.object([#("message", json.string("Logged out"))])
  |> json.to_string_tree
  |> wisp.json_response(200)
  |> Ok
}

pub fn logout_user(
  json: dynamic.Dynamic,
  req: Request,
  ctx: web.Context,
) -> Response {
  case wisp.get_cookie(req, "s.id", wisp.Signed) {
    Error(_) -> {
      wisp.log_debug("a log out occurred with no session cookie")
      Error(UnknownError)
    }
    Ok(session) -> {
      logout_request_decoder(json)
      |> result.then(delete_session(_, session, ctx))
      |> result.then(fn(_) { logout_response() })
    }
  }
  |> send
}
