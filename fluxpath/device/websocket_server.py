import asyncio
import json
import websockets

from fluxpath.core.mmu import mmu_manager

WS_PORT = 9876

async def handler(websocket):
    await websocket.send(json.dumps({
        "msg": "device_info",
        "name": "FluxPath MMU Controller",
        "fw": "1.0.0",
        "sn": "FLUXPATH-0001",
        "tools": mmu_manager.get_capabilities()["tools"]
    }))

    while True:
        await websocket.send(json.dumps({
            "msg": "mmu_status",
            "filaments": mmu_manager.get_filaments(),
            "caps": mmu_manager.get_capabilities()
        }))
        await asyncio.sleep(2)

async def start_ws():
    async with websockets.serve(handler, "0.0.0.0", WS_PORT):
        await asyncio.Future()
