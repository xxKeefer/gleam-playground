# Naming convention for queries

all `*.sql` files in the `src/app/queries/sql` folder shall be named using the following pattern: `{controller}_{action}.sql` where controller is the name of a file in `src/app/controllers`

## Examples
- blog_create.sql
- user_list.sql
- user_session_delete.sql

## Rationale
keep the file structure flat and self organised