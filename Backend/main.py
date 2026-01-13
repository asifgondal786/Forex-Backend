from fastapi import FastAPI

app = FastAPI()


@app.get("/ping")
def ping():
    return {"message": "Pong from the Python AI Backend!"}