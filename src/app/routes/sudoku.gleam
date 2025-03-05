import gleam/list

type Matrix(value) =
  List(Row(value))

type Row(value) =
  List(value)

pub fn empty_sudoku(fill: value) -> Matrix(value) {
  list.repeat(fill, times: 9) |> list.repeat(times: 9)
}

pub fn rows(matrix: Matrix(value)) -> List(Row(value)) {
  matrix
}

pub fn cols(matrix: Matrix(value)) -> List(Row(value)) {
  list.transpose(matrix)
}

type Coord =
  #(Int, Int)

pub fn select_submatrix(
  matrix: Matrix(value),
  from: Coord,
  to: Coord,
) -> Matrix(value) {
  matrix
  |> list.drop(from.0)
  |> list.take(to.0 - from.0 + 1)
  |> list.map(fn(row) {
    row
    |> list.drop(from.1)
    |> list.take(to.1 - from.1 + 1)
  })
}

pub fn boxes(matrix: Matrix(value)) -> Matrix(value) {
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
