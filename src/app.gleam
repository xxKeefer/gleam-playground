import app/router
import app/web
import envoy
import gleam/erlang/process
import gleam/result
import mist
import pog
import wisp
import wisp/wisp_mist

pub fn main() {
  // This sets the logger to print INFO level logs, and other sensible defaults
  // for a web application.
  wisp.configure_logger()

  let assert Ok(db) = read_connection_uri()
  let assert Ok(secret_key) = envoy.get("SECRET_KEY")
  let context = web.Context(db: db, secret: secret_key)

  // The handle_request function is partially applied with the context to make
  // the request handler function that only takes a request.
  let handler = router.handle_request(_, context)

  // Start the Mist web server.
  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.sleep_forever()
}

fn read_connection_uri() -> Result(pog.Connection, Nil) {
  use database_url <- result.try(envoy.get("DATABASE_URL"))
  use config <- result.try(pog.url_config(database_url))
  Ok(pog.connect(config))
}
