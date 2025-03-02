import app/routes/roll
import app/web
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    ["roll"] -> roll.handle_roll_dice(req)
    _ -> wisp.not_found()
  }
}
