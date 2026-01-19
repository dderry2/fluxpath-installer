from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse, HTMLResponse
import uvicorn
import asyncio
from typing import List

app = FastAPI(title="FluxPath Backend")

# ---------------------------------------------------------
# Virtual printer + MMU state (replace with real MMU later)
# ---------------------------------------------------------
printer_state = {
    "name": "FluxPath Virtual Printer",
    "model": "FluxPath-MMU",
    "firmware": "1.0.0",
    "status": "idle",
    "job": None,
    "mmu": {
        "enabled": True,
        "slots": 4,
        "active_slot": 1,
        "filaments": [
            {"slot": 1, "color": "red", "material": "PLA"},
            {"slot": 2, "color": "blue", "material": "PLA"},
            {"slot": 3, "color": "green", "material": "PLA"},
            {"slot": 4, "color": "yellow", "material": "PLA"},
        ],
    },
}

# ---------------------------------------------------------
# WebSocket connection manager
# ---------------------------------------------------------
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except:
                self.disconnect(connection)

manager = ConnectionManager()

# ---------------------------------------------------------
# Dashboard HTML
# ---------------------------------------------------------
DASHBOARD_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>FluxPath Dashboard</title>
    <style>
        body { font-family: sans-serif; background: #111; color: #eee; padding: 20px; }
        h1 { color: #4fd1c5; }
        .card { background: #1a202c; padding: 16px; border-radius: 8px; margin-bottom: 16px; }
        .label { color: #a0aec0; font-size: 0.9em; }
        .value { font-size: 1.1em; }
        pre { background: #2d3748; padding: 12px; border-radius: 6px; }
    </style>
</head>
<body>
    <h1>FluxPath Backend</h1>

    <div class="card">
        <div class="label">Health</div>
        <div class="value" id="health">Loading...</div>
    </div>

    <div class="card">
        <div class="label">Printer Status</div>
        <pre id="printer-status">{}</pre>
    </div>

    <div class="card">
        <div class="label">WebSocket</div>
        <div class="value" id="ws-status">Connecting...</div>
    </div>

    <script>
        async function fetchHealth() {
            try {
                const res = await fetch('/health');
                const data = await res.json();
                document.getElementById('health').innerText = data.status;
            } catch (e) {
                document.getElementById('health').innerText = 'error';
            }
        }

        async function fetchPrinterStatus() {
            try {
                const res = await fetch('/printer/status');
                const data = await res.json();
                document.getElementById('printer-status').innerText = JSON.stringify(data, null, 2);
            } catch (e) {
                document.getElementById('printer-status').innerText = 'error';
            }
        }

        function connectWS() {
            const ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/fluxpath/ws');
            ws.onopen = () => {
                document.getElementById('ws-status').innerText = 'connected';
            };
            ws.onclose = () => {
                document.getElementById('ws-status').innerText = 'disconnected (retrying...)';
                setTimeout(connectWS, 2000);
            };
            ws.onmessage = (event) => {};
        }

        fetchHealth();
        fetchPrinterStatus();
        connectWS();
        setInterval(fetchHealth, 5000);
        setInterval(fetchPrinterStatus, 5000);
    </script>
</body>
</html>
"""

@app.get("/")
async def dashboard():
    return HTMLResponse(DASHBOARD_HTML)

# ---------------------------------------------------------
# Health + Printer API
# ---------------------------------------------------------
@app.get("/health")
async def health():
    return JSONResponse({"status": "ok"})

@app.get("/printer/info")
async def printer_info():
    return JSONResponse({
        "name": printer_state["name"],
        "model": printer_state["model"],
        "firmware": printer_state["firmware"],
        "mmu": printer_state["mmu"]["enabled"],
    })

@app.get("/printer/status")
async def printer_status():
    return JSONResponse({
        "status": printer_state["status"],
        "job": printer_state["job"],
        "mmu": printer_state["mmu"],
    })

# ---------------------------------------------------------
# Capabilities endpoint (OrcaSlicer)
# ---------------------------------------------------------
@app.get("/fluxpath/capabilities")
async def capabilities():
    return JSONResponse({
        "name": "FluxPath",
        "version": "1.0",
        "mmu": True,
        "ws": "/fluxpath/ws"
    })

# ---------------------------------------------------------
# WebSocket endpoint
# ---------------------------------------------------------
@app.websocket("/fluxpath/ws")
async def fluxpath_ws(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        await websocket.send_json({"status": "connected", "source": "fluxpath"})
        while True:
            await manager.broadcast({
                "type": "status",
                "status": printer_state["status"],
                "mmu": printer_state["mmu"],
            })
            await asyncio.sleep(2)
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# ---------------------------------------------------------
# Uvicorn startup (THIS is what opens port 9876)
# ---------------------------------------------------------
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=9876)
