import gleam/dynamic/decode
import pog
import youid/uuid.{type Uuid}

/// A row you get from running the `create_user` query
/// defined in `./src/app/queries/sql/create_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CreateUserRow {
  CreateUserRow(id: Uuid, email: String)
}

/// Runs the `create_user` query
/// defined in `./src/app/queries/sql/create_user.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_user(db, arg_1, arg_2) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    decode.success(CreateUserRow(id:, email:))
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

/// Runs the `delete_session` query
/// defined in `./src/app/queries/sql/delete_session.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_session(db, arg_1, arg_2) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "delete from sessions
where user_id = $1
  and session_token = $2
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `create_session` query
/// defined in `./src/app/queries/sql/create_session.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CreateSessionRow {
  CreateSessionRow(
    user_id: Uuid,
    session_token: String,
    expires_at: pog.Timestamp,
  )
}

/// Runs the `create_session` query
/// defined in `./src/app/queries/sql/create_session.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_session(db, arg_1, arg_2, arg_3) {
  let decoder = {
    use user_id <- decode.field(0, uuid_decoder())
    use session_token <- decode.field(1, decode.string)
    use expires_at <- decode.field(2, pog.timestamp_decoder())
    decode.success(CreateSessionRow(user_id:, session_token:, expires_at:))
  }

  "insert into sessions (id, user_id, session_token, created_at, expires_at)
values (
  gen_random_uuid(), 
  $1, 
  $2, 
  now() at time zone 'utc', 
  $3
)
returning user_id, session_token, expires_at;"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `read_user_by_id` query
/// defined in `./src/app/queries/sql/read_user_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReadUserByIdRow {
  ReadUserByIdRow(id: Uuid, email: String, password_hash: String)
}

/// Runs the `read_user_by_id` query
/// defined in `./src/app/queries/sql/read_user_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn read_user_by_id(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    use password_hash <- decode.field(2, decode.string)
    decode.success(ReadUserByIdRow(id:, email:, password_hash:))
  }

  "select id, email, password_hash from users
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `read_user_by_email` query
/// defined in `./src/app/queries/sql/read_user_by_email.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReadUserByEmailRow {
  ReadUserByEmailRow(id: Uuid, email: String, password_hash: String)
}

/// Runs the `read_user_by_email` query
/// defined in `./src/app/queries/sql/read_user_by_email.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn read_user_by_email(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    use password_hash <- decode.field(2, decode.string)
    decode.success(ReadUserByEmailRow(id:, email:, password_hash:))
  }

  "select id, email, password_hash from users
where email = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_users` query
/// defined in `./src/app/queries/sql/list_users.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListUsersRow {
  ListUsersRow(id: Uuid, email: String)
}

/// Runs the `list_users` query
/// defined in `./src/app/queries/sql/list_users.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_users(db) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    decode.success(ListUsersRow(id:, email:))
  }

  "select id, email from users;
"
  |> pog.query
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
