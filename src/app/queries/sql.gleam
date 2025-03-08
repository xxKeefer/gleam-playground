import gleam/dynamic/decode
import pog
import youid/uuid.{type Uuid}

/// A row you get from running the `user_by_id` query
/// defined in `./src/app/queries/sql/user_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserByIdRow {
  UserByIdRow(id: Uuid, email: String, password_hash: String)
}

/// Runs the `user_by_id` query
/// defined in `./src/app/queries/sql/user_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn user_by_id(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    use password_hash <- decode.field(2, decode.string)
    decode.success(UserByIdRow(id:, email:, password_hash:))
  }

  "select id, email, password_hash from users
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `blog_update` query
/// defined in `./src/app/queries/sql/blog_update.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn blog_update(db, arg_1, arg_2, arg_3, arg_4, arg_5) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "update blog_articles
set content = $2, title = $3, slug = $4, tags = $5
where id = $1;"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.array(fn(value) { pog.text(value) }, arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `blog_list` query
/// defined in `./src/app/queries/sql/blog_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type BlogListRow {
  BlogListRow(id: Uuid, title: String, slug: String, created_at: pog.Timestamp)
}

/// Runs the `blog_list` query
/// defined in `./src/app/queries/sql/blog_list.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn blog_list(db) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use title <- decode.field(1, decode.string)
    use slug <- decode.field(2, decode.string)
    use created_at <- decode.field(3, pog.timestamp_decoder())
    decode.success(BlogListRow(id:, title:, slug:, created_at:))
  }

  "select id, title, slug, created_at from blog_articles;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `user_list` query
/// defined in `./src/app/queries/sql/user_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserListRow {
  UserListRow(id: Uuid, email: String)
}

/// Runs the `user_list` query
/// defined in `./src/app/queries/sql/user_list.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn user_list(db) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    decode.success(UserListRow(id:, email:))
  }

  "select id, email from users;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `user_create` query
/// defined in `./src/app/queries/sql/user_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserCreateRow {
  UserCreateRow(id: Uuid, email: String)
}

/// Runs the `user_create` query
/// defined in `./src/app/queries/sql/user_create.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn user_create(db, arg_1, arg_2) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    decode.success(UserCreateRow(id:, email:))
  }

  "insert into users (id, email, password_hash, created_at, updated_at)
values (
  gen_random_uuid(), 
  $1, 
  $2, 
  now() at time zone 'utc', 
  now() at time zone 'utc'
)
returning id, email;"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `blog_by_id` query
/// defined in `./src/app/queries/sql/blog_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type BlogByIdRow {
  BlogByIdRow(id: Uuid, email: String, password_hash: String)
}

/// Runs the `blog_by_id` query
/// defined in `./src/app/queries/sql/blog_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn blog_by_id(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    use password_hash <- decode.field(2, decode.string)
    decode.success(BlogByIdRow(id:, email:, password_hash:))
  }

  "select id, email, password_hash from users
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `blog_create` query
/// defined in `./src/app/queries/sql/blog_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type BlogCreateRow {
  BlogCreateRow(id: Uuid, title: String, slug: String, created_at: pog.Timestamp,
  )
}

/// Runs the `blog_create` query
/// defined in `./src/app/queries/sql/blog_create.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn blog_create(db, arg_1, arg_2, arg_3, arg_4, arg_5) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use title <- decode.field(1, decode.string)
    use slug <- decode.field(2, decode.string)
    use created_at <- decode.field(3, pog.timestamp_decoder())
    decode.success(BlogCreateRow(id:, title:, slug:, created_at:))
  }

  "insert into blog_articles (
  id,
  title,
  slug,
  author_id,
  created_at,
  updated_at,
  tags,
  content
)
values (
  gen_random_uuid(), 
  $1, 
  $2, 
  $3, 
  now() at time zone 'utc', 
  now() at time zone 'utc',
  $4,
  $5
)
returning  id, title, slug, created_at;"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(uuid.to_string(arg_3)))
  |> pog.parameter(pog.array(fn(value) { pog.text(value) }, arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `blog_delete` query
/// defined in `./src/app/queries/sql/blog_delete.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn blog_delete(db, arg_1) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "delete from blog_articles
where id = $1
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `user_by_email` query
/// defined in `./src/app/queries/sql/user_by_email.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserByEmailRow {
  UserByEmailRow(id: Uuid, email: String, password_hash: String)
}

/// Runs the `user_by_email` query
/// defined in `./src/app/queries/sql/user_by_email.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn user_by_email(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    use password_hash <- decode.field(2, decode.string)
    decode.success(UserByEmailRow(id:, email:, password_hash:))
  }

  "select id, email, password_hash from users
where email = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

// --- Encoding/decoding utils -------------------------------------------------

/// A decoder to decode `Uuid`s coming from a Postgres query.
///
fn uuid_decoder() {
  use bit_array <- decode.then(decode.bit_array)
  case uuid.from_bit_array(bit_array) {
    Ok(uuid) -> decode.success(uuid)
    Error(_) -> decode.failure(uuid.v7(), "uuid")
  }
}
