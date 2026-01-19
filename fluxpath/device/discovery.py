import socket
import json
import threading
import time

BROADCAST_PORT = 2021
INTERVAL = 3

def broadcast_loop():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

    payload = {
        "msg": "discover",
        "dev": "printer",
        "ip": "192.168.0.122",
        "fw": "1.0.0",
        "sn": "FLUXPATH-0001",
        "name": "FluxPath MMU Controller"
    }

    data = json.dumps(payload).encode()

    while True:
        sock.sendto(data, ("255.255.255.255", BROADCAST_PORT))
        time.sleep(INTERVAL)

def start_broadcast():
    t = threading.Thread(target=broadcast_loop, daemon=True)
    t.start()
