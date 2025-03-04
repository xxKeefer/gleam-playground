-- migrate:up
alter table users rename column user_id to id;

-- migrate:down
alter table users rename column id to user_id;