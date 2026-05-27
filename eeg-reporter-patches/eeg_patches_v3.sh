#!/bin/bash
# EEG analyzer patches v3: fix occipital channel pollution
# Root cause: "O2" substring matched SpO2/EtCO2/CO2Wave physiological monitors
set -e
cd ~/eeg-reporter
cp eeg_analyzer.py eeg_analyzer.py.bak-$(date +%Y%m%d-%H%M%S)

python3 <<'PYFIX'
from pathlib import Path
p = Path.home() / "eeg-reporter/eeg_analyzer.py"
src = p.read_text()

# Patch C: exact-name occipital match (no substring)
old_c = '''        occ = [ch for ch in raw.ch_names if any(x in ch.upper() for x in ["O1","O2","OZ"])]
        if not occ:
            occ = raw.ch_names[:min(4,len(raw.ch_names))]'''

new_c = '''        # Exact-name match against canonical occipital EEG electrodes only.
        # OLD bug: "O2" substring matched SpO2/EtCO2/CO2Wave physiological monitors,
        # producing absurd asymmetry ratios (~28000) and contaminating amplitude calc.
        OCC_CANONICAL = {"O1","O2","OZ","O1-A1","O2-A2","O1-REF","O2-REF","OZ-REF"}
        occ_names = []
        for ch in raw.ch_names:
            up = ch.upper().strip()
            if up in OCC_CANONICAL:
                occ_names.append(ch)
        occ = occ_names
        if not occ:
            # Last-resort fallback: pick first 4 channels whose names look like EEG
            # electrodes (no SpO2/EtCO2/CO2/DC/Pulse/PG/$ prefix)
            EXCLUDE_PREFIX = ("SPO","ETCO","CO2","DC","PULSE","PG","X","$","E")
            occ = [c for c in raw.ch_names if not c.upper().startswith(EXCLUDE_PREFIX)][:4]'''

if old_c not in src:
    print("ERROR: Patch C target not found")
    raise SystemExit(1)
src = src.replace(old_c, new_c)

# Patch D: also fix L/R within occ — now occ should be exactly [O1, O2] but be defensive
old_d = '''            # Match O1/O2 as substrings, not just "1"/"2" which catches A1/A2
            left  = [i for i,c in enumerate(occ) if "O1" in c.upper()]
            right = [i for i,c in enumerate(occ) if "O2" in c.upper()]'''

new_d = '''            # Exact-name match — occ should now be [O1, O2] but stay defensive
            left  = [i for i,c in enumerate(occ) if c.upper().strip() in {"O1","O1-A1","O1-REF"}]
            right = [i for i,c in enumerate(occ) if c.upper().strip() in {"O2","O2-A2","O2-REF"}]'''

if old_d not in src:
    print("ERROR: Patch D target not found")
    raise SystemExit(1)
src = src.replace(old_d, new_d)

p.write_text(src)
print("Patches C+D applied")
PYFIX

python3 -c "import ast; ast.parse(open('eeg_analyzer.py').read()); print('SYNTAX OK')"

# Restart watcher
tmux kill-session -t eeg-reporter 2>/dev/null || true
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 6
tail -5 logs/app.log

# Re-test with diagnostic this time so we can see what occ actually is
echo ""
echo "=== Diagnostic on FA00129I (post-patch) ==="
python3 <<'PYDIAG'
import mne, warnings, numpy as np
from scipy.signal import welch
warnings.filterwarnings('ignore')

eeg = "/mnt/nas918/ai-pipeline/eeg-incoming/FA00129I.EEG"
raw = mne.io.read_raw_nihon(eeg, preload=True, verbose=False)

OCC_CANONICAL = {"O1","O2","OZ","O1-A1","O2-A2","O1-REF","O2-REF","OZ-REF"}
occ = [ch for ch in raw.ch_names if ch.upper().strip() in OCC_CANONICAL]
print(f"occ now: {occ}  (expected exactly ['O1', 'O2'])")

if not occ:
    print("FAIL: no occipital channels found")
    raise SystemExit(1)

r = raw.copy().pick(occ)
r.filter(l_freq=1.0, h_freq=40.0, verbose=False)
sfreq = r.info["sfreq"]
start = max(0, r.n_times - int(60*sfreq))
data, _ = r[:, start:]
nperseg = int(min(10.0, r.n_times/sfreq) * sfreq)
freqs, psd = welch(data, fs=sfreq, nperseg=nperseg)
amask = (freqs>=8)&(freqs<=13)
apsd = psd[:,amask]; afreqs = freqs[amask]
mean_psd = apsd.mean(axis=0)
idx = int(np.argmax(mean_psd))
print(f"peak freq: {afreqs[idx]:.3f} Hz, bin width {(afreqs[1]-afreqs[0]):.3f}")
print(f"O1 power: {apsd[0].mean():.3e}, O2 power: {apsd[1].mean():.3e}")
print(f"ratio: {max(apsd[0].mean(), apsd[1].mean())/min(apsd[0].mean(), apsd[1].mean()):.3f}")
PYDIAG

# Now reprocess the 3 test stems
echo ""
echo "=== Reprocessing 3 stems ==="
python3 process_one.py --redo --src 918 FA00129I 2>&1 | tail -3
python3 process_one.py --redo --src 918 FA0011UE 2>&1 | tail -3
python3 process_one.py --redo --src 918 FA0012AH 2>&1 | tail -3

echo ""
echo "=== Results ==="
python3 <<'PYR'
import json, glob, os
for stem in ['FA00129I', 'FA0011UE', 'FA0012AH']:
    files = sorted(glob.glob(os.path.expanduser(f'~/eeg-reporter/reports/{stem}_*.json')))
    if files:
        d = json.load(open(files[-1]))
        bg = d.get('findings',{}).get('background',{})
        print(f"{stem}: PDR {bg.get('pdr_hz')} Hz, {bg.get('pdr_amplitude_uv')} uV, {bg.get('symmetry')}")
PYR
