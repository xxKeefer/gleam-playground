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
  CreateUserRow(user_id: Uuid, email: String)
}

/// Runs the `create_user` query
/// defined in `./src/app/queries/sql/create_user.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_user(db, arg_1, arg_2) {
  let decoder = {
    use user_id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    decode.success(CreateUserRow(user_id:, email:))
  }

  "insert into users (user_id, email, password_hash, created_at, updated_at)
values (
  gen_random_uuid(), 
  $1, 
  $2, 
  now() at time zone 'utc', 
  now() at time zone 'utc'
)
returning user_id, email;"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `read_user` query
/// defined in `./src/app/queries/sql/read_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v3.0.1 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ReadUserRow {
  ReadUserRow(user_id: Uuid, email: String)
}

/// Runs the `read_user` query
/// defined in `./src/app/queries/sql/read_user.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn read_user(db, arg_1) {
  let decoder = {
    use user_id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    decode.success(ReadUserRow(user_id:, email:))
  }

  "select user_id, email from users
where user_id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
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
  ListUsersRow(user_id: Uuid, email: String)
}

/// Runs the `list_users` query
/// defined in `./src/app/queries/sql/list_users.sql`.
///
/// > 🐿️ This function was generated automatically using v3.0.1 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_users(db) {
  let decoder = {
    use user_id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    decode.success(ListUsersRow(user_id:, email:))
  }

  "select user_id, email from users;
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
