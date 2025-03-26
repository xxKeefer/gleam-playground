import app/auth.{type Context}
import app/queries/sql
import app/utils/error.{type AppError}
import app/utils/temporal
import birl
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import pog
import wisp.{type Response}
import youid/uuid

fn send(response: Result(Response, AppError)) -> Response {
  case response {
    Ok(success) -> success
    Error(e) -> error.handle(e)
  }
}

type Create {
  Create(
    title: String,
    slug: String,
    tags: List(String),
    author_id: uuid.Uuid,
    content: String,
  )
}

pub type Update {
  Update(
    id: uuid.Uuid,
    title: String,
    slug: String,
    tags: List(String),
    author_id: uuid.Uuid,
    content: String,
  )
}

fn slugify(raw: String) -> String {
  raw |> string.lowercase |> string.split(" ") |> string.join("-")
}

fn create_blog_req_decoder(
  user: auth.UserClaim,
  json: dynamic.Dynamic,
) -> Result(Create, AppError) {
  decode.run(json, {
    use title <- decode.field("title", decode.string)
    use raw_slug <- decode.field("slug", decode.string)
    use tags <- decode.field("tags", decode.list(decode.string))
    use content <- decode.field("content", decode.string)
    let slug = slugify(raw_slug)
    let payload = Create(title, slug, tags, user.id, content)
    decode.success(payload)
  })
  |> result.map_error(error.Payload)
}

fn update_blog_req_decoder(
  user: auth.UserClaim,
  blog_id: String,
  json: dynamic.Dynamic,
) -> Result(Update, AppError) {
  uuid.from_string(blog_id)
  |> result.map_error(fn(_) { error.PayloadIdInvalid })
  |> result.then(fn(id) {
    decode.run(json, {
      use title <- decode.field("title", decode.string)
      use raw_slug <- decode.field("slug", decode.string)
      use tags <- decode.field("tags", decode.list(decode.string))
      use content <- decode.field("content", decode.string)
      let slug = slugify(raw_slug)
      let payload = Update(id, title, slug, tags, user.id, content)
      decode.success(payload)
    })
    |> result.map_error(error.Payload)
  })
}

fn verify_user(ctx: Context) -> Result(auth.UserClaim, AppError) {
  case ctx {
    auth.Unauthenticated(_, _) -> Error(error.Auth(error.UserNotAuthenticated))
    auth.Authenticated(_, _, claim) -> Ok(claim)
  }
}

fn save_blog(
  payload: Create,
  ctx: Context,
) -> Result(pog.Returned(sql.BlogCreateRow), AppError) {
  let Create(title, slug, tags, author_id, content) = payload
  sql.blog_create(ctx.db, title, slug, author_id, tags, content)
  |> result.map_error(error.Database)
}

pub fn create_blog(json: dynamic.Dynamic, ctx: auth.Context) -> Response {
  verify_user(ctx)
  |> result.then(create_blog_req_decoder(_, json))
  |> result.then(save_blog(_, ctx))
  |> result.then(extract_db_response)
  |> result.map(encode_create)
  |> result.map(respond)
  |> send
}

pub fn list_blog(ctx: Context) -> Response {
  sql.blog_list(ctx.db)
  |> result.map_error(error.Database)
  |> result.then(extract_db_response)
  |> result.map(encode_list)
  |> result.map(respond)
  |> send
}

fn retrieve_blog(
  blog_id: uuid.Uuid,
  ctx: Context,
) -> Result(pog.Returned(sql.BlogByIdRow), AppError) {
  sql.blog_by_id(ctx.db, blog_id)
  |> result.map_error(error.Database)
}

pub fn read_blog(blog_id: String, ctx: Context) -> Response {
  uuid.from_string(blog_id)
  |> result.replace_error(error.PayloadIdInvalid)
  |> result.then(retrieve_blog(_, ctx))
  |> result.then(extract_db_response)
  |> result.map(encode_read)
  |> result.map(respond)
  |> send
}

