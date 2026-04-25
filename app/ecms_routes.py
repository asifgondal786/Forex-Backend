from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query

from app.schemas.ecms import (
    DashboardSummary,
    EcmsOverviewResponse,
    HierarchyNode,
    OrganizationDetail,
    OrganizationSummary,
    RoleSummary,
    SectorCode,
    DepartmentSummary,
)
from app.services.ecms_service import ecms_service

router = APIRouter(prefix="/api/ecms", tags=["ECMS"])


def _not_found(organization_id: str) -> HTTPException:
    return HTTPException(
        status_code=404,
        detail=f"Unknown ECMS organization '{organization_id}'",
    )


@router.get("/overview", response_model=EcmsOverviewResponse)
async def get_overview(
    sector: SectorCode | None = Query(default=None),
) -> EcmsOverviewResponse:
    return ecms_service.get_overview(sector=sector)


@router.get("/organizations", response_model=list[OrganizationSummary])
async def list_organizations(
    sector: SectorCode | None = Query(default=None),
) -> list[OrganizationSummary]:
    return ecms_service.list_organizations(sector=sector)


@router.get("/organizations/{organization_id}", response_model=OrganizationDetail)
async def get_organization(organization_id: str) -> OrganizationDetail:
    organization = ecms_service.get_organization(organization_id)
    if organization is None:
        raise _not_found(organization_id)
    return organization


@router.get(
    "/organizations/{organization_id}/departments",
    response_model=list[DepartmentSummary],
)
async def get_departments(organization_id: str) -> list[DepartmentSummary]:
    departments = ecms_service.get_departments(organization_id)
    if departments is None:
        raise _not_found(organization_id)
    return departments


@router.get("/organizations/{organization_id}/roles", response_model=list[RoleSummary])
async def get_roles(organization_id: str) -> list[RoleSummary]:
    roles = ecms_service.get_roles(organization_id)
    if roles is None:
        raise _not_found(organization_id)
    return roles


@router.get("/organizations/{organization_id}/hierarchy", response_model=HierarchyNode)
async def get_hierarchy(organization_id: str) -> HierarchyNode:
    hierarchy = ecms_service.get_hierarchy(organization_id)
    if hierarchy is None:
        raise _not_found(organization_id)
    return hierarchy


@router.get("/organizations/{organization_id}/dashboard", response_model=DashboardSummary)
async def get_dashboard(organization_id: str) -> DashboardSummary:
    dashboard = ecms_service.get_dashboard(organization_id)
    if dashboard is None:
        raise _not_found(organization_id)
    return dashboard
