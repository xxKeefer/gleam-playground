select id, email, password_hash from users
where id = $1;
