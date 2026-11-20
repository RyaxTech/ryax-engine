#!/usr/bin/env bash
# Throwaway diagnostic: why vulnix takes > 15 min per attempt in CI when it
# takes ~3 min locally under the same limits. Not for merging.
set -uo pipefail

hr() { printf '\n===== %s  %s\n' "$(date -u +%T)" "$*"; }

hr "environment (VARIANT=$VARIANT, VULNIX_CACHE_DIR=$VULNIX_CACHE_DIR)"
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
  local prev_thr=0 prev_us=0
  while sleep 30; do
    local thr us
    thr=$(awk '/^nr_throttled/{print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null || echo 0)
    us=$(awk '/^throttled_usec/{print $2}' /sys/fs/cgroup/cpu.stat 2>/dev/null || echo 0)
    printf '[sample %s] load %s | throttled +%s periods, +%s s | mem %s MiB\n' \
      "$(date -u +%T)" "$(cut -d' ' -f1-3 /proc/loadavg)" \
      "$((thr - prev_thr))" "$(( (us - prev_us) / 1000000 ))" \
      "$(( $(cat /sys/fs/cgroup/memory.current 2>/dev/null || echo 0) / 1048576 ))"
    prev_thr=$thr; prev_us=$us
    for pid in $(pgrep -f "vulnix" | head -3); do
      [ -r /proc/$pid/stat ] || continue
      printf '   pid %s state %s wchan %s cpu(user+sys ticks) %s rss %s MiB io r=%s w=%s\n' "$pid" \
        "$(awk '{print $3}' /proc/$pid/stat)" "$(cat /proc/$pid/wchan 2>/dev/null)" \
        "$(awk '{print $14+$15}' /proc/$pid/stat)" \
        "$(( $(awk '/VmRSS/{print $2}' /proc/$pid/status) / 1024 ))" \
        "$(awk '/^read_bytes/{print $2}' /proc/$pid/io 2>/dev/null)" \
        "$(awk '/^write_bytes/{print $2}' /proc/$pid/io 2>/dev/null)"
    done
    [ -d "$VULNIX_CACHE_DIR" ] && echo "   cache dir: $(du -sm "$VULNIX_CACHE_DIR" | cut -f1) MiB, $(ls "$VULNIX_CACHE_DIR" | tr '\n' ' ')"
  done
}
sampler &
SAMPLER=$!

hr "scan (CORE_IMAGES=$CORE_IMAGES, attempt timeout ${VULNIX_ATTEMPT_TIMEOUT}s)"
start=$(date +%s)
./lint.sh images
rc=$?
kill $SAMPLER 2>/dev/null
hr "scan exit $rc after $(( $(date +%s) - start )) s"
cat /sys/fs/cgroup/cpu.stat 2>/dev/null | sed 's/^/cpu.stat /'
exit $rc
