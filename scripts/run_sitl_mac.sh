#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT/ardupilot"

# activate venv if present
[[ -f ".venv/bin/activate" ]] && source .venv/bin/activate

# make sure MAVProxy is available (needed when not using --no-mavproxy)
python - <<'PY'
import importlib, sys
try: importlib.import_module("MAVProxy")
except ImportError:
    print("MAVProxy not found. Install with: pip install MAVProxy", file=sys.stderr)
PY

# launch
./Tools/autotest/sim_vehicle.py -v ArduPlane -L KSFO \
  --out=udp:127.0.0.1:14550 \
  --out=udp:127.0.0.1:14551


##to run in the root directory after procudure in root readme 
# chmod +x scripts/run_sitl_mac.sh
# ./scripts/run_sitl_mac.sh