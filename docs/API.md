# FluxPath API Reference

## Health
GET /health

## Printer
GET /printer/info  
GET /printer/status  

## MMU (Planned)
GET /mmu/status  
POST /mmu/switch/{slot}  
POST /mmu/load  
POST /mmu/unload  
POST /mmu/reset  

## Slicer Integration (Planned)
GET /fluxpath/capabilities  
POST /print/upload  
POST /print/start  
POST /print/pause  
POST /print/cancel  

## WebSocket
GET /fluxpath/ws  
