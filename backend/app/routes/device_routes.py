"""User-scoped device management endpoints."""

from __future__ import annotations

import uuid
from datetime import timezone

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db_models import DeviceORM, UserORM
from ..schemas import DeviceCreateRequest, DeviceResponse, ErrorResponse


def _serialize_device(device: DeviceORM) -> DeviceResponse:
    created = device.created_at
    if created.tzinfo is None:
        created = created.replace(tzinfo=timezone.utc)
    return DeviceResponse(
        id=device.id,
        user_id=device.user_id,
        category=device.category,
        manufacturer=device.manufacturer,
        model=device.model,
        device_age=device.device_age,
        operating_environment=device.operating_environment,
        created_at=created,
    )


def build_device_router(*, get_db, get_current_user) -> APIRouter:
    router = APIRouter(prefix="/api/v1/devices", tags=["devices"])

    @router.get("")
    def list_devices(
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        rows = db.scalars(
            select(DeviceORM)
            .where(DeviceORM.user_id == current_user.id)
            .order_by(DeviceORM.created_at.desc())
        ).all()
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "items": [_serialize_device(row).model_dump(mode="json") for row in rows],
                "total": len(rows),
            },
        )

    @router.post("", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
    def create_device(
        payload: DeviceCreateRequest,
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        device = DeviceORM(
            id=f"dev_{uuid.uuid4().hex[:12]}",
            user_id=current_user.id,
            category=payload.category,
            manufacturer=payload.manufacturer or "",
            model=payload.model or "",
            device_age=payload.device_age,
            operating_environment=payload.operating_environment,
        )
        db.add(device)
        db.commit()
        db.refresh(device)
        return JSONResponse(
            status_code=status.HTTP_201_CREATED,
            content=_serialize_device(device).model_dump(mode="json"),
        )

    @router.get("/{device_id}", response_model=DeviceResponse)
    def get_device(
        device_id: str,
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        device = db.scalar(
            select(DeviceORM).where(
                DeviceORM.id == device_id,
                DeviceORM.user_id == current_user.id,
            )
        )
        if device is None:
            return JSONResponse(
                status_code=status.HTTP_404_NOT_FOUND,
                content=ErrorResponse(
                    code="DEVICE_NOT_FOUND",
                    message="Device not found for the authenticated user.",
                ).model_dump(),
            )
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=_serialize_device(device).model_dump(mode="json"),
        )

    @router.delete("/{device_id}")
    def delete_device(
        device_id: str,
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        device = db.scalar(
            select(DeviceORM).where(
                DeviceORM.id == device_id,
                DeviceORM.user_id == current_user.id,
            )
        )
        if device is None:
            return JSONResponse(
                status_code=status.HTTP_404_NOT_FOUND,
                content=ErrorResponse(
                    code="DEVICE_NOT_FOUND",
                    message="Device not found for the authenticated user.",
                ).model_dump(),
            )
        db.delete(device)
        db.commit()
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"status": "deleted", "device_id": device_id},
        )

    return router
