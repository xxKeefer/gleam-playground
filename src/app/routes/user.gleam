import antigone
import app/queries/sql
import app/web.{type Context}
import gleam/bit_array
import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/json
import pog
import wisp.{type Request, type Response}
import youid/uuid

// This request handler is used for requests to `/users`.
//
pub fn all(req: Request, ctx: Context) -> Response {
  // Dispatch to the appropriate handler based on the HTTP method.
  case req.method {
    Get -> list(req, ctx)
    Post -> create(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

// This request handler is used for requests to `/users/:id`.

pub fn one(req: Request, ctx: Context, id: String) -> Response {
  // Dispatch to the appropriate handler based on the HTTP method.
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
          let object =
            json.object([
              #("id", json.string(uuid.to_string(created.id))),
              #("email", json.string(created.email)),
            ])

          Ok(json.to_string_tree(object))
        }
        _ -> Error("Failed to create user")
      }
    }
    Error(_) -> Error("Failed to insert into database")
  }

  case result {
    Ok(json) -> wisp.json_response(json, 201)
    Error(_) -> wisp.unprocessable_entity()
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
    _ -> wisp.unprocessable_entity()
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
    _ -> wisp.unprocessable_entity()
  }
}
