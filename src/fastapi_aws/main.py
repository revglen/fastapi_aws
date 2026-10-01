from fastapi import FastAPI

app = FastAPI(title="Simple FastAPI Service to test AWS and GitHub")

@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI"}

@app.get("/health")
def health():
    return {"status": "okay"}

@app.get("/items/{item_id}")
def read_item(item_id: int, q: str | None = None):
    return {"item_id": item_id, "q": q}