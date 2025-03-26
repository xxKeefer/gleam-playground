import app/auth.{type Context}
import app/controllers/blog as controller
import gleam/http.{Delete, Get, Post}
import wisp.{type Request, type Response}

pub fn all(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> list(ctx)
    Post -> create(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn one(req: Request, ctx: Context, id: String) -> Response {
  case req.method {
    Get -> read(ctx, id)
    Delete -> delete(ctx, id)
    Post -> update(req, ctx, id)
    _ -> wisp.method_not_allowed([Get, Post, Delete])
  }
}

pub fn create(req: Request, ctx: Context) -> Response {
  use json <- wisp.require_json(req)
  controller.create_blog(json, ctx)
}

pub fn list(ctx: Context) -> Response {
  controller.list_blog(ctx)
}

pub fn read(ctx: Context, id: String) -> Response {
  controller.read_blog(id, ctx)
}

pub fn delete(ctx: Context, id: String) -> Response {
  controller.delete_blog(id, ctx)
}

pub fn update(req: Request, ctx: Context, id: String) -> Response {
  use json <- wisp.require_json(req)
  controller.update_blog(id, json, ctx)
}
