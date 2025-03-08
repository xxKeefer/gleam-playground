import app/controllers/user as controller
import app/web.{type Context}
import gleam/http.{Delete, Get, Post}
import wisp.{type Request, type Response}

pub fn all(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> list(req, ctx)
    Post -> create(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn one(req: Request, ctx: Context, id: String) -> Response {
  case req.method {
    Get -> read(req, ctx, id)
    _ -> wisp.method_not_allowed([Get])
  }
}

pub fn create(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)
  controller.create_user(json, req, ctx)
}

pub fn list(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Get)
  controller.list_user(ctx)
}

pub fn read(req: Request, ctx: Context, id: String) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Get)
  controller.read_user(id, ctx)
}

pub fn login(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)
  controller.login_user(json, req, ctx)
}

pub fn logout(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)
  use <- wisp.require_method(req, Delete)
  use json <- wisp.require_json(req)
  controller.logout_user(json, req, ctx)
}
