import sys
from kilosort import run_kilosort
from kilosort.io import load_probe
import os

# Check if the correct number of arguments is provided
if len(sys.argv) != 3:
    print("Usage: python kilosort4.py data_dir probe_path")
    for i, arg in enumerate(sys.argv):
        print(f"Argument {i}: {arg}")
    sys.exit(1)

# Retrieve the command line arguments
data_dir = sys.argv[1]
probe_path = sys.argv[2]
probe = load_probe(probe_path)
n_chan_bin = probe["n_chan"]
settings = {"data_dir": data_dir, "n_chan_bin": n_chan_bin}
subdirectory = os.path.join(data_dir, "kilosort4")
os.makedirs(subdirectory, exist_ok=True)
run_kilosort(settings, probe)
