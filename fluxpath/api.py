# /home/syko/FluxPath/fluxpath/api.py

from fastapi import FastAPI, HTTPException
from .core.instances import instance_manager
from .core.diagnostics import basic_diagnostics
from . import __version__

app = FastAPI(title="FluxPath Backend", version=__version__)

@app.get("/fluxpath/version")
def get_version():
    return {
        "result": "ok",
        "backend": "FluxPath",
        "version": __version__,
    }

@app.get("/fluxpath/instances")
def list_instances():
    return {"result": "ok", "instances": instance_manager.list_instances()}

@app.post("/fluxpath/instances")
def create_instance(name: str = "default"):
    inst = instance_manager.create_instance(name)
    return {"result": "ok", "instance": inst}

@app.get("/fluxpath/instances/{inst_id}")
def get_instance(inst_id: str):
    inst = instance_manager.get_instance(inst_id)
    if not inst:
        raise HTTPException(status_code=404, detail="Instance not found")
    return {"result": "ok", "instance": inst}

@app.post("/fluxpath/instances/{inst_id}/status")
def set_instance_status(inst_id: str, status: str):
    inst = instance_manager.set_status(inst_id, status)
    if not inst:
        raise HTTPException(status_code=404, detail="Instance not found")
    return {"result": "ok", "instance": inst}

@app.get("/fluxpath/diagnostics")
def diagnostics():
    return {"result": "ok", "diagnostics": basic_diagnostics()}

from pydantic import BaseModel
from typing import List
from .core.mmu import mmu_manager

class FilamentModel(BaseModel):
    tool: int
    color_hex: str
    material: str
    name: str | None = None

class ToolchangeRequest(BaseModel):
    sequence: List[int]

@app.get("/fluxpath/capabilities")
def get_capabilities():
    return {"result": "ok", "capabilities": mmu_manager.get_capabilities()}

@app.get("/fluxpath/filaments")
def get_filaments():
    return {"result": "ok", "filaments": mmu_manager.get_filaments()}

@app.post("/fluxpath/filaments")
def set_filaments(filaments: List[FilamentModel]):
    stored = mmu_manager.set_filaments([f.model_dump() for f in filaments])
    return {"result": "ok", "filaments": stored}

@app.post("/fluxpath/slicer/plan")
def slicer_plan(req: ToolchangeRequest):
    plan = mmu_manager.plan_toolchanges(req.sequence)
    return {"result": "ok", "plan": plan}
