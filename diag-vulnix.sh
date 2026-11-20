#!/usr/bin/env bash
# Throwaway diagnostic: why vulnix takes > 15 min per attempt in CI when it
# takes ~3 min locally under the same limits. Not for merging.
set -uo pipefail

hr() { printf '\n===== %s  %s\n' "$(date -u +%T)" "$*"; }

hr "environment (VARIANT=$VARIANT, MEM=$KUBERNETES_MEMORY_LIMIT, VULNIX_CACHE_DIR=$VULNIX_CACHE_DIR)"
echo "node: ${KUBERNETES_NODE_NAME:-?}  nproc: $(nproc)"
grep -m1 "model name" /proc/cpuinfo
grep -c ^processor /proc/cpuinfo | sed 's/^/host processors: /'
for f in cpu.max memory.max memory.high io.max; do
  [ -r /sys/fs/cgroup/$f ] && echo "cgroup $f: $(cat /sys/fs/cgroup/$f)"
done
cat /sys/fs/cgroup/cpu.stat 2>/dev/null | sed 's/^/cpu.stat /'
df -hT "$CI_PROJECT_DIR" /tmp /nix 2>/dev/null
grep -E " (/builds|/tmp|/nix|/) " /proc/mounts

hr "disk: 2000 x 4 KiB synchronous writes (ZODB-like)"
for d in "$CI_PROJECT_DIR/.diag-io" /tmp/.diag-io; do
  mkdir -p "$d"
  start=$(date +%s.%N)
  dd if=/dev/zero of="$d/f" bs=4k count=2000 oflag=dsync 2>&1 | tail -1
  echo "  $d: $(python3 -c "print(round($(date +%s.%N)-$start,2))") s"
  start=$(date +%s.%N)
  dd if=/dev/zero of="$d/big" bs=1M count=512 conv=fsync 2>&1 | tail -1
  rm -rf "$d"
done

hr "cpu: single-thread python benchmark"
python3 - <<'PY'
import time, json, hashlib
t = time.time()
data = [{"id": f"CVE-{i}", "v": [hashlib.sha1(str(i).encode()).hexdigest()] * 5} for i in range(200000)]
s = json.dumps(data); json.loads(s)
print(f"  json+sha1 200k records: {time.time()-t:.2f} s (about 1.0 s on a laptop)")
PY

# Sampler: every 30 s, throttling, load, and what the heaviest processes do.
sampler() {
  local cg=/sys/fs/cgroup
  while sleep 20; do
    python3 - "$cg" "$VULNIX_CACHE_DIR" <<'PY'
import os, sys, time, glob
cg, cache = sys.argv[1], sys.argv[2]
def kv(f):
    try: return dict(l.split()[:2] for l in open(f"{cg}/{f}"))
    except OSError: return {}
def first(f):
    try: return open(f"{cg}/{f}").read().split("\n")[0]
    except OSError: return "?"
mib = lambda b: int(b) // 1048576
m = kv("memory.stat"); cur = first("memory.current")
print(f"[sample {time.strftime('%H:%M:%S', time.gmtime())}] load {open('/proc/loadavg').read().split()[:3]} "
      f"mem {mib(cur) if cur.isdigit() else cur} MiB (anon {mib(m.get('anon',0))}, file {mib(m.get('file',0))}, "
      f"dirty {mib(m.get('file_dirty',0))}, writeback {mib(m.get('file_writeback',0))}) "
      f"events {kv('memory.events')}")
print(f"   memory.pressure {first('memory.pressure')} | io.pressure {first('io.pressure')} | cpu.pressure {first('cpu.pressure')}")
for pid in os.listdir("/proc"):
    if not pid.isdigit(): continue
    try:
        cmd = open(f"/proc/{pid}/cmdline").read()
        if "vulnix" not in cmd or "nix run" in cmd.replace("\0"," ") and "wrapped" not in cmd: continue
        st = open(f"/proc/{pid}/stat").read().split(") ")[1].split()
        io = dict(l.split(": ") for l in open(f"/proc/{pid}/io").read().splitlines())
        rss = [l for l in open(f"/proc/{pid}/status") if l.startswith("VmRSS")][0].split()[1]
        print(f"   pid {pid} state {st[0]} wchan {open(f'/proc/{pid}/wchan').read()} cpu {(int(st[11])+int(st[12]))/100:.0f}s "
              f"rss {int(rss)//1024} MiB read {int(io['read_bytes'])//1048576} MiB write {int(io['write_bytes'])//1048576} MiB")
    except (OSError, IndexError, KeyError, ValueError):
        pass
if os.path.isdir(cache):
    print("   cache dir:", {f: os.path.getsize(f"{cache}/{f}") // 1048576 for f in os.listdir(cache)}, "MiB")
PY
  done
}
sampler &
SAMPLER=$!

hr "scan (CORE_IMAGES=${CORE_IMAGES:-all five}, attempt timeout ${VULNIX_ATTEMPT_TIMEOUT}s)"
start=$(date +%s)
./lint.sh images
rc=$?
kill $SAMPLER 2>/dev/null
hr "scan exit $rc after $(( $(date +%s) - start )) s"
cat /sys/fs/cgroup/cpu.stat 2>/dev/null | sed 's/^/cpu.stat /'
exit $rc
