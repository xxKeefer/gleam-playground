import gleam/int
import gleam/list
import gleam/result
import gleam/string

// is my best attempt to follow along with the first four lessons Graham Hutton's 
// Advanced Functional Programming in Haskell and converting the Haskell taught there into Gleam.
// see: https://www.youtube.com/playlist?list=PLF1Z-APd9zK5uFc8FKr_di9bfsYv8-lbc) 

// ---[ Types ]--------------------------------------------------------
type Input =
  Int

type Grid =
  Matrix(Input)

type Matrix(a) =
  List(Row(a))

type Row(a) =
  List(a)

type Choices =
  List(Input)

type Transform(a) =
  fn(Matrix(a)) -> Matrix(a)

type Coord =
  #(Int, Int)

// ---[ Parsing and setup ]--------------------------------------------------------

pub fn blank() -> Grid {
  list.repeat(0, times: 9) |> list.repeat(times: 9)
}

pub fn valid_example() -> Grid {
  [
    [1, 2, 3, 4, 5, 6, 7, 8, 9],
    [4, 5, 6, 7, 8, 9, 1, 2, 3],
    [7, 8, 9, 1, 2, 3, 4, 5, 6],
    [2, 3, 4, 5, 6, 7, 8, 9, 1],
    [5, 6, 7, 8, 9, 1, 2, 3, 4],
    [8, 9, 1, 2, 3, 4, 5, 6, 7],
    [3, 4, 5, 6, 7, 8, 9, 1, 2],
    [6, 7, 8, 9, 1, 2, 3, 4, 5],
    [9, 1, 2, 3, 4, 5, 6, 7, 8],
  ]
}

pub fn from_strings(rows: List(String), blank: String) -> Grid {
  let empty: Input = 0

  use row <- list.map(rows)
  string.replace(row, blank, int.to_string(empty))
  |> string.to_graphemes
  |> list.map(fn(str) { int.parse(str) |> result.unwrap(0) })
}

pub fn to_strings(matrix: Grid) -> List(String) {
  {
    use row <- list.map(matrix)
    use el <- list.map(row)
    el |> int.to_string |> string.replace("0", ".")
  }
  |> list.map(string.join(_, ""))
}

// ---[ Matrix Utils ]--------------------------------------------------------

pub fn rows(matrix: Matrix(a)) -> Matrix(a) {
  matrix
}

pub fn cols(matrix: Matrix(a)) -> Matrix(a) {
  list.transpose(matrix)
}

pub fn select_submatrix(matrix: Matrix(a), from: Coord, to: Coord) -> Matrix(a) {
  matrix
  |> list.drop(from.0)
  |> list.take(to.0 - from.0 + 1)
  |> list.map(fn(row) {
    row
    |> list.drop(from.1)
    |> list.take(to.1 - from.1 + 1)
  })
}

