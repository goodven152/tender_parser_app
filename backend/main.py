from fastapi import FastAPI, WebSocket, UploadFile, File
from fastapi.responses import JSONResponse
from apscheduler.schedulers.background import BackgroundScheduler
import runner, json, datetime, asyncio, pathlib, os

app=FastAPI()
scheduler=BackgroundScheduler(); scheduler.start()

# -------- ACTIONS ----------------------------------------------------------
@app.post("/run")
def run():
    return {"run_id": runner.start_run()}

@app.get("/runs")
def recent():
    return runner.last_runs()

@app.websocket("/ws")
async def ws(websocket: WebSocket):
    await websocket.accept()
    while True:
        if runner._current["id"]:
            lines=[]
            while not runner._current["log"].empty():
                lines.append(runner._current["log"].get())
            await websocket.send_json({"id": runner._current["id"],
                                       "progress": runner._current["progress"],
                                       "lines": lines})
        await asyncio.sleep(1)

# -------- CONFIG & KEYWORDS -----------------------------------------------
CONF_PATH = pathlib.Path("/app/config.json")

@app.get("/config")
def get_config():
    return json.loads(CONF_PATH.read_text())

@app.put("/config")
def update_config(cfg: dict):
    CONF_PATH.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))
    return {"status":"saved"}

@app.get("/keywords")
def kw():
    return {"KEYWORDS_GEO": get_config()["KEYWORDS_GEO"]}

@app.put("/keywords")
def kw_update(kw: list[str]):
    cfg=get_config()
    cfg["KEYWORDS_GEO"]=kw
    update_config(cfg)
    return {"status":"saved"}

# -------- NEXT SCHEDULE (пример: ежедневно 02:00) -------------------------
CRON_EXPR="0 2 * * *"  # поменяйте или читайте из env

def _calc_next_run():
    return scheduler._create_trigger("cron", expr=CRON_EXPR).get_next_fire_time(None, datetime.datetime.utcnow())

@app.get("/next_run")
def next_run():
    return {"next": _calc_next_run()}
