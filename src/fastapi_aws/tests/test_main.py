from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello from FastAPI"}


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_read_item():
    response = client.get("/items/5?q=test")
    assert response.status_code == 200
    assert response.json() == {"item_id": 5, "q": "test"}


def test_read_item_no_query():
    response = client.get("/items/5")
    assert response.status_code == 200
    assert response.json() == {"item_id": 5, "q": None}
