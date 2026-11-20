"""A30 Analytics: how companies use KaamNishaan over a period, compared with the period before."""

from datetime import date

from pydantic import BaseModel, Field


class Metric(BaseModel):
    value: float | None = Field(description="null when there is nothing to measure yet")
    previous: float | None


class Bucket(BaseModel):
    start: date
    count: int


class Share(BaseModel):
    key: str = Field(description="language code or industry slug; 'other' for the rest")
    label: str | None = Field(None, description="industry name in the asked language")
    count: int


class AdminAnalyticsOut(BaseModel):
    days: int
    reports_sent: Metric
    review_minutes: Metric = Field(description="median time from submitted to approved")
    first_time: Metric = Field(description="% of approved reports that needed no changes")
    active_technicians: Metric = Field(description="people who took photos or voice notes")
    step: str = Field(description="day or week")
    sent_by_period: list[Bucket]
    voice_languages: list[Share]
    voice_total: int
    reports_by_industry: list[Share]
