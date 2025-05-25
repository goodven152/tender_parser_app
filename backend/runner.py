import json, uuid, subprocess, threading, datetime, os, sqlite3, queue, pathlib

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

def _reader(proc, run_id):
    log_lines=[]
    for line in proc.stdout:
        decoded=line.decode("utf-8", errors="ignore")
        _current["log"].put(decoded)
        log_lines.append(decoded)
        # try to guess % (пример: "Page X/Y")
        if "/" in decoded:
            try:
                x,y=[int(t) for t in decoded.split("/")[:2]]
                _current["progress"]=int(x*100/y)
            except: pass
    proc.wait()
    save_run(run_id,
             _current["started"],
             datetime.datetime.utcnow().isoformat(),
             proc.returncode,
             "".join(log_lines))
    _current.update({"id":None, "progress":0})

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
