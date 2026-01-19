from pathlib import Path

from .utils import run_cmd, log_info, log_warn


KLIPPER_SERVICE_TEMPLATE = """[Unit]
Description=Klipper instance {id}
After=network.target

[Service]
Type=simple
User=syko
ExecStart=/usr/bin/python3 {klipper_dir}/klippy/klippy.py {config_dir}/printer.cfg -l {logs_dir}/klippy.log
Restart=always
WorkingDirectory={klipper_dir}

[Install]
WantedBy=multi-user.target
"""

MOONRAKER_SERVICE_TEMPLATE = """[Unit]
Description=Moonraker instance {id}
After=network.target

[Service]
Type=simple
User=syko
ExecStart=/usr/bin/python3 -m moonraker -c {config_path}
Restart=always
WorkingDirectory={config_dir}

[Install]
WantedBy=multi-user.target
"""


def write_klipper_service(instance) -> Path:
    service_path = Path("/etc/systemd/system/{0}.service".format(instance.service_name))
    logs_dir = Path(instance.config_dir).parent / "logs"
    content = KLIPPER_SERVICE_TEMPLATE.format(
        id=instance.id,
        klipper_dir=instance.klipper_dir,
        config_dir=instance.config_dir,
        logs_dir=str(logs_dir),
    )
    service_path.write_text(content)
    log_info("Wrote Klipper service: {0}".format(service_path))
    return service_path


def write_moonraker_service(instance) -> Path:
    svc_name = "moonraker{0}".format(instance.id)
    service_path = Path("/etc/systemd/system/{0}.service".format(svc_name))

    config_dir = Path(instance.config_dir)
    moon_cfg = config_dir / "moonraker.conf"

    if not moon_cfg.exists():
        moon_cfg.write_text(
            "[server]\n"
            "host: 0.0.0.0\n"
            "port: {port}\n\n"
            "[authorization]\n"
            "trusted_clients: 127.0.0.1\n".format(port=instance.moonraker_port)
        )
        log_info("Created moonraker.conf at {0}".format(moon_cfg))

    content = MOONRAKER_SERVICE_TEMPLATE.format(
        id=instance.id,
        config_path=str(moon_cfg),
        config_dir=str(config_dir),
    )
    service_path.write_text(content)
    log_info("Wrote Moonraker service: {0}".format(service_path))
    return service_path


def reload_and_enable(service_name: str):
    run_cmd(["systemctl", "daemon-reload"], sudo=True)
    run_cmd(["systemctl", "enable", service_name], sudo=True)
    run_cmd(["systemctl", "start", service_name], sudo=True)
    log_info("Enabled + started service: {0}".format(service_name))


def restart_service(service_name: str):
    run_cmd(["systemctl", "restart", service_name], sudo=True)
    log_info("Restarted service: {0}".format(service_name))


def stop_and_disable(service_name: str):
    run_cmd(["systemctl", "stop", service_name], sudo=True, check=False)
    run_cmd(["systemctl", "disable", service_name], sudo=True, check=False)
    Path("/etc/systemd/system/{0}.service".format(service_name)).unlink(missing_ok=True)
    run_cmd(["systemctl", "daemon-reload"], sudo=True)
    log_warn("Stopped + disabled service: {0}".format(service_name))


def service_status(service_name: str) -> str:
    if not service_name:
        return "unknown"
    result = run_cmd(["systemctl", "is-active", service_name], sudo=True, check=False)
    if result.returncode == 0:
        return "active"
    if result.returncode == 3:
        return "inactive"
    return "unknown"
