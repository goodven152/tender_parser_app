# ─── в самом верху файла ───
import signal
# …

import json, uuid, subprocess, threading, datetime, os, sqlite3, queue, pathlib

import shutil, json
LOG_DIR = pathlib.Path("/app/logs")          # общий каталог для всех артефактов
LOG_DIR.mkdir(exist_ok=True)



_current = {
    "id": None,
    "progress": 0,
    "log": queue.Queue(),
    "proc": None,             # ←  держим сам subprocess.Popen
}

# … _reader без изменений …

def start_run():
    if _current["id"]:
        return _current["id"]        # уже работает
    run_id = str(uuid.uuid4())
    _current.update({"id": run_id,
                     "started": datetime.datetime.utcnow().isoformat(),
                     "progress": 0})
    cmd = ["python", "-m", "ge_parser_tenders.cli", "--config", str(CONF_PATH)]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=False)
    _current["proc"] = proc          # сохраняем
    threading.Thread(target=_reader, args=(proc, run_id), daemon=True).start()
    return run_id

def stop_run() -> bool:
    """True, если что-то было остановлено"""
    proc = _current.get("proc")
    if proc and proc.poll() is None:        # ещё жив
        proc.send_signal(signal.SIGINT)     # мягко ^C
        try:
            proc.wait(10)
        except subprocess.TimeoutExpired:
            proc.kill()
        return True
    return False

# ――― функция-обёртка ―――
def _reader(proc, run_id):
    log_lines = []
    for raw in proc.stdout:
        line = raw.decode("utf-8", errors="ignore")
        _current["log"].put(line)            # → WS
        log_lines.append(line)
        # ... вычисление progress ...
    proc.wait()

    # ── сохраняем stdout в runs.db
    save_run(run_id, _current["started"],
             datetime.datetime.utcnow().isoformat(),
             proc.returncode, "".join(log_lines))

    # ── если парсер создал found_tenders.json — переименуем под run_id
    src = pathlib.Path("/app/found_tenders.json")
    if src.exists():
        dst = LOG_DIR / f"{run_id}.json"
        shutil.move(src, dst)                # теперь логика фронта знает путь

    _current.update({"id": None, "progress": 0})

CONF_PATH = pathlib.Path("/app/config.json")
DB_PATH   = pathlib.Path("/app/runs.db")

# --- storage ---------------------------------------------------------------
def _init_db():
    with sqlite3.connect(DB_PATH) as c:
        c.execute("""CREATE TABLE IF NOT EXISTS runs (
            id TEXT PRIMARY KEY,
            started TEXT,
            finished TEXT,
            returncode INT,
            log TEXT
        )""")
_init_db()

def save_run(run_id, started, finished=None, code=None, log=""):
    with sqlite3.connect(DB_PATH) as c:
        c.execute("""INSERT OR REPLACE INTO runs(id,started,finished,returncode,log)
                     VALUES(?,?,?,?,?)""", (run_id,started,finished,code,log))

def last_runs(limit=10):
    with sqlite3.connect(DB_PATH) as c:
        cur=c.execute("SELECT * FROM runs ORDER BY started DESC LIMIT ?",(limit,))
        cols=[d[0] for d in cur.description]
        return [dict(zip(cols,r)) for r in cur.fetchall()]

# --- runner ----------------------------------------------------------------
_current = {"id": None, "progress": 0, "log": queue.Queue()}

def start_run():
    if _current["id"]:                      # уже идёт
        return _current["id"]
    run_id=str(uuid.uuid4())
    _current.update({"id": run_id,
                     "started": datetime.datetime.utcnow().isoformat(),
                     "progress": 0})
    cmd = ["python", "-m", "ge_parser_tenders.cli", "--config", str(CONF_PATH)]
    proc=subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    threading.Thread(target=_reader, args=(proc, run_id), daemon=True).start()
    return run_id
