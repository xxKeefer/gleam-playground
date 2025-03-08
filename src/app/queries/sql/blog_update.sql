update blog_articles
set content = $2, title = $3, slug = $4, tags = $5
where id = $1;