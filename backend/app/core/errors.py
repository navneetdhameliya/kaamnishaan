"""One error shape for every response: {"error": {"code", "message", "details"}}."""

from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class AppError(Exception):
    status = 400

    def __init__(
        self, code: str, message: str, details: dict[str, Any] | None = None, status: int | None = None
    ):
        super().__init__(message)
        self.code, self.message, self.details = code, message, details or {}
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


def _body(code: str, message: str, details: dict[str, Any] | None = None) -> dict:
    return {"error": {"code": code, "message": message, "details": details or {}}}


def install(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(_body(exc.code, exc.message, exc.details), status_code=exc.status)

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        fields = [{"field": ".".join(str(p) for p in e["loc"][1:]), "issue": e["type"]} for e in exc.errors()]
        return JSONResponse(_body("validation_error", "Some fields are not valid.", {"fields": fields}), 422)

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = {404: "not_found", 405: "method_not_allowed"}.get(exc.status_code, "http_error")
        return JSONResponse(_body(code, str(exc.detail)), status_code=exc.status_code)
