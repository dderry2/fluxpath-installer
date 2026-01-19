#!/usr/bin/env python3
import argparse
from pathlib import Path

from fp_core.instances import (
    load_instances,
    save_instances,
    next_id,
    allocate_ports,
    Instance,
)
from fp_core.klipper import (
    create_instance_dirs,
    clone_klipper,
    write_base_printer_cfg,
)
from fp_core.systemd import (
    write_klipper_service,
    write_moonraker_service,
    reload_and_enable,
    restart_service,
    stop_and_disable,
    service_status,
)
from fp_core.installer_bridge import run_fluxpath_installer
from fp_core.config import (
    KLIPPER_PORT_BASE,
    MOONRAKER_PORT_BASE,
)
from fp_core.utils import log_info, log_warn, log_error, log_header, color_text


def _get_instance(instances, iid):
    return next((i for i in instances if i.id == iid), None)


def cmd_instance_create(args):
    instances = load_instances()
    new_id = next_id(instances)
    k_port, m_port = allocate_ports(instances, KLIPPER_PORT_BASE, MOONRAKER_PORT_BASE)

    root = create_instance_dirs(new_id)
    klipper_dir = clone_klipper(new_id)
    config_dir = root / "config"

    write_base_printer_cfg(config_dir)

    inst = Instance(
        id=new_id,
        name="instance_{0}".format(new_id),
        config_dir=str(config_dir),
        klipper_dir=str(klipper_dir),
        service_name="klipper{0}".format(new_id),
        klipper_port=k_port,
        moonraker_port=m_port,
        moonraker_service="moonraker{0}".format(new_id),
        active=False,
        sandbox=bool(args.sandbox),
    )

    if not args.sandbox:
        write_klipper_service(inst)
        reload_and_enable(inst.service_name)
        write_moonraker_service(inst)
        reload_and_enable(inst.moonraker_service)
        inst.active = True
        log_info("Created live instance {0}".format(inst.id))
    else:
        log_warn("Created sandbox instance {0} (no services)".format(inst.id))

    instances.append(inst)
    save_instances(instances)

    log_header("Instance created")
    print("  {0}:   {1}".format(color_text("config", "cyan"), inst.config_dir))
    print("  {0}:  {1}".format(color_text("klipper", "cyan"), inst.klipper_dir))
    print("  {0}:  {1} (sandbox={2})".format(color_text("service", "cyan"), inst.service_name, inst.sandbox))
    print("  {0}: klipper={1}, moonraker={2}".format(
        color_text("ports", "cyan"), inst.klipper_port, inst.moonraker_port
    ))


def cmd_instance_list(args):
    instances = load_instances()
    if not instances:
        log_warn("No instances registered.")
        return

    log_header("Registered instances")
    for i in instances:
        status = "active" if i.active else "inactive"
        status_color = "green" if i.active else "yellow"
        print(
            "  [{id}] {name} | cfg={cfg} | svc={svc} | k={k} m={m} | {status}".format(
                id=i.id,
                name=color_text(i.name, "magenta"),
                cfg=i.config_dir,
                svc=i.service_name,
                k=i.klipper_port,
                m=i.moonraker_port,
                status=color_text(status, status_color),
            )
        )


def cmd_install(args):
    instances = load_instances()
    target = _get_instance(instances, args.instance)
    if not target:
        log_error("No instance with id {0}".format(args.instance))
        return

    run_fluxpath_installer(Path(target.config_dir))
    log_info("Installed MMU into instance {0} ({1})".format(target.id, target.name))


def cmd_instance_restart(args):
    instances = load_instances()
    target = _get_instance(instances, args.instance)
    if not target:
        log_error("No instance with id {0}".format(args.instance))
        return

    if target.sandbox:
        log_warn("Instance {0} is sandboxed (no services to restart)".format(target.id))
        return

    if target.service_name:
        restart_service(target.service_name)
    if target.moonraker_service:
        restart_service(target.moonraker_service)

    log_info("Restarted services for instance {0}".format(target.id))


