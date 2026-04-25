from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.ecms_routes import router


app = FastAPI()
app.include_router(router)
client = TestClient(app)


def test_overview_lists_supported_sectors() -> None:
    response = client.get("/api/ecms/overview")

    assert response.status_code == 200
    payload = response.json()

    assert payload["current_focus"].startswith("Phase 1 foundation")
    assert len(payload["supported_sectors"]) == 3
    assert {item["code"] for item in payload["supported_sectors"]} == {
        "military",
        "education",
        "industry",
    }
    assert len(payload["organizations"]) == 3


def test_organizations_can_be_filtered_by_sector() -> None:
    response = client.get("/api/ecms/organizations", params={"sector": "education"})

    assert response.status_code == 200
    payload = response.json()

    assert len(payload) == 1
    assert payload[0]["sector"] == "education"
    assert payload[0]["id"] == "national_education_network"


def test_hierarchy_returns_expected_root_node() -> None:
    response = client.get("/api/ecms/organizations/pak_tri_force_command/hierarchy")

    assert response.status_code == 200
    payload = response.json()

    assert payload["label"] == "Tri-Force Headquarters"
    assert payload["leader_role"] == "Supreme Commander"
    assert len(payload["children"]) == 3


def test_dashboard_returns_panels_for_known_organization() -> None:
    response = client.get("/api/ecms/organizations/atlas_industrial_group/dashboard")

    assert response.status_code == 200
    payload = response.json()

    assert payload["organization_id"] == "atlas_industrial_group"
    assert len(payload["command_snapshot"]) == 4
    assert len(payload["panels"]) == 2


def test_unknown_organization_returns_404() -> None:
    response = client.get("/api/ecms/organizations/not-real/dashboard")

    assert response.status_code == 404
    assert "Unknown ECMS organization" in response.json()["detail"]
