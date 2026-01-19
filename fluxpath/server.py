# /home/syko/FluxPath/fluxpath/server.py

import uvicorn
from .api import app

def main():
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=9999,
        log_level="info",
    )

if __name__ == "__main__":
    main()
