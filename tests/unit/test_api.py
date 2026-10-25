import pytest
from fastapi.testclient import TestClient

from app.main import app, tasks


@pytest.fixture
def client():
    tasks.clear()
    with TestClient(app) as test_client:
        yield test_client
    tasks.clear()


def test_health(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_version(client):
    response = client.get("/version")

    assert response.status_code == 200
    assert isinstance(response.json()["version"], str)
    assert response.json()["version"]


def test_task_lifecycle(client):
    response = client.post("/tasks", json={"title": "Learn Docker"})

    assert response.status_code == 201
    task = response.json()
    task_id = task["id"]
    assert task["title"] == "Learn Docker"
    assert task["completed"] is False

    response = client.get(f"/tasks/{task_id}")
    assert response.status_code == 200
    assert response.json() == task

    response = client.get("/tasks")
    assert response.status_code == 200
    assert response.json() == [task]

    response = client.delete(f"/tasks/{task_id}")
    assert response.status_code == 204
    assert response.content == b""

    assert client.get(f"/tasks/{task_id}").status_code == 404
    assert client.delete(f"/tasks/{task_id}").status_code == 404
    assert client.get("/tasks").json() == []


@pytest.mark.parametrize("payload", [
    {},
    {"title": ""},
    {"title": "x" * 201},
])
def test_invalid_title(client, payload):
    response = client.post("/tasks", json=payload)

    assert response.status_code == 422
    assert client.get("/tasks").json() == []


def test_missing_task(client):
    response = client.get("/tasks/00000000-0000-0000-0000-000000000001")

    assert response.status_code == 404


def test_invalid_task_id(client):
    response = client.get("/tasks/not-a-uuid")

    assert response.status_code == 422