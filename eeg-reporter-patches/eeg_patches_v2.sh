#!/bin/bash
# EEG analyzer patches v2: frequency resolution + symmetry fix
set -e
cd ~/eeg-reporter
cp eeg_analyzer.py eeg_analyzer.py.bak-$(date +%Y%m%d-%H%M%S)

python3 <<'PYFIX'
from pathlib import Path
p = Path.home() / "eeg-reporter/eeg_analyzer.py"
src = p.read_text()

# Patch A: frequency resolution + parabolic interpolation
old_a = '''        freqs, psd = welch(data, fs=sfreq, nperseg=int(4*sfreq))
        amask = (freqs>=8)&(freqs<=13)
        apsd = psd[:,amask]; afreqs = freqs[amask]
        if apsd.size:
            idx = np.argmax(apsd.mean(axis=0))
            result["pdr_hz"] = round(float(afreqs[idx]),1)'''

new_a = '''        # 10-second windows -> 0.1 Hz bin width (was 4s = 0.25 Hz, caused 8.2 snap)
        nperseg = int(min(10.0, r.n_times/sfreq) * sfreq)
        freqs, psd = welch(data, fs=sfreq, nperseg=nperseg)
        amask = (freqs>=8)&(freqs<=13)
        apsd = psd[:,amask]; afreqs = freqs[amask]
        if apsd.size:
            mean_psd = apsd.mean(axis=0)
            idx = int(np.argmax(mean_psd))
            # Parabolic interpolation for sub-bin precision
            if 0 < idx < len(mean_psd) - 1:
                y0, y1, y2 = mean_psd[idx-1], mean_psd[idx], mean_psd[idx+1]
                denom = (y0 - 2*y1 + y2)
                delta = 0.5 * (y0 - y2) / denom if abs(denom) > 1e-20 else 0.0
                delta = max(-0.5, min(0.5, delta))
                bin_hz = float(afreqs[1] - afreqs[0])
                pdr_hz_precise = float(afreqs[idx]) + delta * bin_hz
            else:
                pdr_hz_precise = float(afreqs[idx])
            result["pdr_hz"] = round(pdr_hz_precise, 1)'''

if old_a not in src:
    print("ERROR: Patch A target not found")
    raise SystemExit(1)
src = src.replace(old_a, new_a)

# Patch B: fix L/R channel ID + tighten threshold
old_b = '''            left  = [i for i,c in enumerate(occ) if "1" in c]
            right = [i for i,c in enumerate(occ) if "2" in c]
            if left and right:
                lp = float(apsd[left].mean()); rp = float(apsd[right].mean())
                if max(lp,rp)/(min(lp,rp)+1e-12) > 1.5:
                    result["symmetry"] = "mildly asymmetric"
                    result["assessment"] = "mildly abnormal"'''

new_b = '''            # Match O1/O2 as substrings, not just "1"/"2" which catches A1/A2
            left  = [i for i,c in enumerate(occ) if "O1" in c.upper()]
            right = [i for i,c in enumerate(occ) if "O2" in c.upper()]
            if left and right:
                lp = float(apsd[left].mean()); rp = float(apsd[right].mean())
                ratio = max(lp,rp)/(min(lp,rp)+1e-12)
                if ratio > 2.0:
                    result["symmetry"] = "asymmetric"
                    result["assessment"] = "mildly abnormal -- interhemispheric asymmetry"
                elif ratio > 1.7:
                    result["symmetry"] = "mildly asymmetric"'''

if old_b not in src:
    print("ERROR: Patch B target not found")
    raise SystemExit(1)
src = src.replace(old_b, new_b)

p.write_text(src)
print("Both patches applied")
PYFIX

python3 -c "import ast; ast.parse(open('eeg_analyzer.py').read()); print('SYNTAX OK')"

# Restart watcher
tmux kill-session -t eeg-reporter 2>/dev/null || true
tmux new-session -d -s eeg-reporter 'cd ~/eeg-reporter && python3 main.py 2>&1 | tee -a logs/app.log'
sleep 8
tail -10 logs/app.log

# Re-test 3 stems
echo ""
echo "=== Re-running 3 stems ==="
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