fn edit_blog(
  payload: Update,
  ctx: Context,
) -> Result(pog.Returned(sql.BlogUpdateRow), AppError) {
  let Update(id, title, slug, tags, _, content) = payload
  sql.blog_update(ctx.db, id, content, title, slug, tags)
  |> result.map_error(error.Database)
}

pub fn update_blog(
  blog_id: String,
  json: dynamic.Dynamic,
  ctx: auth.Context,
) -> Response {
  verify_user(ctx)
  |> result.then(update_blog_req_decoder(_, blog_id, json))
  |> result.then(edit_blog(_, ctx))
  |> result.then(extract_db_response)
  |> result.map(encode_update)
  |> result.map(respond)
  |> send
}

fn extract_db_response(from: pog.Returned(x)) -> Result(List(x), AppError) {
  let pog.Returned(_, rows) = from
  Ok(rows)
}

fn respond(payload: json.Json) -> Response {
  json.to_string_tree(payload) |> wisp.json_response(200)
}

fn encode(
  id: uuid.Uuid,
  title: String,
  slug: String,
  tags: Option(List(String)),
  created_at: pog.Timestamp,
  updated_at: pog.Timestamp,
  content: String,
) -> json.Json {
  let stamp = temporal.from_pog_timestamp(created_at) |> birl.to_iso8601
  let update_stamp = temporal.from_pog_timestamp(updated_at) |> birl.to_iso8601
  json.object([
    #("id", json.string(uuid.to_string(id))),
    #("title", json.string(title)),
    #("slug", json.string(slug)),
    #("tags", json.nullable(tags, json.array(_, json.string))),
    #("created_at", json.string(stamp)),
    #("updated_at", json.string(update_stamp)),
    #("content", json.string(content)),
  ])
}

fn encode_read(rows: List(sql.BlogByIdRow)) -> json.Json {
  json.array(rows, fn(row) {
    encode(
      row.id,
      row.title,
      row.slug,
      row.tags,
      row.created_at,
      row.updated_at,
      row.content,
    )
  })
}

fn encode_list(rows: List(sql.BlogListRow)) -> json.Json {
  json.array(rows, fn(row) {
    encode(
      row.id,
      row.title,
      row.slug,
      row.tags,
      row.created_at,
      row.updated_at,
      row.content,
    )
  })
}

fn encode_create(rows: List(sql.BlogCreateRow)) -> json.Json {
  json.array(rows, fn(row) {
    encode(
      row.id,
      row.title,
      row.slug,
      row.tags,
      row.created_at,
      row.updated_at,
      row.content,
    )
  })
}

fn encode_update(rows: List(sql.BlogUpdateRow)) -> json.Json {
  json.array(rows, fn(row) {
    encode(
      row.id,
      row.title,
      row.slug,
      row.tags,
      row.created_at,
      row.updated_at,
      row.content,
    )
  })
}

pub fn delete_blog(blog_id: String, ctx: Context) -> Response {
  verify_user(ctx)
  |> result.then(check_ownership(_, blog_id, ctx))
  |> result.then(fn(blog_id) {
    sql.blog_delete(ctx.db, blog_id)
    |> result.map_error(error.Database)
  })
  |> result.map(fn(_) { wisp.response(204) })
  |> send
}

fn check_ownership(
  user: auth.UserClaim,
  blog_id: String,
  ctx: Context,
) -> Result(uuid.Uuid, AppError) {
  uuid.from_string(blog_id)
  |> result.map_error(fn(_) { error.PayloadIdInvalid })
  |> result.then(retrieve_blog(_, ctx))
  |> result.then(extract_db_response)
  |> result.then(fn(row) {
    case list.first(row) {
      Ok(blog) ->
        case blog.author_id == user.id {
          True -> Ok(blog.id)
          False -> Error(error.Auth(error.UserLacksPermission))
        }
      _ -> Error(error.NotFound)
    }
  })
}
