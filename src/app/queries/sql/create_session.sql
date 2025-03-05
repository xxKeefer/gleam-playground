insert into sessions (id, user_id, session_token, created_at, expires_at)
values (
  gen_random_uuid(), 
  $1, 
  $2, 
  now() at time zone 'utc', 
  $3
)
returning user_id, session_token, expires_at;