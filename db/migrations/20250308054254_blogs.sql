-- migrate:up
-- create the accounts table
create table accounts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,
    email text not null references users(email) on delete cascade,
    username text not null,
    updated_at timestamp not null default now()
);

-- create the blog_articles table
create table blog_articles (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    slug text not null unique,
    author_id uuid not null references users(id) on delete cascade,
    created_at timestamp not null default now(),
    updated_at timestamp not null default now(),
    tags text [] default '{}',
    content text not null
);

-- add set_updated_at trigger to accounts table
create trigger set_updated_at_accounts
before update on accounts
for each row
execute function update_updated_at();

-- add set_updated_at trigger to blog_articles table
create trigger set_updated_at_blog_articles
before update on blog_articles
for each row
execute function update_updated_at();

-- add set_updated_at trigger to users table
create trigger set_updated_at_users
before update on users
for each row
execute function update_updated_at();

-- migrate:down
-- drop the triggers from the tables
drop trigger if exists set_updated_at_accounts on accounts;
drop trigger if exists set_updated_at_blog_articles on blog_articles;
drop trigger if exists set_updated_at_users on users;

-- drop the blog_articles table
drop table if exists blog_articles;

-- drop the accounts table
drop table if exists accounts;