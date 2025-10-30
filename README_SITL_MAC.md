# README_SITL.md

A fast, repeatable way to run **ArduPilot SITL (Software‑In‑The‑Loop)** locally with two UDP streams:

* `127.0.0.1:14550` → QGroundControl (QGC)
* `127.0.0.1:14551` → your Python app (or idle for now)

This guide avoids MAVProxy (`--no-mavproxy`) because it’s often the source of setup friction. You’ll still get a full ArduPilot firmware running (e.g., *ArduPlane*) with live telemetry over MAVLink/UDP.

---

## TL;DR

```bash
# 1) Prereqs (Linux/macOS; WSL2 on Windows OK)
#    Install Git, Python 3.10–3.12, pip, build tools, and QGC.

# 2) Clone & bootstrap
git clone https://github.com/ArduPilot/ardupilot.git
cd ardupilot
git submodule update --init --recursive

# 3) (Recommended) Create an isolated Python env for SITL tools
python3 -m venv .venv && source .venv/bin/activate
pip install --upgrade pip wheel setuptools
pip install pexpect pymavlink dronecan  # MAVProxy optional

# 4) Build SITL (example: ArduPlane)
./waf configure --board sitl
./waf plane

# 5) Run (QGC on 14550, Python hook on 14551)
./Tools/autotest/sim_vehicle.py -v ArduPlane -L KSFO \
  --no-mavproxy \
  --out=127.0.0.1:14550 \
  --out=127.0.0.1:14551
```

Or use the repo script:

```bash
chmod +x scripts/run_sitl.sh
scripts/run_sitl.sh
```

---

## Why SITL

SITL emulates the flight controller completely in software. You can:

* Exercise **state machines** and **mission logic** in real time.
* Verify **MAVLink/UDP** comms between your Python control code and FCU.
* Log **telemetry, video, and commands** without risking hardware.

---

## Supported Platforms

* **Linux** (Ubuntu 22.04/24.04 recommended)
* **macOS** (Apple Silicon & Intel tested via Homebrew toolchain)
* **Windows** via **WSL2** (Ubuntu distro inside WSL2). Run QGC on Windows; SITL in WSL2. (You can also run QGC inside WSLg, but Windows QGC is simpler.)

> If you’re on native Windows without WSL2, you’ll hit more friction. Use WSL2 unless you’re comfortable with MSYS2/MinGW.

---

## Prerequisites

### System packages (Linux/WSL2)

```bash
sudo apt update
sudo apt install -y git python3 python3-venv python3-pip \
  build-essential ccache pkg-config \
  libtool libffi-dev libxml2-dev libxslt1-dev zlib1g-dev
```

### System packages (macOS) 

1. Install Xcode Command Line Tools:

   ```bash
   xcode-select --install
   ```
2. Install Homebrew (if not installed) and tools:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   brew install git python ccache pkg-config
   ```

### QGroundControl (QGC)

Download QGC from the official site and run it locally. By default it listens on UDP **14550**, which matches our SITL output #1.
https://docs.qgroundcontrol.com/master/en/qgc-user-guide/getting_started/download_and_install.html
---

## Create a Clean Python Environment (recommended)

Use either **venv** or **conda**. Examples use `venv`.

```bash
cd ardupilot
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip wheel setuptools
# Minimal tool deps
pip install pexpect pymavlink dronecan
# Optional (can be finicky):
# pip install MAVProxy
```

> If you prefer **conda**:
>
> ```bash
> conda create -n sitl python=3.11 -y
> conda activate sitl
> pip install --upgrade pip wheel setuptools
> pip install pexpect pymavlink dronecan
> ```

---

## Get & Build ArduPilot SITL

```bash
# Inside a workspace folder
git clone https://github.com/ArduPilot/ardupilot.git
cd ardupilot
# Very important: pull in all submodules
git submodule update --init --recursive

