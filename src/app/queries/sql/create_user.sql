insert into users (user_id, email, password_hash, created_at, updated_at)
values (
  gen_random_uuid(), 
  $1, 
  $2, 
  now() at time zone 'utc', 
  now() at time zone 'utc'
)
returning user_id, email;