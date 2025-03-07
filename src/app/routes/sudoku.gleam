import app/controllers/sudoku.{from_strings, solve, to_strings}
import app/web
import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/json
import gleam/list
import wisp.{type Request, type Response}

pub type SudokuPayload {
  SudokuPayload(grid: List(String), blank: String)
}

fn sudoku_payload_decoder() -> decode.Decoder(SudokuPayload) {
  use grid <- decode.field("grid", decode.list(decode.string))
  use blank <- decode.field("blank", decode.string)
  let payload = SudokuPayload(grid, blank)
  decode.success(payload)
}

pub fn handle_solve(req: Request) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)

  case decode.run(json, sudoku_payload_decoder()) {
    Ok(puzzle) -> {
      let solutions =
        puzzle.grid
        |> from_strings(puzzle.blank)
        |> solve(0, list.range(1, 9))
        |> list.map(to_strings)
      let payload =
        solutions
        |> json.array(json.array(_, json.string))
        |> fn(array) { json.object([#("solutions", array)]) }
        |> json.to_string_tree
      wisp.json_response(payload, 200)
    }
    _ -> wisp.unprocessable_entity()
  }
}