# Configure & build for SITL
./waf configure --board sitl
# Choose a vehicle to build: plane, copter, rover, sub, etc.
./waf plane   # builds ArduPlane.sitl
```

### Verifying the binary

You can quick‑run via `sim_vehicle.py` (preferred). It automatically picks the right SITL binary for `-v`.

---

## Running SITL (no MAVProxy)

We intentionally skip MAVProxy to simplify the pipeline.

```bash
./Tools/autotest/sim_vehicle.py -v ArduPlane -L KSFO \
  --no-mavproxy \
  --out=127.0.0.1:14550 \
  --out=127.0.0.1:14551
```
You can open QGroundControl first then run this SITL to visualize it.

* `-v ArduPlane` selects the firmware.
* `-L KSFO` sets the start location (San Francisco Intl). Try `-L Canberra`, `-L CMAC`, or `(lat,lon,alt,hdg)` with `--custom-location`.
* `--out=<host:port>` adds UDP endpoints. First is QGC; second is reserved for your Python app.

### Alternate vehicles

```bash
-v ArduCopter
-v ArduRover
-v ArduSub
```

---

## Python Side (consuming 14551)

When you’re ready, point your Python MAVLink client to `udp:127.0.0.1:14551`.

Minimal snippet (pymavlink):

```python
from pymavlink import mavutil
mav = mavutil.mavlink_connection('udp:127.0.0.1:14551')
mav.wait_heartbeat()
print("Heartbeat from:", mav.target_system, mav.target_component)
```

create a connect_test.py in adrupilot folder and run it after running SIRL
you will get something like 
✅ Heartbeat received from system: 1 component: 0

---

## Log Locations

* **SITL logs** (e.g., `.BIN`) will appear under `ardupilot/build/sitl/bin/` or a `logs` subfolder created by `sim_vehicle.py` (e.g., in `~/Documents/ArduPilot` or within `ardupilot/` under `logs/`).
* **QGC logs** are recorded from the UI (Telemetry Logs) if you choose to start logging.

---

## Troubleshooting

### Common blockers & fixes

* **QGC isn’t connecting**

  * Make sure QGC is running *before* you launch SITL.
  * Verify no firewall is blocking UDP **14550**.
  * Confirm `--out=127.0.0.1:14550` is present and no typos.

* **`waf` errors or missing submodules**

  * Run: `git submodule update --init --recursive`
  * Ensure Python 3.10–3.12. If you see package build errors, try another minor version (3.11 is a sweet spot).

* **`ModuleNotFoundError` for `pexpect`/`pymavlink`/`dronecan`**

  * You likely didn’t activate your env. Run `source .venv/bin/activate` (or `conda activate sitl`). Reinstall deps.

* **Port already in use**

  * Change the outputs: `--out=127.0.0.1:14650` etc. Update QGC UDP port or add a second UDP link in QGC.

* **Running on Windows** (WSL2)

  * Run SITL inside WSL2 Ubuntu. Run **QGC on Windows**; it will still receive from `127.0.0.1:14550` if you forward.
  * Easiest: add an extra output for Windows host IP. Find it with `grep nameserver /etc/resolv.conf` (often `172.21.112.1`‑ish) and add:

    ```
    --out=<windows_host_ip>:14550
    ```
  * Or run QGC in WSLg and keep `127.0.0.1:14550`.

* **MAVProxy conflicts**

  * We don’t use it. If installed, don’t pass `--mavproxy` and avoid `MAVPROXY_OPTIONS` env vars.

* **Apple Silicon quirks**

  * Use Homebrew Python and ensure `pip install pymavlink` builds. If it fails, try `pip install --only-binary=:all: pymavlink` (may lag) or use Python 3.11.

---

## Repo Layout & Scripts

We include a small script to standardize launches.

```
repo/
├─ scripts/
│  └─ run_sitl.sh
└─ README_SITL.md  (this file)
```

### Make the script executable

```bash
chmod +x scripts/run_sitl.sh
scripts/run_sitl.sh
```

### Customizing

Environment variables override defaults:

* `VEHICLE` (default `ArduPlane`)
* `LOCATION` (default `KSFO`)
* `OUT_QGC` (default `127.0.0.1:14550`)
* `OUT_PY`  (default `127.0.0.1:14551`)
* `ARDUPILOT_DIR` (default: auto‑detect current/parent ardupilot)
* `ENV_FILE` — optional path to an env activation script

Example:

```bash
VEHICLE=ArduCopter LOCATION=Canberra scripts/run_sitl.sh
```

---

## Validation Checklist (what to report back)

* [ ] OS & version (e.g., Ubuntu 24.04, macOS 14.6, WSL2 Ubuntu 22.04)
* [ ] Python version & env type (venv/conda)
* [ ] Steps you took (copy/paste shell history if possible)
* [ ] Issues hit (errors, screenshots), **and fixes**
* [ ] Confirmation that QGC connects on `14550`
* [ ] (Optional) A tiny Python script received heartbeats on `14551`

> Please PR your notes into `README_SITL.md` under a new `### Notes: <YourName>` section so we build a one‑stop doc.

