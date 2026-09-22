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

set -u

READY=1
NOT_READY=0

# Written by the node-label-watcher sidecar; see the MIG branch below.
MIG_INTENT_FILE="${MIG_INTENT_FILE:-/nodeinfo/mig.config}"

# Everything below runs on the host, in its mount namespace, the same way the
# registry certificate setup DaemonSet reaches the node. After nsenter both the
# binary and the paths it resolves belong to the host, so this image only has
# to carry nsenter itself -- and a mount the host gains *after* this pod starts
# (the GPU Operator bind-mounts its driver root at /run/nvidia/driver once the
# driver container is up) is visible with no mount propagation on our side.
#
# Needs hostPID, so that PID 1 is the host's init rather than this pod's, and a
# privileged container.
#
# nsenter switches the mount namespace but keeps this container's environment,
# so a bare command name would be looked up along the *container's* PATH inside
# the *host's* filesystem. That happens to work on the usual node images and
# silently does not on others, so the PATH is set explicitly and the command is
# run through the host's /bin/sh, the one interpreter POSIX guarantees is there.
# The last entry is where NixOS keeps system binaries; it is inert elsewhere and
# is listed last so it can never shadow a normal distribution's copy.
HOST_PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/run/current-system/sw/bin'
host() { nsenter --target 1 --mount -- /bin/sh -c "export PATH='$HOST_PATH'; $*"; }

# Tell "the host is not reachable" apart from "this node has no GPU yet".
# Without this a missing nsenter, a missing hostPID or a non-privileged
# container all read as a node that is simply still booting, and the node stays
# tainted forever with nothing to say why.
if ! host true >/dev/null 2>&1; then
  echo "cannot enter host namespace"
  exit "$NOT_READY"
fi

# Two driver installations to cover, probed in order:
#   - the GPU Operator's driver container, whose root the operator bind-mounts
#     at /run/nvidia/driver on the host;
#   - a driver installed on the host itself (GPU AMIs, bare metal).
# Resolve which one answers once, rather than on every call below.
if host chroot /run/nvidia/driver nvidia-smi -L >/dev/null 2>&1; then
  smi() { host chroot /run/nvidia/driver nvidia-smi "$@"; }
elif host nvidia-smi -L >/dev/null 2>&1; then
  smi() { host nvidia-smi "$@"; }
else
  echo "nvidia-smi not answering"
  exit "$NOT_READY"
fi

# Only cheap nvidia-smi subcommands from here: the plugin timeout is a handful
# of seconds and a bare nvidia-smi on a freshly loaded multi-GPU driver is not
# fast. A timed-out probe leaves the condition Unknown, which the untainter
# cannot tell apart from "never ready".

# GPUs with MIG turned on. A card that does not support MIG reports "[N/A]" and
# one with MIG off reports "Disabled"; neither contains "Enabled".
enabled=$(smi --query-gpu=mig.mode.current --format=csv,noheader 2>/dev/null |
  awk '/Enabled/ { n++ } END { print n + 0 }')

if [ "$enabled" -eq 0 ]; then
  # MIG is off. Whether that is correct depends on what the pool asked for, and
  # nvidia-smi cannot say: a full-GPU pool runs with MIG off for good, while a
  # MIG pool looks identical for the minute or two before MIG Manager enables
  # it. The intent lives in the node's nvidia.com/mig.config label, which the
  # sidecar publishes here (see files/watch-node-labels.sh -- this image has no
  # HTTP client, so it cannot read the label itself).
  if [ -f "$MIG_INTENT_FILE" ]; then
    intent=$(cat "$MIG_INTENT_FILE" 2>/dev/null || true)
  else
    # The sidecar has not answered yet. Deliberately ready rather than not:
    # the untainter gates on nvidia.com/mig.config.state independently, so
    # nothing is released early by this, whereas failing closed here would let
    # one broken sidecar keep every GPU node in the cluster tainted.
    echo "driver up, MIG intent unknown"
    exit "$READY"
  fi

  case "$intent" in
    ""|all-disabled)
      echo "driver up, MIG mode off"
      exit "$READY" ;;
    *)
      echo "MIG $intent asked for, not enabled yet"
      exit "$NOT_READY" ;;
  esac
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
partitioned=$(smi -L 2>/dev/null |
  awk '/^GPU / { seen = 0 }
       /MIG /  { if (!seen) { seen = 1; n++ } }
       END     { print n + 0 }')

if [ "$partitioned" -lt "$enabled" ]; then
  echo "MIG on $enabled GPU(s), $partitioned partitioned"
  exit "$NOT_READY"
fi

echo "driver up, $partitioned MIG GPU(s) partitioned"
exit "$READY"