def cmd_instance_delete(args):
    from shutil import rmtree

    instances = load_instances()
    target = _get_instance(instances, args.instance)
    if not target:
        log_error("No instance with id {0}".format(args.instance))
        return

    if not args.force:
        log_warn("Refusing to delete instance {0} without --force".format(target.id))
        return

    if not target.sandbox:
        if target.service_name:
            stop_and_disable(target.service_name)
        if target.moonraker_service:
            stop_and_disable(target.moonraker_service)

    root = Path(target.config_dir).parent
    rmtree(root, ignore_errors=True)

    kdir = Path(target.klipper_dir)
    if kdir.exists():
        rmtree(kdir, ignore_errors=True)

    instances = [i for i in instances if i.id != target.id]
    save_instances(instances)

    log_info("Deleted instance {0}".format(target.id))


def cmd_instance_diag(args):
    instances = load_instances()
    target = _get_instance(instances, args.instance)
    if not target:
        log_error("No instance with id {0}".format(args.instance))
        return

    log_header("Diagnostics for instance {0}".format(target.id))

    cfg_dir = Path(target.config_dir)
    print("  config dir:   {0} ({1})".format(
        cfg_dir,
        color_text("ok", "green") if cfg_dir.exists() else color_text("missing", "red"),
    ))

    kdir = Path(target.klipper_dir)
    print("  klipper dir:  {0} ({1})".format(
        kdir,
        color_text("ok", "green") if kdir.exists() else color_text("missing", "red"),
    ))

    if not target.sandbox:
        ks = service_status(target.service_name) if target.service_name else "unknown"
        ms = service_status(target.moonraker_service) if target.moonraker_service else "unknown"

        def color_status(s):
            if s == "active":
                return color_text(s, "green")
            if s == "inactive":
                return color_text(s, "yellow")
            return color_text(s, "red")

        print("  klipper svc:  {0} ({1})".format(target.service_name, color_status(ks)))
        print("  moonraker:    {0} ({1})".format(target.moonraker_service, color_status(ms)))
    else:
        log_warn("Sandbox instance: no services to diagnose")

    moon_cfg = cfg_dir / "moonraker.conf"
    print("  moonraker.conf: {0} ({1})".format(
        moon_cfg,
        color_text("present", "green") if moon_cfg.exists() else color_text("missing", "red"),
    ))

    printer_cfg = cfg_dir / "printer.cfg"
    print("  printer.cfg:    {0} ({1})".format(
        printer_cfg,
        color_text("present", "green") if printer_cfg.exists() else color_text("missing", "red"),
    ))


def main():
    parser = argparse.ArgumentParser(
        prog="fluxpath",
        description="FluxPath Multi-Instance Manager",
    )
    sub = parser.add_subparsers(dest="cmd")

    p_create = sub.add_parser("instance-create", help="Create a new Klipper instance")
    p_create.add_argument(
        "--sandbox",
        action="store_true",
        help="Create only directories and configs (no systemd services)",
    )
    p_create.set_defaults(func=cmd_instance_create)

    p_list = sub.add_parser("instance-list", help="List all managed instances")
    p_list.set_defaults(func=cmd_instance_list)

    p_install = sub.add_parser("install", help="Run FluxPath installer on an instance")
    p_install.add_argument("--instance", type=int, required=True, help="Instance ID")
    p_install.set_defaults(func=cmd_install)

    p_restart = sub.add_parser("instance-restart", help="Restart services for an instance")
    p_restart.add_argument("--instance", type=int, required=True)
    p_restart.set_defaults(func=cmd_instance_restart)

    p_delete = sub.add_parser("instance-delete", help="Delete an instance and its resources")
    p_delete.add_argument("--instance", type=int, required=True)
    p_delete.add_argument("--force", action="store_true", help="Confirm deletion")
    p_delete.set_defaults(func=cmd_instance_delete)

    p_diag = sub.add_parser("instance-diag", help="Run diagnostics on an instance")
    p_diag.add_argument("--instance", type=int, required=True)
    p_diag.set_defaults(func=cmd_instance_diag)

    args = parser.parse_args()
    if not hasattr(args, "func"):
        parser.print_help()
        return
    args.func(args)


if __name__ == "__main__":
    main()
