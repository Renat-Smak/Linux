import json
import os
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

PROM = "http://127.0.0.1:9090"
GRAFANA = "http://127.0.0.1:3000"


def request(url, headers=None, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = Request(url, data=data, headers=headers or {})
    with urlopen(req, timeout=12) as response:
        return json.load(response)


def wait_for(call, label):
    for _ in range(30):
        try:
            result = call()
            if result:
                return result
        except OSError:
            pass
        time.sleep(3)
    raise RuntimeError(f"{label} unavailable")


targets = wait_for(
    lambda: [
        {"job": item["labels"]["job"], "health": item["health"], "url": item["scrapeUrl"]}
        for item in request(f"{PROM}/api/v1/targets")["data"]["activeTargets"]
        if item["labels"]["job"] == "node_exporter" and item["health"] == "up"
    ],
    "node_exporter target",
)
print("Prometheus targets:", json.dumps(targets))
queries = {
    "CPU usage %": '100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)',
    "Available RAM MiB": "node_memory_MemAvailable_bytes / 1024 / 1024",
}
for label, query in queries.items():
    address = f"{PROM}/api/v1/query?{urlencode({'query': query})}"
    result = wait_for(lambda: request(address)["data"]["result"], label)
    print(f"{label}: {float(result[0]['value'][1]):.2f}")

wait_for(lambda: request(f"{GRAFANA}/api/health").get("database") == "ok", "Grafana")
headers = {"Authorization": "Basic YWRtaW46YWRtaW4=", "Content-Type": "application/json"}
request(
    f"{GRAFANA}/api/datasources",
    headers,
    {"name": "Prometheus", "uid": "lab-prometheus", "type": "prometheus",
     "access": "proxy", "url": "http://prometheus:9090", "isDefault": True},
)
health = request(f"{GRAFANA}/api/datasources/uid/lab-prometheus/health", headers)
if health.get("status") != "OK":
    raise RuntimeError(health)
print("Grafana data source:", health.get("message", health["status"]))

catalog_url = "https://grafana.com/api/dashboards/1860/revisions/latest/download"
dashboard = request(catalog_url)
dashboard["id"] = None
dashboard["uid"] = "node-exporter-full"
imported = request(
    f"{GRAFANA}/api/dashboards/import",
    headers,
    {"dashboard": dashboard, "overwrite": True, "folderId": 0,
     "inputs": [{"name": "DS_PROMETHEUS", "type": "datasource",
                 "pluginId": "prometheus", "value": "lab-prometheus"}]},
)
verified = request(f"{GRAFANA}/api/dashboards/uid/node-exporter-full", headers)
print("Grafana dashboard 1860:", verified["dashboard"]["title"], "uid=", verified["dashboard"]["uid"])
url = verified["meta"]["url"]
Path(os.environ.get("RUNNER_TEMP", "/tmp"), "lab8-dashboard-url.txt").write_text(
    f"{GRAFANA}{url}?from=now-5m&to=now&kiosk", encoding="utf-8"
)
