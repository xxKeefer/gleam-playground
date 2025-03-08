import app/controllers/user as controller
import app/web.{type Context}
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
    _ -> wisp.method_not_allowed([Get])
  }
}

pub fn create(req: Request, ctx: Context) -> Response {
  use json <- wisp.require_json(req)
  controller.create_user(json, req, ctx)
}

pub fn list(ctx: Context) -> Response {
  controller.list_user(ctx)
}

pub fn read(ctx: Context, id: String) -> Response {
  controller.read_user(id, ctx)
}

pub fn login(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)
  controller.login_user(json, req, ctx)
}

pub fn logout(req: Request) -> Response {
  use <- wisp.require_method(req, Delete)
  controller.logout_user(req)
}
