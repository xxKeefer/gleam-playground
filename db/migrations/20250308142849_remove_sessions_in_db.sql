-- migrate:up
drop index idx_sessions_user_id;
drop index idx_sessions_session_token;
drop table if exists sessions


-- migrate:down
create table sessions (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  session_token text not null,
  created_at timestamp without time zone default now(),
  expires_at timestamp without time zone not null
);

create index idx_sessions_user_id on sessions(user_id);
create index idx_sessions_session_token on sessions(session_token);