---

# scripts/run_sitl.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

# --- Config (env‑overrideable) ---
VEHICLE="${VEHICLE:-ArduPlane}"
LOCATION="${LOCATION:-KSFO}"
OUT_QGC="${OUT_QGC:-127.0.0.1:14550}"
OUT_PY="${OUT_PY:-127.0.0.1:14551}"
ENV_FILE="${ENV_FILE:-}"

# Try to locate ardupilot root automatically if not provided
ARDUPILOT_DIR="${ARDUPILOT_DIR:-}"
if [[ -z "${ARDUPILOT_DIR}" ]]; then
  if [[ -d "./ardupilot" ]]; then
    ARDUPILOT_DIR="$(cd ./ardupilot && pwd)"
  elif [[ -d "../ardupilot" ]]; then
    ARDUPILOT_DIR="$(cd ../ardupilot && pwd)"
  else
    echo "[ERROR] Could not find ardupilot directory. Set ARDUPILOT_DIR or clone ardupilot in repo/ or repo/.." >&2
    exit 1
  fi
fi

# --- Activate env if available ---
# Priority: explicit ENV_FILE, then local .venv, then conda 'sitl'
if [[ -n "${ENV_FILE}" && -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
elif [[ -f "${ARDUPILOT_DIR}/.venv/bin/activate" ]]; then
  # shellcheck disable=SC1091
  source "${ARDUPILOT_DIR}/.venv/bin/activate"
elif command -v conda >/dev/null 2>&1 && conda env list | grep -q "\bsitl\b"; then
  # shellcheck disable=SC1091
  eval "$(conda shell.bash hook)"
  conda activate sitl || true
else
  echo "[INFO] No Python env auto‑activated. Proceeding with system Python."
fi

# --- Sanity checks ---
if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] python3 not found. Install Python 3.10–3.12." >&2
  exit 1
fi

if [[ ! -x "${ARDUPILOT_DIR}/Tools/autotest/sim_vehicle.py" && -f "${ARDUPILOT_DIR}/Tools/autotest/sim_vehicle.py" ]]; then
  chmod +x "${ARDUPILOT_DIR}/Tools/autotest/sim_vehicle.py"
fi

if [[ ! -f "${ARDUPILOT_DIR}/Tools/autotest/sim_vehicle.py" ]]; then
  echo "[ERROR] sim_vehicle.py not found under ${ARDUPILOT_DIR}/Tools/autotest" >&2
  exit 1
fi

# --- Build check (optional but helpful) ---
if [[ ! -d "${ARDUPILOT_DIR}/build" ]]; then
  echo "[INFO] No build folder found. Configuring & building SITL (plane)."
  pushd "${ARDUPILOT_DIR}" >/dev/null
  ./waf configure --board sitl
  ./waf plane
  popd >/dev/null
fi

# --- Launch SITL ---
cd "${ARDUPILOT_DIR}"
exec ./Tools/autotest/sim_vehicle.py \
  -v "${VEHICLE}" \
  -L "${LOCATION}" \
  --no-mavproxy \
  --out="${OUT_QGC}" \
  --out="${OUT_PY}"
```


