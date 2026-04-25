from __future__ import annotations

from app.schemas.ecms import (
    DashboardMetric,
    DashboardPanel,
    DashboardSummary,
    DeliveryPhase,
    DepartmentSummary,
    EcmsOverviewResponse,
    HierarchyNode,
    OrganizationDetail,
    OrganizationSummary,
    RoleSummary,
    SectorCode,
    SectorSummary,
)


def _metric(
    metric_id: str,
    label: str,
    value: str,
    *,
    trend: str | None = None,
    status: str = "info",
) -> DashboardMetric:
    return DashboardMetric(
        id=metric_id,
        label=label,
        value=value,
        trend=trend,
        status=status,
    )


class ECMSService:
    """Seed-backed foundation slice for the first ECMS implementation phase."""

    def __init__(self) -> None:
        self._supported_sectors = [
            SectorSummary(
                code=SectorCode.military,
                label="Military & Tri-Forces",
                headline="Command-critical operations, logistics, intelligence, and crisis response.",
                default_modules=[
                    "personnel",
                    "operations",
                    "weapons_registry",
                    "medical_corps",
                    "crisis_command",
                ],
            ),
            SectorSummary(
                code=SectorCode.education,
                label="Schools, Colleges & Universities",
                headline="Admissions, academics, attendance, exams, parent engagement, and finance.",
                default_modules=[
                    "admissions",
                    "academics",
                    "attendance",
                    "examinations",
                    "parent_portal",
                ],
            ),
            SectorSummary(
                code=SectorCode.industry,
                label="Factories, Mills & Large-Scale Companies",
                headline="Production, quality, maintenance, warehouse, procurement, and HSE.",
                default_modules=[
                    "production",
                    "supply_chain",
                    "warehouse",
                    "maintenance",
                    "quality_assurance",
                ],
            ),
        ]

        self._delivery_phases = [
            DeliveryPhase(
                code="phase_1",
                title="Foundation",
                status="active",
                description="Auth, hierarchy engine, org portal structure, and basic dashboard APIs.",
            ),
            DeliveryPhase(
                code="phase_2",
                title="Communication",
                status="planned",
                description="Department chat, broadcast board, notices, and grievance flows.",
            ),
            DeliveryPhase(
                code="phase_3",
                title="Task & Workflow",
                status="planned",
                description="Assignments, approvals, SLAs, escalation rules, and audit trails.",
            ),
        ]

        self._organizations = self._build_organizations()
        self._hierarchies = self._build_hierarchies()
        self._roles = self._build_roles()
        self._dashboards = self._build_dashboards()

    def get_overview(self, sector: SectorCode | None = None) -> EcmsOverviewResponse:
        organizations = self.list_organizations(sector=sector)
        return EcmsOverviewResponse(
            mission=(
                "Build a unified, role-aware command platform that can serve military, "
                "education, and industry without losing sector-specific workflows."
            ),
            current_focus=(
                "Phase 1 foundation is live in seed form: organization directory, "
                "hierarchy engine, role catalog, departments, and dashboard summaries."
            ),
            supported_sectors=[item.model_copy(deep=True) for item in self._supported_sectors],
            foundation_modules=[
                "multi-sector tenant directory",
                "command hierarchy tree",
                "department registry",
                "role catalog",
                "dashboard summary cards",
            ],
            delivery_phases=[item.model_copy(deep=True) for item in self._delivery_phases],
            organizations=organizations,
        )

    def list_organizations(
        self,
        sector: SectorCode | None = None,
    ) -> list[OrganizationSummary]:
        organizations = [
            self._summarize_organization(org)
            for org in self._organizations.values()
            if sector is None or org.sector == sector
        ]
        return sorted(organizations, key=lambda organization: organization.name)

    def get_organization(self, organization_id: str) -> OrganizationDetail | None:
        organization = self._organizations.get(organization_id)
        if organization is None:
            return None
        return organization.model_copy(deep=True)

    def get_departments(self, organization_id: str) -> list[DepartmentSummary] | None:
        organization = self._organizations.get(organization_id)
        if organization is None:
            return None
        return [department.model_copy(deep=True) for department in organization.departments]

    def get_roles(self, organization_id: str) -> list[RoleSummary] | None:
        roles = self._roles.get(organization_id)
        if roles is None:
            return None
        return [role.model_copy(deep=True) for role in roles]

    def get_hierarchy(self, organization_id: str) -> HierarchyNode | None:
        hierarchy = self._hierarchies.get(organization_id)
        if hierarchy is None:
            return None
        return hierarchy.model_copy(deep=True)

    def get_dashboard(self, organization_id: str) -> DashboardSummary | None:
        dashboard = self._dashboards.get(organization_id)
        if dashboard is None:
            return None
        return dashboard.model_copy(deep=True)

    def _summarize_organization(self, organization: OrganizationDetail) -> OrganizationSummary:
        return OrganizationSummary(
            id=organization.id,
            name=organization.name,
            sector=organization.sector,
            deployment_mode=organization.deployment_mode,
            command_model=organization.command_model,
            tenant_key=organization.tenant_key,
            active_users=organization.active_users,
            department_count=organization.department_count,
            hierarchy_depth=organization.hierarchy_depth,
            priority_modules=list(organization.priority_modules),
        )

    def _build_organizations(self) -> dict[str, OrganizationDetail]:
        organizations = [
            OrganizationDetail(
                id="pak_tri_force_command",
                name="Pakistan Tri-Force Command",
                sector=SectorCode.military,
                description=(
                    "Seed tenant for military workflows with operational command, logistics, "
                    "signals, medical, and finance visibility."
                ),
                deployment_mode="hybrid",
                command_model="strict_chain_of_command",
                tenant_key="pak-tri-force",
                active_users=14820,
                department_count=6,
                hierarchy_depth=4,
                priority_modules=[
                    "personnel",
                    "operations",
                    "intelligence",
                    "weapons_registry",
                    "crisis_command",
                ],
                departments=[
                    DepartmentSummary(
                        id="mil_ops",
                        name="Operations Command",
                        code="OPS",
                        category="operations",
                        lead_role="Chief of Operations",
                        headcount=4200,
                        active_workflows=89,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="mil_intel",
                        name="Intelligence & Signals",
                        code="INT",
                        category="security",
                        lead_role="Director Intelligence",
                        headcount=1300,
                        active_workflows=37,
                        health="elevated",
                    ),
                    DepartmentSummary(
                        id="mil_log",
                        name="Logistics & Supply",
                        code="LOG",
                        category="supply_chain",
                        lead_role="Logistics Commander",
                        headcount=2900,
                        active_workflows=58,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="mil_med",
                        name="Medical Corps",
                        code="MED",
                        category="medical",
                        lead_role="Surgeon General",
                        headcount=940,
                        active_workflows=24,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="mil_arm",
                        name="Weapons & Armory",
                        code="ARM",
                        category="inventory",
                        lead_role="Armory Director",
                        headcount=610,
                        active_workflows=43,
                        health="watch",
                    ),
                    DepartmentSummary(
                        id="mil_fin",
                        name="Finance & Pay",
                        code="FIN",
                        category="finance",
                        lead_role="Pay Controller",
                        headcount=410,
                        active_workflows=31,
                        health="stable",
                    ),
                ],
                top_roles=[
                    RoleSummary(
                        id="role_supreme_commander",
                        title="Supreme Commander",
                        code="SCOM",
                        hierarchy_level=1,
                        permissions=["tenant.manage", "command.override", "broadcast.all"],
                    ),
                    RoleSummary(
                        id="role_force_commander",
                        title="Force Commander",
                        code="FCOM",
                        hierarchy_level=2,
                        reports_to="Supreme Commander",
                        permissions=["operations.approve", "personnel.assign", "dashboard.view"],
                    ),
                    RoleSummary(
                        id="role_unit_commander",
                        title="Unit Commander",
                        code="UCOM",
                        hierarchy_level=3,
                        reports_to="Force Commander",
                        permissions=["task.assign", "ops.execute", "incidents.report"],
                    ),
                ],
            ),
            OrganizationDetail(
                id="national_education_network",
                name="National Education Network",
                sector=SectorCode.education,
                description=(
                    "Seed tenant for schools, colleges, and universities with admissions, "
                    "academics, exams, parent communication, and finance modules."
                ),
                deployment_mode="cloud_saas",
                command_model="academic_hierarchy",
                tenant_key="national-education-network",
                active_users=9210,
                department_count=7,
                hierarchy_depth=5,
                priority_modules=[
                    "admissions",
                    "academics",
                    "attendance",
                    "examinations",
                    "parent_portal",
                ],
                departments=[
                    DepartmentSummary(
                        id="edu_adm",
                        name="Admissions",
                        code="ADM",
                        category="student_lifecycle",
                        lead_role="Director Admissions",
                        headcount=180,
                        active_workflows=46,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="edu_aca",
                        name="Academic Affairs",
                        code="ACA",
                        category="academics",
                        lead_role="Dean Academics",
                        headcount=880,
                        active_workflows=114,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="edu_exam",
                        name="Examinations",
                        code="EXM",
                        category="assessment",
                        lead_role="Controller of Examinations",
                        headcount=220,
                        active_workflows=61,
                        health="watch",
                    ),
                    DepartmentSummary(
                        id="edu_lib",
                        name="Library Services",
                        code="LIB",
                        category="resources",
                        lead_role="Chief Librarian",
                        headcount=95,
                        active_workflows=18,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="edu_hostel",
                        name="Hostel & Student Life",
                        code="HST",
                        category="student_affairs",
                        lead_role="Director Student Affairs",
                        headcount=140,
                        active_workflows=29,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="edu_parent",
                        name="Parent & Guardian Services",
                        code="PGS",
                        category="communication",
                        lead_role="Parent Portal Lead",
                        headcount=52,
                        active_workflows=34,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="edu_fin",
                        name="Accounts & Finance",
                        code="FIN",
                        category="finance",
                        lead_role="Finance Director",
                        headcount=130,
                        active_workflows=41,
                        health="stable",
                    ),
                ],
                top_roles=[
                    RoleSummary(
                        id="role_chancellor",
                        title="Chancellor",
                        code="CHAN",
                        hierarchy_level=1,
                        permissions=["tenant.manage", "policy.approve", "broadcast.all"],
                    ),
                    RoleSummary(
                        id="role_principal",
                        title="Principal",
                        code="PRIN",
                        hierarchy_level=2,
                        reports_to="Chancellor",
                        permissions=["academics.approve", "staff.assign", "dashboard.view"],
                    ),
                    RoleSummary(
                        id="role_hod",
                        title="Head of Department",
                        code="HOD",
                        hierarchy_level=3,
                        reports_to="Principal",
                        permissions=["timetable.manage", "attendance.review", "results.publish"],
                    ),
                ],
            ),
            OrganizationDetail(
                id="atlas_industrial_group",
                name="Atlas Industrial Group",
                sector=SectorCode.industry,
                description=(
                    "Seed tenant for large-scale industrial operations with production, "
                    "procurement, maintenance, warehouse, QA, and HSE command structures."
                ),
                deployment_mode="on_premise",
                command_model="executive_to_shopfloor",
                tenant_key="atlas-industrial-group",
                active_users=6340,
                department_count=8,
                hierarchy_depth=5,
                priority_modules=[
                    "production",
                    "supply_chain",
                    "warehouse",
                    "maintenance",
                    "quality_assurance",
                ],
                departments=[
                    DepartmentSummary(
                        id="ind_prod",
                        name="Production",
                        code="PRD",
                        category="operations",
                        lead_role="Plant Director",
                        headcount=2140,
                        active_workflows=138,
                        health="watch",
                    ),
                    DepartmentSummary(
                        id="ind_qa",
                        name="Quality Assurance",
                        code="QAS",
                        category="quality",
                        lead_role="QA Head",
                        headcount=310,
                        active_workflows=57,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="ind_maint",
                        name="Maintenance & Engineering",
                        code="MNT",
                        category="maintenance",
                        lead_role="Maintenance Manager",
                        headcount=460,
                        active_workflows=74,
                        health="watch",
                    ),
                    DepartmentSummary(
                        id="ind_supply",
                        name="Supply Chain & Procurement",
                        code="SCP",
                        category="supply_chain",
                        lead_role="Procurement Director",
                        headcount=285,
                        active_workflows=63,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="ind_warehouse",
                        name="Warehouse & Dispatch",
                        code="WHS",
                        category="inventory",
                        lead_role="Warehouse Lead",
                        headcount=540,
                        active_workflows=49,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="ind_hse",
                        name="Safety & HSE",
                        code="HSE",
                        category="compliance",
                        lead_role="HSE Manager",
                        headcount=120,
                        active_workflows=26,
                        health="elevated",
                    ),
                    DepartmentSummary(
                        id="ind_hr",
                        name="HR & Labour",
                        code="HRL",
                        category="human_resources",
                        lead_role="HR Director",
                        headcount=155,
                        active_workflows=33,
                        health="stable",
                    ),
                    DepartmentSummary(
                        id="ind_fin",
                        name="Accounts & ERP",
                        code="ERP",
                        category="finance",
                        lead_role="Finance Controller",
                        headcount=104,
                        active_workflows=38,
                        health="stable",
                    ),
                ],
                top_roles=[
                    RoleSummary(
                        id="role_ceo",
                        title="Chief Executive Officer",
                        code="CEO",
                        hierarchy_level=1,
                        permissions=["tenant.manage", "strategy.approve", "budget.override"],
                    ),
                    RoleSummary(
                        id="role_coo",
                        title="Chief Operating Officer",
                        code="COO",
                        hierarchy_level=2,
                        reports_to="Chief Executive Officer",
                        permissions=["production.approve", "maintenance.review", "dashboard.view"],
                    ),
                    RoleSummary(
                        id="role_plant_manager",
                        title="Plant Manager",
                        code="PLANT",
                        hierarchy_level=3,
                        reports_to="Chief Operating Officer",
                        permissions=["shift.manage", "quality.review", "dispatch.release"],
                    ),
                ],
            ),
        ]

        return {organization.id: organization for organization in organizations}

    def _build_hierarchies(self) -> dict[str, HierarchyNode]:
        return {
            "pak_tri_force_command": HierarchyNode(
                id="hq_pak_tri_force",
                label="Tri-Force Headquarters",
                title="Strategic Command",
                code="HQ",
                level=1,
                headcount=80,
                leader_role="Supreme Commander",
                children=[
                    HierarchyNode(
                        id="army_command",
                        label="Army Command",
                        title="Force Command",
                        code="ARMY",
                        level=2,
                        headcount=5200,
                        leader_role="Force Commander",
                        children=[
                            HierarchyNode(
                                id="army_ops_division",
                                label="Operations Division",
                                title="Division Command",
                                code="OPS-DIV",
                                level=3,
                                headcount=2200,
                                leader_role="Chief of Operations",
                                children=[],
                            ),
                            HierarchyNode(
                                id="army_logistics_division",
                                label="Logistics Division",
                                title="Division Command",
                                code="LOG-DIV",
                                level=3,
                                headcount=1800,
                                leader_role="Logistics Commander",
                                children=[],
                            ),
                        ],
                    ),
                    HierarchyNode(
                        id="navy_command",
                        label="Naval Command",
                        title="Force Command",
                        code="NAVY",
                        level=2,
                        headcount=3300,
                        leader_role="Force Commander",
                        children=[],
                    ),
                    HierarchyNode(
                        id="air_command",
                        label="Air Command",
                        title="Force Command",
                        code="AIR",
                        level=2,
                        headcount=2900,
                        leader_role="Force Commander",
                        children=[],
                    ),
                ],
            ),
            "national_education_network": HierarchyNode(
                id="edu_head_office",
                label="Education Head Office",
                title="Governing Body",
                code="GOV",
                level=1,
                headcount=44,
                leader_role="Chancellor",
                children=[
                    HierarchyNode(
                        id="campus_north",
                        label="North Campus",
                        title="Campus Administration",
                        code="NC",
                        level=2,
                        headcount=2100,
                        leader_role="Principal",
                        children=[
                            HierarchyNode(
                                id="campus_north_academics",
                                label="Academic Block",
                                title="Faculty Cluster",
                                code="NC-ACA",
                                level=3,
                                headcount=980,
                                leader_role="Dean Academics",
                                children=[],
                            ),
                            HierarchyNode(
                                id="campus_north_student_affairs",
                                label="Student Affairs Block",
                                title="Support Cluster",
                                code="NC-SA",
                                level=3,
                                headcount=260,
                                leader_role="Director Student Affairs",
                                children=[],
                            ),
                        ],
                    ),
                    HierarchyNode(
                        id="campus_central",
                        label="Central Campus",
                        title="Campus Administration",
                        code="CC",
                        level=2,
                        headcount=1880,
                        leader_role="Principal",
                        children=[],
                    ),
                    HierarchyNode(
                        id="digital_learning",
                        label="Digital Learning Wing",
                        title="Shared Services",
                        code="DLW",
                        level=2,
                        headcount=220,
                        leader_role="Director Admissions",
                        children=[],
                    ),
                ],
            ),
            "atlas_industrial_group": HierarchyNode(
                id="atlas_board",
                label="Atlas Board Office",
                title="Executive Office",
                code="BRD",
                level=1,
                headcount=22,
                leader_role="Chief Executive Officer",
                children=[
                    HierarchyNode(
                        id="atlas_plant_1",
                        label="Plant 1",
                        title="Manufacturing Plant",
                        code="P1",
                        level=2,
                        headcount=2460,
                        leader_role="Plant Manager",
                        children=[
                            HierarchyNode(
                                id="atlas_plant_1_shopfloor",
                                label="Shopfloor Cluster",
                                title="Production Block",
                                code="P1-SF",
                                level=3,
                                headcount=1620,
                                leader_role="Plant Director",
                                children=[],
                            ),
                            HierarchyNode(
                                id="atlas_plant_1_warehouse",
                                label="Warehouse Cluster",
                                title="Warehouse Block",
                                code="P1-WH",
                                level=3,
                                headcount=340,
                                leader_role="Warehouse Lead",
                                children=[],
                            ),
                        ],
                    ),
                    HierarchyNode(
                        id="atlas_supply_hub",
                        label="Supply Hub",
                        title="Shared Services",
                        code="SUP",
                        level=2,
                        headcount=720,
                        leader_role="Procurement Director",
                        children=[],
                    ),
                    HierarchyNode(
                        id="atlas_quality_lab",
                        label="Quality Lab",
                        title="Quality Services",
                        code="QAL",
                        level=2,
                        headcount=190,
                        leader_role="QA Head",
                        children=[],
                    ),
                ],
            ),
        }

    def _build_roles(self) -> dict[str, list[RoleSummary]]:
        return {
            "pak_tri_force_command": [
                RoleSummary(
                    id="mil_role_1",
                    title="Supreme Commander",
                    code="SCOM",
                    hierarchy_level=1,
                    permissions=["tenant.manage", "broadcast.all", "strategic.override"],
                ),
                RoleSummary(
                    id="mil_role_2",
                    title="Force Commander",
                    code="FCOM",
                    hierarchy_level=2,
                    reports_to="Supreme Commander",
                    permissions=["operations.approve", "personnel.assign", "intelligence.review"],
                ),
                RoleSummary(
                    id="mil_role_3",
                    title="Chief of Operations",
                    code="COPS",
                    hierarchy_level=3,
                    reports_to="Force Commander",
                    permissions=["mission.plan", "deployment.track", "crisis.monitor"],
                ),
                RoleSummary(
                    id="mil_role_4",
                    title="Logistics Commander",
                    code="LOGC",
                    hierarchy_level=3,
                    reports_to="Force Commander",
                    permissions=["inventory.issue", "supply.transfer", "maintenance.track"],
                ),
            ],
            "national_education_network": [
                RoleSummary(
                    id="edu_role_1",
                    title="Chancellor",
                    code="CHAN",
                    hierarchy_level=1,
                    permissions=["tenant.manage", "policy.approve", "broadcast.all"],
                ),
                RoleSummary(
                    id="edu_role_2",
                    title="Principal",
                    code="PRIN",
                    hierarchy_level=2,
                    reports_to="Chancellor",
                    permissions=["academics.approve", "leave.approve", "dashboard.view"],
                ),
                RoleSummary(
                    id="edu_role_3",
                    title="Head of Department",
                    code="HOD",
                    hierarchy_level=3,
                    reports_to="Principal",
                    permissions=["timetable.manage", "assessment.review", "attendance.audit"],
                ),
                RoleSummary(
                    id="edu_role_4",
                    title="Teacher",
                    code="TCHR",
                    hierarchy_level=4,
                    reports_to="Head of Department",
                    permissions=["attendance.mark", "grades.enter", "parent.message"],
                ),
            ],
            "atlas_industrial_group": [
                RoleSummary(
                    id="ind_role_1",
                    title="Chief Executive Officer",
                    code="CEO",
                    hierarchy_level=1,
                    permissions=["tenant.manage", "budget.override", "strategy.approve"],
                ),
                RoleSummary(
                    id="ind_role_2",
                    title="Chief Operating Officer",
                    code="COO",
                    hierarchy_level=2,
                    reports_to="Chief Executive Officer",
                    permissions=["production.approve", "dispatch.release", "dashboard.view"],
                ),
                RoleSummary(
                    id="ind_role_3",
                    title="Plant Manager",
                    code="PLANT",
                    hierarchy_level=3,
                    reports_to="Chief Operating Officer",
                    permissions=["shift.manage", "maintenance.plan", "quality.audit"],
                ),
                RoleSummary(
                    id="ind_role_4",
                    title="Shift Supervisor",
                    code="SHIFT",
                    hierarchy_level=4,
                    reports_to="Plant Manager",
                    permissions=["crew.assign", "downtime.report", "safety.escalate"],
                ),
            ],
        }

    def _build_dashboards(self) -> dict[str, DashboardSummary]:
        return {
            "pak_tri_force_command": DashboardSummary(
                organization_id="pak_tri_force_command",
                command_snapshot=[
                    _metric("active_personnel", "Active Personnel", "14,820", trend="+2.4%"),
                    _metric("live_operations", "Live Operations", "12", status="attention"),
                    _metric("mission_readiness", "Mission Readiness", "91%", trend="+4 pts", status="good"),
                    _metric("supply_alerts", "Supply Alerts", "7", status="watch"),
                ],
                alerts=[
                    "Signals division has 3 elevated incidents awaiting review.",
                    "Two armory stock audit workflows are outside SLA.",
                ],
                panels=[
                    DashboardPanel(
                        id="ops_panel",
                        title="Operations",
                        description="Strategic activity across deployments, incidents, and approvals.",
                        metrics=[
                            _metric("missions_planned", "Missions Planned", "26"),
                            _metric("incidents_open", "Incidents Open", "5", status="attention"),
                            _metric("approval_backlog", "Approval Backlog", "14", status="watch"),
                        ],
                    ),
                    DashboardPanel(
                        id="personnel_panel",
                        title="Personnel & Medical",
                        description="Personnel readiness, training, and medical support indicators.",
                        metrics=[
                            _metric("training_compliance", "Training Compliance", "88%"),
                            _metric("medical_cases", "Medical Cases", "42"),
                            _metric("leave_requests", "Leave Requests", "19"),
                        ],
                    ),
                ],
            ),
            "national_education_network": DashboardSummary(
                organization_id="national_education_network",
                command_snapshot=[
                    _metric("enrolled_students", "Enrolled Students", "28,400", trend="+6.1%"),
                    _metric("faculty_active", "Active Faculty", "1,420"),
                    _metric("attendance_today", "Attendance Today", "94%", status="good"),
                    _metric("fees_due", "Fees Due This Week", "412", status="watch"),
                ],
                alerts=[
                    "Examination department has result compilation queues above the threshold.",
                    "Parent portal notifications are pending for 58 absence events.",
                ],
                panels=[
                    DashboardPanel(
                        id="academic_panel",
                        title="Academic Operations",
                        description="Course delivery, attendance, examinations, and risk indicators.",
                        metrics=[
                            _metric("classes_today", "Classes Today", "362"),
                            _metric("at_risk_students", "At-Risk Students", "173", status="watch"),
                            _metric("exam_workflows", "Exam Workflows", "48"),
                        ],
                    ),
                    DashboardPanel(
                        id="engagement_panel",
                        title="Parent & Student Engagement",
                        description="Admissions, support tickets, and guardian communication health.",
                        metrics=[
                            _metric("new_applications", "New Applications", "126"),
                            _metric("guardian_messages", "Guardian Messages", "231"),
                            _metric("support_sla", "Support SLA", "97%", status="good"),
                        ],
                    ),
                ],
            ),
            "atlas_industrial_group": DashboardSummary(
                organization_id="atlas_industrial_group",
                command_snapshot=[
                    _metric("production_orders", "Production Orders", "184", trend="+3.8%"),
                    _metric("oee", "Overall Equipment Effectiveness", "82%", status="good"),
                    _metric("downtime_hours", "Downtime Hours", "13.4", status="watch"),
                    _metric("safety_events", "Safety Events", "2", status="attention"),
                ],
                alerts=[
                    "Preventive maintenance completion dropped below the weekly target.",
                    "One HSE incident requires executive sign-off before shift close.",
                ],
                panels=[
                    DashboardPanel(
                        id="manufacturing_panel",
                        title="Manufacturing",
                        description="Production targets, WIP movement, and quality checkpoints.",
                        metrics=[
                            _metric("target_vs_actual", "Target vs Actual", "96%"),
                            _metric("wip_batches", "WIP Batches", "38"),
                            _metric("defect_rate", "Defect Rate", "1.7%", status="good"),
                        ],
                    ),
                    DashboardPanel(
                        id="supply_panel",
                        title="Supply Chain & Maintenance",
                        description="Inventory, procurement velocity, and machine health.",
                        metrics=[
                            _metric("critical_spares", "Critical Spares", "11", status="watch"),
                            _metric("open_purchase_orders", "Open Purchase Orders", "29"),
                            _metric("maintenance_work_orders", "Work Orders", "21"),
                        ],
                    ),
                ],
            ),
        }


ecms_service = ECMSService()
