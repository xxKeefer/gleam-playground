import app/auth.{type Context}
import app/routes/roll
import app/routes/sudoku
import app/routes/user
import app/web

// import gleam/io
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, static_base_context: Context) -> Response {
  use req <- web.middleware(req)
  use req, ctx <- auth.middleware(req, static_base_context)

  case wisp.path_segments(req) {
    ["roll"] -> roll.handle_roll_dice(req)
    ["user"] -> user.all(req, ctx)
    ["user", "login"] -> user.login(req, ctx)
    ["user", "logout"] -> user.logout(req)
    ["user", "cool"] -> user.example_protected(req, ctx)
    ["user", id] -> user.one(req, ctx, id)
    ["sudoku"] -> sudoku.handle_solve(req)
    _ -> wisp.not_found()
  }
}
