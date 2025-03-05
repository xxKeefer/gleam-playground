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
