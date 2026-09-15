"""Учебный генератор JSON-событий в stdout контейнера."""
import json
import random
import time
from datetime import datetime, timezone

while True:
    level = random.choice(["INFO", "WARNING", "ERROR"])
    print(json.dumps({
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "netology-dummy",
        "level": level,
        "message": {"INFO": "Request completed", "WARNING": "Slow request", "ERROR": "Demo request failed"}[level],
        "event_id": f"dummy-{time.time_ns()}"
    }), flush=True)
    time.sleep(2)
