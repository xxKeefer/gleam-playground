# omen_roller

Just a silly little app to learn about backend dev

## Development

### Prerequisites
1. have postgres v17 or later running locally
1. install [dbmate](https://github.com/amacneil/dbmate?tab=readme-ov-file#installation) and run `dbmate up`
1. at the root of the project, create a .env file with your dev secrets. an example can be found in `./.env.example`

```sh
source ./dotenv.sh # loads env variables from .env file
gleam run   # Run the project
```

### Sudoku stuff
`src/app/routes/sudoku.gleam` is my best attempt to follow along with the first four lessons Graham Hutton's [Advanced Functional Programming in Haskell](https://www.youtube.com/playlist?list=PLF1Z-APd9zK5uFc8FKr_di9bfsYv8-lbc) and converting the Haskell taught there into Gleam.