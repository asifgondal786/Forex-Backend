from __future__ import annotations

from enum import Enum

from pydantic import BaseModel, Field


class SectorCode(str, Enum):
    military = "military"
    education = "education"
    industry = "industry"


class SectorSummary(BaseModel):
    code: SectorCode
    label: str
    headline: str
    default_modules: list[str] = Field(default_factory=list)


class DeliveryPhase(BaseModel):
    code: str
    title: str
    status: str
    description: str


class DepartmentSummary(BaseModel):
    id: str
    name: str
    code: str
    category: str
    lead_role: str
    headcount: int
    active_workflows: int
    health: str


class RoleSummary(BaseModel):
    id: str
    title: str
    code: str
    hierarchy_level: int
    reports_to: str | None = None
    permissions: list[str] = Field(default_factory=list)


class HierarchyNode(BaseModel):
    id: str
    label: str
    title: str
    code: str
    level: int
    headcount: int
    leader_role: str
    children: list["HierarchyNode"] = Field(default_factory=list)


class DashboardMetric(BaseModel):
    id: str
    label: str
    value: str
    trend: str | None = None
    status: str = "info"


class DashboardPanel(BaseModel):
    id: str
    title: str
    description: str
    metrics: list[DashboardMetric] = Field(default_factory=list)


class OrganizationSummary(BaseModel):
    id: str
    name: str
    sector: SectorCode
    deployment_mode: str
    command_model: str
    tenant_key: str
    active_users: int
    department_count: int
    hierarchy_depth: int
    priority_modules: list[str] = Field(default_factory=list)


class OrganizationDetail(OrganizationSummary):
    description: str
    departments: list[DepartmentSummary] = Field(default_factory=list)
    top_roles: list[RoleSummary] = Field(default_factory=list)


class DashboardSummary(BaseModel):
    organization_id: str
    command_snapshot: list[DashboardMetric] = Field(default_factory=list)
    alerts: list[str] = Field(default_factory=list)
    panels: list[DashboardPanel] = Field(default_factory=list)


class EcmsOverviewResponse(BaseModel):
    mission: str
    current_focus: str
    supported_sectors: list[SectorSummary] = Field(default_factory=list)
    foundation_modules: list[str] = Field(default_factory=list)
    delivery_phases: list[DeliveryPhase] = Field(default_factory=list)
    organizations: list[OrganizationSummary] = Field(default_factory=list)


HierarchyNode.model_rebuild()
