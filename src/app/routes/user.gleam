import antigone
import app/queries/sql
import app/utils/temporal
import app/web.{type Context}
import gleam/bit_array
import gleam/bool
import gleam/dynamic/decode
import gleam/http.{Delete, Get, Post}
import gleam/json
import pog
import wisp.{type Request, type Response}
import youid/uuid

pub fn all(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> list(req, ctx)
    Post -> create(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn one(req: Request, ctx: Context, id: String) -> Response {
  case req.method {
    Get -> read(req, ctx, id)
    _ -> wisp.method_not_allowed([Get])
  }
}

pub type CreateUserPayload {
  CreateUserPayload(email: String, password: String)
}

fn create_payload_decoder() -> decode.Decoder(CreateUserPayload) {
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  let bits = bit_array.from_string(password)
  let hashed = antigone.hash(antigone.hasher(), bits)
  let payload = CreateUserPayload(email: email, password: hashed)
  decode.success(payload)
}

pub fn create(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)

  let result = case decode.run(json, create_payload_decoder()) {
    Ok(user) -> {
      case sql.create_user(ctx.db, user.email, user.password) {
        Ok(pog.Returned(_, [created])) -> {
          json.object([
            #("id", json.string(uuid.to_string(created.id))),
            #("email", json.string(created.email)),
          ])
          |> json.to_string_tree
          |> wisp.json_response(201)
          |> new_session(req, ctx, _, created.id)
        }
        _ -> Error(wisp.unprocessable_entity())
      }
    }
    _ -> Error(wisp.unprocessable_entity())
  }

  case result {
    Ok(success) -> success
    Error(error) -> error
  }
}

fn list_to_json(user: sql.ListUsersRow) {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("email", json.string(user.email)),
  ])
}

pub fn list(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Get)

  case sql.list_users(ctx.db) {
    Ok(pog.Returned(_, users)) -> {
      let object = json.array(users, list_to_json)
      let payload = json.to_string_tree(object)
      wisp.json_response(payload, 200)
    }
    _ -> wisp.internal_server_error()
  }
}

fn read_to_json(user: sql.ReadUserByIdRow) {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("email", json.string(user.email)),
  ])
}

pub fn read(req: Request, ctx: Context, id: String) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Get)

  case uuid.from_string(id) {
    Ok(id) -> {
      case sql.read_user_by_id(ctx.db, id) {
        Ok(pog.Returned(_, [user])) -> {
          let object = read_to_json(user)
          let payload = json.to_string_tree(object)
          wisp.json_response(payload, 200)
        }
        _ -> wisp.not_found()
      }
    }
    _ -> wisp.bad_request()
  }
}

pub type LoginPayload {
  LoginPayload(email: String, password: String)
}

fn login_payload_decoder() -> decode.Decoder(LoginPayload) {
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(LoginPayload(email: email, password: password))
}

fn new_session(
  req: Request,
  ctx: Context,
  res: Response,
  user: uuid.Uuid,
) -> Result(Response, Response) {
  let token = uuid.v4_string()
  // number of seconds in 30 days
  let expires_in = 60 * 60 * 24 * 30
  let stamp =
    temporal.from_seconds(expires_in)
    |> temporal.to_pog_timestamp
  case sql.create_session(ctx.db, user, token, stamp) {
    Ok(pog.Returned(_, [session])) -> {
      Ok(wisp.set_cookie(
        res,
        req,
        "s.id",
        session.session_token,
        wisp.Signed,
        expires_in,
      ))
    }

    _ -> Error(wisp.internal_server_error())
  }
}

pub fn login(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)

  let result = {
    case decode.run(json, login_payload_decoder()) {
      Ok(payload) -> {
        case sql.read_user_by_email(ctx.db, payload.email) {
          Ok(pog.Returned(_, [user])) -> {
            let bits = bit_array.from_string(payload.password)
            use <- bool.guard(
              when: !antigone.verify(bits, user.password_hash),
              return: Error(wisp.bad_request()),
            )

            json.object([#("user_id", json.string(uuid.to_string(user.id)))])
            |> json.to_string_tree
            |> wisp.json_response(200)
            |> new_session(req, ctx, _, user.id)
          }
          _ -> Error(wisp.not_found())
        }
      }
      _ -> Error(wisp.unprocessable_entity())
    }
  }

  case result {
    Ok(success_response) -> success_response
    Error(error_response) -> error_response
  }
}

pub type LogoutPayload {
  LogoutPayload(user_id: uuid.Uuid)
}

fn logout_payload_decoder() -> decode.Decoder(LogoutPayload) {
  use user_id <- decode.field("user_id", decode.string)
  case uuid.from_string(user_id) {
    Ok(id) -> decode.success(LogoutPayload(user_id: id))
    Error(_) -> decode.failure(LogoutPayload(uuid.v7()), "user_id")
  }
}

pub fn logout(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Delete)
  use json <- wisp.require_json(req)

  let session_token = wisp.get_cookie(req, "s.id", wisp.Signed)
  case decode.run(json, logout_payload_decoder()) {
    Ok(payload) -> {
      case session_token {
        Ok(token) -> {
          case sql.delete_session(ctx.db, payload.user_id, token) {
            Ok(_) ->
              json.object([#("message", json.string("Logged out"))])
              |> json.to_string_tree
              |> wisp.json_response(200)
            _ -> wisp.not_found()
          }
        }
        _ -> wisp.bad_request()
      }
    }
    _ -> wisp.unprocessable_entity()
  }
}
