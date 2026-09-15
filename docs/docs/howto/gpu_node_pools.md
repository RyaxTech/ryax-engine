# GPU node pools and MIG

This page covers setting up a GPU node pool for Ryax actions, including
[Multi-Instance GPU (MIG)](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/)
partitioning and the readiness gate that keeps actions off a GPU node until the
node can actually serve them.

## Why a readiness gate

When the cluster autoscaler adds a GPU node, the kubelet reports it `Ready` long
before the NVIDIA stack on it is usable. The driver, the container toolkit, the
device plugin and — on a MIG pool — the MIG partitioning itself all land after
the node has joined. Anything scheduled in that window hits one of two failures:

* the action is handed a **whole GPU** instead of the MIG slice its node pool
  advertises, which is exactly what Ryax IntelliScale's MIG recommendations
  assume it will not get;
* `nvidia-device-plugin-daemonset` crash-loops with

    ```plaintext
    at least one device with migEnabled=true was not configured correctly:
    error visiting device: device 0 has no MIG devices configured
    ```

This is [NVIDIA/gpu-operator#2670](https://github.com/NVIDIA/gpu-operator/issues/2670).
The fix, following
[NVIDIA/gpu-operator#2573](https://github.com/NVIDIA/gpu-operator/pull/2573), is
a **startup taint**: every new GPU node joins tainted, and the taint is removed
only once the node has proved it is ready. Ryax ships the two pieces that do
that, in the Kubernetes Worker chart:

| Component | Role |
|---|---|
| Node pool template (your cloud provider) | Applies the startup taint to every new GPU node |
| [node-problem-detector](https://github.com/kubernetes/node-problem-detector) | Runs a GPU readiness probe on each GPU node and publishes the `nvidia.com/GPUReady` node condition |
| Ryax untainter | Removes the startup taint once that condition is `True` **and** the MIG geometry is the one the pool asked for |
| NVIDIA GPU Operator | Unchanged, but its operands must tolerate the startup taint |

!!! warning
    Ryax actions must **never** tolerate the startup taint — the taint is what
    keeps them off the node. Only the components that make the node ready
    (the GPU Operator operands, node-feature-discovery, node-problem-detector)
    tolerate it. Ryax adds tolerations for `ryax.tech/ryaxns-execs` and `sku`
    only, so there is nothing to do here.

## Prerequisites

* A GPU node pool, dedicated to Ryax actions. See
  [the worker installation guide](./worker-install.md) for the
  `ryax.tech/ryaxns-execs` taint that lets a pool scale to zero.
* The [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html)
  with its [MIG Manager](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-operator-mig.html),
  which reads the `nvidia.com/mig.config` node label and applies the matching
  MIG geometry. Ryax does **not** partition GPUs itself.
* A cluster autoscaler whose flags you control (see step 5).

Two rules about the pool itself:

* **Keep each GPU node pool homogeneous** — one MIG profile per pool. Ryax picks
  a node pool, not a device, so a pool with mixed geometries cannot be reasoned
  about.
* **Run the GPU Operator with `mig.strategy=single`.** Ryax action pods request
  `nvidia.com/gpu`, not per-profile resources such as `nvidia.com/mig-1g.10gb`,
  and `single` is the strategy that advertises MIG instances under that name.

The MIG profiles Ryax IntelliScale can recommend are currently fixed at
`mig-1g.10gb`, `mig-3g.40gb` and `mig-7g.80gb`. Give your pools one of these.

## Step 1 — set the MIG profile on the node pool

Label the nodes with the profile you want, prefixed with `all-` so it applies to
every GPU on the node:

```sh
# Example: split every GPU on the node into 1g.10gb MIG instances
kubectl label node <node-name> nvidia.com/mig.config=all-1g.10gb --overwrite
```

Set the same label through your cloud provider's **node-pool labels**, not by
hand, so nodes created on scale-up are labelled as they join.

!!! note
    Earlier Ryax versions shipped a node-labeler DaemonSet that derived this
    label from an `all-*` pool label (`config.MIG` and `labeler` in the worker
    chart). It has been removed — see [Upgrading](#upgrading) below.

## Step 2 — enable the readiness gate

In your `worker-values.yaml`:

```yaml
gpuReadiness:
  enabled: true
```

Then upgrade the worker:

```sh
helm upgrade --install ryax-worker oci://registry.ryax.org/release-charts/ryax-worker-k8s \
  --values worker-values.yaml -n ryaxns
```

!!! warning
    Do this **before** step 3. A node that joins with the startup taint while
    nothing is in place to remove it stays tainted, and therefore unusable,
    forever. The gate is harmless on its own: with no taint on the node pool
    there is nothing for it to remove.

The full list of settings — the taint key, the condition type, the probe
interval and timeout, the images — is in the
[`ryax-worker-k8s` chart reference](https://gitlab.com/ryax-tech/ryax/ryax-engine/-/blob/master/charts/worker-k8s/README.md)
under *GPU Readiness*. The defaults match the rest of this page.

## Step 3 — add the startup taint to the node pool

The taint key is `readiness.k8s.io/nvidia-gpu-not-ready`, with value `pending`
and effect `NoSchedule`. Add it to the node pool **template**, so every node
created from it starts tainted. How depends on your provider:

```sh
# AWS, with eksctl -- in the nodeGroup's `taints:` list
#   - key: readiness.k8s.io/nvidia-gpu-not-ready
#     value: pending
#     effect: NoSchedule

# Azure AKS
az aks nodepool update ... --node-taints "readiness.k8s.io/nvidia-gpu-not-ready=pending:NoSchedule"

# GCP GKE
gcloud container node-pools create ... --node-taints "readiness.k8s.io/nvidia-gpu-not-ready=pending:NoSchedule"
```

See [the AWS guide](./kubernetes_aws.md#add-gpu-node-groups) for a complete
eksctl node group.

## Step 4 — let the GPU Operator tolerate the taint

The GPU Operator's operands are what *make* the node ready, so they have to run
while the taint is still on it. Two separate values control this, and **both
replace their defaults rather than appending**, so the existing entries must be
repeated — along with whatever taints your GPU pool already carries:

```yaml
daemonsets:
  tolerations:
    # gpu-operator's own default -- this list replaces it, so keep it.
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
    - key: readiness.k8s.io/nvidia-gpu-not-ready
      operator: Exists
      effect: NoSchedule
    # The taints Ryax GPU pools carry.
    - key: ryax.tech/ryaxns-execs
      operator: Equal
      value: only
      effect: NoSchedule
    - key: sku
      operator: Equal
      value: gpu
      effect: NoSchedule

# node-feature-discovery is a gpu-operator subchart and is NOT covered by
# daemonsets.tolerations. It must run on a tainted node, because it is what
# labels the node nvidia.com/gpu.present -- which is what the readiness probe
# selects on. Miss this and the node is never probed, never untainted, and the
# autoscaler eventually scales it away and tries again.
node-feature-discovery:
  worker:
    tolerations:
      # The chart's own defaults -- keep them.
      - key: node-role.kubernetes.io/control-plane
        operator: Equal
        value: ""
        effect: NoSchedule
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      - key: readiness.k8s.io/nvidia-gpu-not-ready
        operator: Exists
        effect: NoSchedule
      - key: ryax.tech/ryaxns-execs
        operator: Equal
        value: only
        effect: NoSchedule
      - key: sku
        operator: Equal
        value: gpu
        effect: NoSchedule
```

If you would rather not depend on node-feature-discovery reaching the node, set
`gpuReadiness.nodeSelector: {}` in the worker values: the probe then runs on
every node instead of only on labelled GPU nodes.

## Step 5 — tell the cluster autoscaler the taint is temporary

**This step is not optional.** Ryax action pods do not tolerate the startup
taint. An autoscaler that has not been told the taint is temporary concludes
that a node from this pool could not host the pending pod, and so **never scales
the pool up at all** — the GPU action simply stays `Pending`.

On cluster-autoscaler 1.36 and newer, pass the prefix flag:

```plaintext
--startup-taint-prefix=readiness.k8s.io/
```

On older versions, pass the full key (repeatable):

```plaintext
--startup-taint=readiness.k8s.io/nvidia-gpu-not-ready
```

Check it is actually applied:

```sh
kubectl -n kube-system get deploy cluster-autoscaler \
  -o jsonpath='{.spec.template.spec.containers[0].args}'
```

Provider notes:

* **Self-managed cluster-autoscaler** (the usual setup on EKS, and what
  [the AWS guide](./kubernetes_aws.md#enable-autoscaler-recommended) installs):
  edit the Deployment's args.
* **GKE**: the managed autoscaler is planned to recognise the
  `readiness.k8s.io/` prefix with no configuration.
* **AKS and other managed autoscalers**: the flags are not user-editable and the
  prefix is not preset, so this pattern does not work there yet.
* **Karpenter**: use its native `spec.template.spec.startupTaints` instead.

## Validate

With the GPU pool at zero, deploy a GPU action and watch the order of events:

```sh
# the new node joins tainted
kubectl get nodes -w

# the probe reports, then the taint goes away
NODE=<new-node>
kubectl get node $NODE -o jsonpath='{.status.conditions[?(@.type=="nvidia.com/GPUReady")]}'
kubectl get node $NODE -o jsonpath='{.metadata.labels.nvidia\.com/mig\.config\.state}'
kubectl get node $NODE -o jsonpath='{.spec.taints}'
```

The action pod must stay `Pending` until the condition is `True`, the MIG state
is `success` and the taint is gone — then start and see only its MIG slice.

## Scale-from-zero

To scale a pool up, the autoscaler first checks that the pending pod would fit a
node from that pool. With the pool at zero there is no node to copy, so it
builds a template from the pool's static configuration alone — its instance type
and the labels and taints declared on the pool.

The consequence: **never select a GPU pool on a label the GPU Operator applies
after boot.** `nvidia.com/mig.config.state` and `nvidia.com/mig.strategy` are
set only once MIG configuration finishes, so they are never in a zero-pool
template, and a node pool selector using them keeps the pool at zero forever.
Gating on `nvidia.com/mig.config.state=success` used to be a common way to keep
pods off an unconfigured node; the startup taint is what does that now. Select
the pool on a static label instead — the pool-name label
(`ryax.tech/nodepool`, `eks.amazonaws.com/nodegroup`, `agentpool`, …).

## Troubleshooting

One command shows the state of every GPU node and covers most failures:

```sh
kubectl get nodes -l nvidia.com/gpu.present=true -o custom-columns=\
'NAME:.metadata.name,TAINTS:.spec.taints[*].key,GPUREADY:.status.conditions[?(@.type=="nvidia.com/GPUReady")].status,MIG:.metadata.labels.nvidia\.com/mig\.config,STATE:.metadata.labels.nvidia\.com/mig\.config\.state'

kubectl logs -n ryaxns deploy/<release>-ryax-worker-k8s-gpu-untainter
```

**No GPU node appears at all, the action stays `Pending`.** The autoscaler is
treating the startup taint as permanent — step 5.

**`GPUREADY` is empty.** node-problem-detector is not running on that node:
`kubectl get pods -n ryaxns -l app.kubernetes.io/name=ryax-worker-k8s-gpu-ready-monitor -o wide`.
Either the node is not labelled `nvidia.com/gpu.present` (node-feature-discovery
could not run on it — step 4), or the pool carries a taint the probe does not
tolerate (`gpuReadiness.tolerations`).

**`GPUREADY` is `Unknown`.** The probe is timing out. Raise
`gpuReadiness.probeTimeoutSeconds`.

**`GPUREADY` is `True` but the taint is still there.** `STATE` is not `success`:
the MIG Manager has not finished, or has failed. Check `MIG` names a profile the
hardware supports, and look at the `nvidia-mig-manager` pod on that node. Setting
`gpuReadiness.untainter.requireMigConfigSuccess: false` releases nodes on the
driver check alone — appropriate only for pools that do not use MIG.

**Everything is `True` and `success`, and the taint is still there.** Check the
untainter's logs above; it names every node it is waiting on and why.

**Pods land on the node before it is ready.** The workload tolerates the startup
taint. Only components that participate in making the node ready should.

## Upgrading

Ryax used to ship a `gpu-node-labeler` DaemonSet in the worker chart, which read
a node label starting with `all-` and rewrote it into `nvidia.com/mig.config`.
It is gone, along with the `config.MIG` and `labeler` values.

!!! warning
    If your GPU pools relied on that DaemonSet, **set `nvidia.com/mig.config`
    directly in the cloud node-pool labels before upgrading** (step 1). Nodes
    already running keep the label the DaemonSet wrote, so MIG stays configured
    on them — but nodes created after the upgrade will never be partitioned.

Helm removes the DaemonSet and its ServiceAccount, ClusterRole and
ClusterRoleBinding — all named `<release>-ryax-worker-k8s-gpu-node-labeler` — on
upgrade. ArgoCD and Flux only do so with pruning enabled; otherwise delete them
by hand.
