"""One error shape for every response:
{"error": {"code", "message", "fields": {field: issue}, "details": {...}}}.

`details` carries the numbers screens show (attempts_left, locked_until, resend_after, limit, used...).
"""

from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class AppError(Exception):
    status = 400

    def __init__(
        self,
        code: str,
        message: str,
        details: dict[str, Any] | None = None,
        status: int | None = None,
        fields: dict[str, str] | None = None,
    ):
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


def install(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(body(exc.code, exc.message, exc.details, exc.fields), status_code=exc.status)

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        fields = {".".join(str(p) for p in e["loc"][1:]) or "body": e["type"] for e in exc.errors()}
        return JSONResponse(body("validation_error", "Some fields are not valid.", fields=fields), 422)

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = {404: "not_found", 405: "method_not_allowed"}.get(exc.status_code, "http_error")
        return JSONResponse(body(code, str(exc.detail)), status_code=exc.status_code)
