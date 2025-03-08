import app/routes/roll
import app/routes/sudoku
import app/routes/user
import app/web.{type Context}
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    ["roll"] -> roll.handle_roll_dice(req)
    ["user"] -> user.all(req, ctx)
    ["user", "login"] -> user.login(req, ctx)
    ["user", "logout"] -> user.logout(req)
    ["user", id] -> user.one(req, ctx, id)
    ["sudoku"] -> sudoku.handle_solve(req)
    _ -> wisp.not_found()
  }
}
