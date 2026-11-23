"""One error shape for every response:
{"error": {"code", "message", "fields": {field: issue}, "details": {...}}}.

`details` carries the numbers screens show (attempts_left, locked_until, resend_after, limit, used...).
"""

from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.messages import pick_language, translate


class AppError(Exception):
    status = 400

    def __init__(
        self,
        code: str,
        message: str,
        details: dict[str, Any] | None = None,
        status: int | None = None,
        fields: dict[str, str] | None = None,
        params: dict[str, Any] | None = None,
    ):
        # `message` is a fixed English sentence, so it can be translated (app/content/messages); values that
        # change go in `params` as {name} placeholders and are filled in after translating.
        self.template, self.params = message, params or {}
        message = message.format(**self.params) if self.params else message
        super().__init__(message)
        self.code, self.message, self.details, self.fields = code, message, details or {}, fields or {}
        if status:
            self.status = status


class Unauthorized(AppError):
    status = 401


class Forbidden(AppError):
    status = 403


class NotFound(AppError):
    status = 404


class Conflict(AppError):
    status = 409


class Gone(AppError):
    status = 410


class PlanLimit(AppError):
    status = 402


class RateLimited(AppError):
    status = 429


def body(code: str, message: str, details: dict | None = None, fields: dict | None = None) -> dict:
    return {"error": {"code": code, "message": message, "fields": fields or {}, "details": details or {}}}


def _reply(request: Request, status: int, code: str, template: str, **kw: Any) -> JSONResponse:
    """The error body, its message in the language the request asked for (D-137)."""
    lang = pick_language(request.headers.get("accept-language"))
    message = translate(template, lang, kw.pop("params", None))
    return JSONResponse(body(code, message, **kw), status_code=status, headers={"Content-Language": lang})


def install(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(request: Request, exc: AppError) -> JSONResponse:
        extra = {"details": exc.details, "fields": exc.fields, "params": exc.params}
        return _reply(request, exc.status, exc.code, exc.template, **extra)

    @app.exception_handler(RequestValidationError)
    async def _validation(request: Request, exc: RequestValidationError) -> JSONResponse:
        fields = {".".join(str(p) for p in e["loc"][1:]) or "body": e["type"] for e in exc.errors()}
        return _reply(request, 422, "validation_error", "Some fields are not valid.", fields=fields)

    @app.exception_handler(StarletteHTTPException)
    async def _http(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = {404: "not_found", 405: "method_not_allowed"}.get(exc.status_code, "http_error")
        template = {404: "Not found.", 405: "This action isn't allowed."}.get(
            exc.status_code, "Something went wrong."
        )
        return _reply(request, exc.status_code, code, template)
