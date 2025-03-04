-- migrate:up
alter table browser_sessions rename to sessions;
alter table sessions drop column ip_address;
alter table sessions drop column user_agent;
alter table sessions drop constraint browser_sessions_user_id_fkey;
alter table sessions add constraint sessions_user_id_fkey foreign key (user_id) references users(id) on delete cascade;

-- update indexes
drop index idx_browser_sessions_user_id;
drop index idx_browser_sessions_session_token;
create index idx_sessions_user_id on sessions(user_id);
create index idx_sessions_session_token on sessions(session_token);

-- migrate:down

alter table sessions rename to browser_sessions;
alter table browser_sessions add column ip_address inet;
alter table browser_sessions add column user_agent text;
alter table browser_sessions drop constraint sessions_user_id_fkey;
alter table browser_sessions add constraint browser_sessions_user_id_fkey foreign key (user_id) references users(user_id) on delete cascade;

-- restore indexes
drop index idx_sessions_user_id;
drop index idx_sessions_session_token;
create index idx_browser_sessions_user_id on browser_sessions(user_id);
create index idx_browser_sessions_session_token on browser_sessions(session_token);