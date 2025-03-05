import app/routes/sudoku
import gleam/list
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn empty_sudoku_zero_test() {
  sudoku.empty_sudoku(0)
  |> should.equal([
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
  ])
}

pub fn empty_sudoku_period_test() {
  sudoku.empty_sudoku(".")
  |> should.equal([
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
  ])
}

pub fn rows_is_identity_test() {
  list.range(1, 81)
  |> list.sized_chunk(9)
  |> sudoku.rows
  |> should.equal(list.range(1, 81) |> list.sized_chunk(9))
}

pub fn cols_is_involution_test() {
  list.range(1, 81)
  |> list.sized_chunk(9)
  |> sudoku.cols
  |> sudoku.cols
  |> should.equal(list.range(1, 81) |> list.sized_chunk(9))
}

pub fn select_submatrix_test() {
  list.range(1, 81)
  |> list.sized_chunk(9)
  |> sudoku.select_submatrix(#(1, 1), #(2, 2))
  |> should.equal([[11, 12], [20, 21]])
}

pub fn four_by_four_select_submatrix_test() {
  [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]]
  |> sudoku.select_submatrix(#(1, 1), #(2, 2))
  |> should.equal([[6, 7], [10, 11]])
}

pub fn boxes_is_involution_test() {
  list.range(1, 81)
  |> list.sized_chunk(9)
  |> sudoku.boxes
  |> sudoku.boxes
  |> should.equal(
    list.range(1, 81)
    |> list.sized_chunk(9),
  )
}
