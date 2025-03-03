-- migrate:up

-- a trigger function function to update the updated_at column to the current
-- time. this is to be used in a trigger on the tables to be updated.
create or replace function update_updated_at()
  returns trigger as $$
begin
  new.updated_at = now() at time zone 'utc';
  return new;
end
$$ language plpgsql;

create table users (
  user_id uuid primary key default gen_random_uuid(),
  email text unique not null, 
  password_hash text not null, 
  created_at timestamp not null, 
  updated_at timestamp not null,
  last_login timestamp
);

create trigger users_updated_at
  before update on users
  for each row
  execute procedure update_updated_at();

create table browser_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(user_id) on delete cascade,
  session_token text not null unique,
  ip_address inet,
  user_agent text,
  created_at timestamp default now(),
  expires_at timestamp not null
);

create index idx_browser_sessions_user_id on browser_sessions(user_id);
create index idx_browser_sessions_session_token on browser_sessions(session_token);

-- migrate:down
drop table if exists browser_sessions;
drop table users;
drop function update_updated_at();