pub fn boxes(matrix: Matrix(a)) -> Matrix(a) {
  let indices = [0, 3, 6]

  indices
  |> list.flat_map(fn(i) {
    indices
    |> list.flat_map(fn(j) {
      select_submatrix(matrix, #(i, j), #(i + 2, j + 2))
    })
  })
  |> list.flatten()
  |> list.sized_chunk(9)
}

// ---[ Predicates ]--------------------------------------------------------

fn no_dupes(row: Row(Input)) -> Bool {
  row == list.unique(row)
}

pub fn valid(matrix: Grid) -> Bool {
  validate_property(matrix, has: no_dupes)
}

pub fn voided(matrix: Matrix(Choices)) -> Bool {
  matrix |> list.any(list.any(_, list.is_empty))
}

pub fn safe(matrix: Matrix(Choices)) -> Bool {
  validate_property(matrix, has: consistency)
}

pub fn consistency(row: Row(Choices)) -> Bool {
  row
  |> list.filter(fn(choices) { list.length(choices) == 1 })
  |> list.flatten
  |> no_dupes
}

pub fn cannot_solve(matrix: Matrix(Choices)) -> Bool {
  voided(matrix) || !safe(matrix)
}

pub fn is_solved(matrix: Matrix(Choices)) -> Bool {
  use row <- validate_property(matrix)
  use choices <- list.all(row)
  list.length(choices) == 1
}

fn validate_property(
  matrix: Matrix(a),
  has property: fn(Row(a)) -> Bool,
) -> Bool {
  let rows_valid = matrix |> rows |> list.all(property)
  let cols_valid = matrix |> cols |> list.all(property)
  let boxes_valid = matrix |> boxes |> list.all(property)
  rows_valid && cols_valid && boxes_valid
}

// ---[ Combinations / Choices ]--------------------------------------------------------

pub fn choices(
  matrix: Grid,
  blank blank: Input,
  fill fill: Choices,
) -> Matrix(Choices) {
  matrix
  |> list.map(
    list.map(_, fn(cell) {
      case cell {
        c if c == blank -> fill
        _ -> [cell]
      }
    }),
  )
}

pub fn cartesian_product(matrix: Matrix(a)) -> Matrix(a) {
  case matrix {
    [] -> [[]]
    [head, ..tail] -> {
      let tail_product = cartesian_product(tail)
      use item <- list.flat_map(head)
      use combination <- list.map(tail_product)
      list.prepend(combination, item)
    }
  }
}

pub fn all_possible(matrix: Matrix(List(a))) -> List(Matrix(a)) {
  matrix |> list.map(cartesian_product) |> cartesian_product
}

pub fn first_possible(matrix: Matrix(Choices)) -> List(Matrix(Choices)) {
  let front =
    list.take_while(matrix, fn(row) {
      list.all(row, fn(cell) { list.length(cell) == 1 })
    })

  case list.drop(matrix, list.length(front)) {
    [] -> [matrix]
    [target, ..rest] -> {
      let head = list.take_while(target, fn(cell) { list.length(cell) == 1 })
      case list.drop(target, list.length(head)) {
        [] -> []
        // should not happen if target is unsolved
        [first, ..tail] -> {
          let possible = cartesian_product([first])
          let new_rows =
            list.map(possible, fn(candidate) {
              head |> list.append([candidate]) |> list.append(tail)
            })
          list.map(new_rows, fn(new_row) {
            front |> list.append([new_row, ..rest])
          })
        }
      }
    }
  }
}

// ---[ Reducers ]--------------------------------------------------------

pub fn prune(matrix: Matrix(Choices)) -> Matrix(Choices) {
  matrix |> prune_by(rows) |> prune_by(cols) |> prune_by(boxes)
}

pub fn prune_by(
  matrix: Matrix(Choices),
  transform: Transform(Choices),
) -> Matrix(Choices) {
  matrix |> transform |> list.map(reduce) |> transform
}

pub fn reduce(row: Row(Choices)) -> Row(Choices) {
  case row {
    [head, ..tail] -> {
      let solved =
        list.filter_map(tail, fn(check) {
          case check {
            n -> Ok(n)
          }
        })

      let new_head =
        list.filter(head, fn(element) { !list.contains(solved, [element]) })
      [new_head, ..tail]
    }
    _ -> []
  }
}

// ---[ Helpers]--------------------------------------------------------
// was used in a naive step, no longer require in final function
fn fix(input input: a, func func: fn(a) -> a) -> a {
  case func(input) {
    output if output == input -> output
    again -> fix(again, func)
  }
}

// ---[ Solver ]--------------------------------------------------------

pub fn solve(matrix: Grid, blank blank: Input, fill fill: Choices) -> List(Grid) {
  matrix
  |> choices(blank, fill)
  |> prune
  |> search
}

fn search(matrix: Matrix(Choices)) -> List(Grid) {
  case cannot_solve(matrix) {
    True -> []
    _ ->
      case is_solved(matrix) {
        True -> all_possible(matrix)
        _ ->
          list.flat_map(first_possible(matrix), fn(next) {
            next |> prune |> search
          })
      }
  }
}
