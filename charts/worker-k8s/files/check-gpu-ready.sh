#!/bin/sh
#
# node-problem-detector custom plugin: is the NVIDIA stack on this node usable?
#
# The exit codes are INVERTED with respect to what the name suggests, and that
# is not a mistake. node-problem-detector maps a permanent rule's plugin exit
# status onto the condition the rule owns: NonOK (exit 1) sets the condition
# True with the *rule's* reason, OK (exit 0) sets it False with the
# *condition's* default reason. The condition here asserts "the GPU is ready",
# so:
#
#   exit 1  -> nvidia.com/GPUReady = True    -> the untainter may release
#   exit 0  -> nvidia.com/GPUReady = False   -> not ready yet
#   timeout -> nvidia.com/GPUReady = Unknown -> not ready yet
#
# Whatever this prints becomes the condition message and is truncated at
# max_output_length (80), so print exactly one short line.
#
# Every nvidia-smi call is a cheap subcommand (-L, --query-gpu) rather than a
# bare `nvidia-smi`: the plugin timeout is a handful of seconds and a full
# nvidia-smi on a freshly loaded multi-GPU driver is not fast. A timed-out
# probe leaves the condition Unknown, which the untainter cannot tell apart
# from "never ready".

set -u

READY=1
NOT_READY=0

# The GPU Operator's driver container bind-mounts its own root at
# /run/nvidia/driver on the host after this pod has started -- which is what
# the HostToContainer mount propagation on /host is for. Try it first: with a
# container-managed driver the host itself has no nvidia-smi. Fall back to the
# host root for pre-installed drivers (GPU AMIs, bare metal).
ROOT=""
for candidate in /host/run/nvidia/driver /host; do
  if chroot "$candidate" nvidia-smi -L >/dev/null 2>&1; then
    ROOT="$candidate"
    break
  fi
done

if [ -z "$ROOT" ]; then
  echo "nvidia-smi not answering"
  exit "$NOT_READY"
fi

# GPUs with MIG turned on. A card that does not support MIG reports "[N/A]" and
# one with MIG off reports "Disabled"; neither contains "Enabled".
enabled=$(chroot "$ROOT" nvidia-smi --query-gpu=mig.mode.current --format=csv,noheader 2>/dev/null |
  awk '/Enabled/ { n++ } END { print n + 0 }')

if [ "$enabled" -eq 0 ]; then
  echo "driver up, no MIG on this node"
  exit "$READY"
fi

# GPUs that actually carry a MIG device. `nvidia-smi -L` lists each card and
# indents its MIG devices underneath:
#
#   GPU 0: NVIDIA A100-SXM4-40GB (UUID: GPU-...)
#     MIG 1g.5gb     Device  0: (UUID: MIG-...)
#
# A card with MIG enabled and nothing under it is precisely the state that
# crash-loops nvidia-device-plugin with "device 0 has no MIG devices
# configured", and that hands an action a whole card instead of its slice.
# Counted per card, not globally: mid-reconfiguration one card can be done
# while the next is not.
partitioned=$(chroot "$ROOT" nvidia-smi -L 2>/dev/null |
  awk '/^GPU / { seen = 0 }
       /MIG /  { if (!seen) { seen = 1; n++ } }
       END     { print n + 0 }')

if [ "$partitioned" -lt "$enabled" ]; then
  echo "MIG on $enabled GPU(s), $partitioned partitioned"
  exit "$NOT_READY"
fi

echo "driver up, $partitioned MIG GPU(s) partitioned"
exit "$READY"
