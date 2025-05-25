from fastapi import FastAPI, WebSocket
from celery.result import AsyncResult
from tasks.parser import run_parser
import os, asyncio

app = FastAPI()

@app.post("/runs")
def create_run():
    task = run_parser.delay()
    return {"run_id": task.id}

@app.get("/runs/{run_id}")
def get_run(run_id: str):
    res = AsyncResult(run_id)
    return {"state": res.state, "meta": res.info}

@app.websocket("/ws/{run_id}")
async def log_stream(ws: WebSocket, run_id: str):
    await ws.accept()
    log_file = f"/app/logs/{run_id}.log"
    pos = 0
    while True:
        await asyncio.sleep(1)
        if os.path.exists(log_file):
            with open(log_file) as f:
                f.seek(pos)
                chunk = f.read()
                pos = f.tell()
                if chunk:
                    await ws.send_text(chunk)