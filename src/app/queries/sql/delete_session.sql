delete from sessions
where user_id = $1
  and session_token = $2
