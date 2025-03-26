insert into blog_articles (
  id,
  title,
  slug,
  author_id,
  created_at,
  updated_at,
  tags,
  content
)
values (
  gen_random_uuid(), 
  $1, 
  $2, 
  $3, 
  now() at time zone 'utc', 
  now() at time zone 'utc',
  $4,
  $5
)
returning *;