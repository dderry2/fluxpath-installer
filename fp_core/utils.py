import subprocess


class Colors(object):
    RESET = "\033[0m"
    BOLD = "\033[1m"

    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    MAGENTA = "\033[35m"
    CYAN = "\033[36m"


_COLOR_MAP = {
    "red": Colors.RED,
    "green": Colors.GREEN,
    "yellow": Colors.YELLOW,
    "blue": Colors.BLUE,
    "magenta": Colors.MAGENTA,
    "cyan": Colors.CYAN,
}


def color_text(text, color):
    prefix = _COLOR_MAP.get(color, "")
    return "{0}{1}{2}".format(prefix, text, Colors.RESET)


def log_info(msg):
    print("{0} {1}".format(color_text("[INFO]", "green"), msg))


def log_warn(msg):
    print("{0} {1}".format(color_text("[WARN]", "yellow"), msg))


def log_error(msg):
    print("{0} {1}".format(color_text("[ERROR]", "red"), msg))


def log_header(msg):
    print(color_text("== {0} ==".format(msg), "cyan"))


def run_cmd(cmd, sudo=False, check=True):
    full = ["sudo"] + cmd if sudo else cmd
    log_info("run: {0}".format(" ".join(full)))
    return subprocess.run(full, check=check)
