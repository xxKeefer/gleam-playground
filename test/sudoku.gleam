import app/routes/sudoku
import gleam/list
import gleeunit/should

pub fn blank_zero_test() {
  sudoku.blank()
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

pub fn rows_is_identity_test() {
  sudoku.valid_example()
  |> sudoku.rows
  |> should.equal(sudoku.valid_example())
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
  sudoku.valid_example()
  |> sudoku.boxes
  |> sudoku.boxes
  |> should.equal(sudoku.valid_example())
}

pub fn valid_test() {
  sudoku.valid_example() |> sudoku.valid |> should.equal(True)
}

pub fn invalid_test() {
  sudoku.blank() |> sudoku.valid |> should.equal(False)
}

pub fn two_by_two_choices_test() {
  let matrix = [[1, 1], [1, 0]]
  sudoku.choices(matrix, blank: 0, fill: list.range(1, 2))
  |> should.equal([[[1], [1]], [[1], [1, 2]]])
}

pub fn cartesian_product_test() {
  [[1, 2], [3, 4], [5, 6]]
  |> sudoku.cartesian_product
  |> should.equal([
    [1, 3, 5],
    [1, 3, 6],
    [1, 4, 5],
    [1, 4, 6],
    [2, 3, 5],
    [2, 3, 6],
    [2, 4, 5],
    [2, 4, 6],
  ])
}

pub fn two_options_cartesian_product_test() {
  [[1, 2], [1, 2]]
  |> sudoku.cartesian_product
  |> should.equal([[1, 1], [1, 2], [2, 1], [2, 2]])
}

pub fn two_by_two_all_possible_test() {
  [
    [[1], [1, 2]],
    //
    [[2], [1, 2]],
    //
  ]
  |> sudoku.all_possible
  |> should.equal([
    [[1, 1], [2, 1]],
    [[1, 1], [2, 2]],
    [[1, 2], [2, 1]],
    [[1, 2], [2, 2]],
  ])
}

pub fn first_possible_test() {
  [
    //
    [[1, 2], [1]],
    //
    [[2], [1, 2]],
  ]
  |> sudoku.first_possible
  |> should.equal([[[[1], [1]], [[2], [1, 2]]], [[[2], [1]], [[2], [1, 2]]]])
}

pub fn single_reduce_test() {
  [[1, 2, 3, 4], [1], [3, 4], [3]]
  |> sudoku.reduce
  |> should.equal([[2, 4], [1], [3, 4], [3]])
}

pub fn consistency_true_test() {
  [[1, 2, 3, 4], [1], [3, 4], [3]] |> sudoku.consistency |> should.be_true
}

pub fn consistency_false_test() {
  [[1, 2, 3, 4], [1], [3, 4], [1]] |> sudoku.consistency |> should.be_false
}

pub fn voided_true_test() {
  [[[1, 2, 3, 4], [1], [3, 4], []]] |> sudoku.voided |> should.be_true
}

pub fn voided_false_test() {
  [[[1, 2, 3, 4], [1], [3, 4], [1]]] |> sudoku.voided |> should.be_false
}

pub fn cannot_solve_valid_example_test() {
  [sudoku.valid_example()] |> sudoku.cannot_solve |> should.be_false
}

pub fn cannot_solve_false_test() {
  [
    sudoku.from_strings(
      [
        "2....1.38", "........5", ".7...6...", ".......13", ".981..257",
        "31....8..", "9..8...2.", ".5..69784", "4..25....",
      ],
      ".",
    ),
  ]
  |> sudoku.cannot_solve
  |> should.be_false
}

pub fn cannot_safe_example_test() {
  [sudoku.valid_example()] |> sudoku.safe |> should.be_true
}

pub fn solve_solved_test() {
  sudoku.valid_example()
  |> sudoku.solve(0, list.range(1, 9))
  |> should.equal([sudoku.valid_example()])
}

pub fn solve_test() {
  [
    [1, 0, 3, 4, 0, 6, 7, 8, 0],
    [0, 0, 0, 0, 8, 9, 1, 2, 3],
    [0, 0, 0, 1, 2, 3, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 8, 0, 1],
    [0, 0, 0, 8, 9, 1, 2, 3, 4],
    [0, 0, 0, 2, 3, 4, 5, 0, 7],
    [0, 0, 0, 6, 0, 8, 0, 1, 2],
    [0, 0, 0, 9, 1, 2, 3, 0, 5],
    [0, 0, 0, 3, 4, 5, 0, 7, 0],
  ]
  |> sudoku.solve(0, list.range(1, 9))
  |> list.map(sudoku.valid)
  |> list.all(fn(x) { x })
  |> should.be_true
}

pub fn solve_from_string_test() {
  sudoku.from_strings(
    [
      "1.34.678.", "....89123", "...123...", "......8.1", "...891234",
      "...2345.7", "...6.8.12", "...9123.5", "...345.7.",
    ],
    ".",
  )
  |> sudoku.solve(0, list.range(1, 9))
  |> list.map(sudoku.valid)
  |> list.all(fn(x) { x })
  |> should.be_true
}
