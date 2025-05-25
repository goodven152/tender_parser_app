from celery import Celery
import subprocess, uuid, datetime, logging, time, os, json

celery = Celery('parser', broker="redis://redis:6379/0")

@celery.task(bind=True)
def run_parser(self, cfg="config.json"):
    run_id = str(uuid.uuid4())
    log_path = f"/app/logs/{run_id}.log"
    logging.basicConfig(
        handlers=[logging.FileHandler(log_path), logging.StreamHandler()],
        level=logging.INFO
    )
    proc = subprocess.Popen(
        ["python", "-m", "ge_parser_tenders.cli", "--config", cfg],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
    )
    for line in proc.stdout:
        logging.info(line.rstrip())
        pct = _percent(line)
        if pct:
            self.update_state(state="PROGRESS", meta={"pct": pct})
    proc.wait()
    status = "SUCCESS" if proc.returncode == 0 else "FAILED"
    return {"status": status, "log": log_path}