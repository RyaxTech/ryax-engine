# Ryax IntelliScale

## What is Ryax IntelliScale

**The AI-empowered resource management optimizations within Ryax are brought through Ryax IntelliScale**

Ryax IntelliScale recommends the size of the container of each action of a
workflow: CPU request and limit, memory, and a slice of a GPU. It learns from the
utilization metrics of past executions and recommends a size as close as
possible to what the action actually used, to avoid wasting resources and to fit
more executions on the same nodes.

IntelliScale is a Python service built like the Runner and the Worker (domain,
application and infrastructure layers, driven by an internal message bus). It
keeps its state in memory and is reached only over the message broker.

Three algorithms live in `ryax/intelliscale/domain/algorithms/`, and two are
active:

- `vpa_pilot_rule` : rule-based recommendation of **CPU request, CPU limit and
  memory**, computed from statistics of the historical utilization.
- `simple_mig_recommender` : recommends the **GPU memory and the share of a
  card** an action needs.
- `vpa_pilot_ml` : an ML-driven variant. Only its state class exists in the
  tree and it is not wired into the service, so it cannot be selected.

There is no algorithm selector: the rule-based and the GPU recommenders both run.

## Install and configure

IntelliScale is a deployment with one pod, installed by the `intelliscale`
subchart of the Ryax Helm chart. It takes no command line flag: the process
does not parse any. It is configured by a YAML file and by two environment
variables set by the chart.

| Variable | Set from | Role |
|---|---|---|
| `RYAX_CONFIG_APP` | the chart, `/intelliscale-config/config.yaml` | Path of the YAML configuration file |
| `RYAX_BROKER` | the secret named by `brokerSecret` (key `broker`) | RabbitMQ URL. **Required**, IntelliScale refuses to start without it |
| `RYAX_OTLP_ENDPOINT` | `global.monitoring.otlpEndpoint` | OpenTelemetry collector endpoint |

### The `config:` values

The `config:` block of `charts/ryax/subcharts/intelliscale/values.yaml` is
rendered into a ConfigMap and mounted as the **whole** configuration file.

!!! warning "A key you remove does not fall back to a default"
    The file is not merged with any default: a key you leave out of `config:`
    reaches the service as `None`, not as the value the code would otherwise
    use. A setting only has a usable default if the code handles `None`
    explicitly, as `ComputeShareLadder.__init__`
    (`domain/algorithms/simple_mig_recommender/mig_profile.py`) does for
    `total_compute_slices` and `compute_buckets`. For everything else, keep the
    chart's keys and change their values rather than deleting them.

```yaml
config:
  algorithm_configs:
    vpa_pilot_rule:
      cpu_request:   # same keys for cpu_limit and memory
        data_source: sp_95
        policy: weighted_avg
        max_range_samples: 10
        weighted_avg_decay_half_life_in_seconds: 43200
        fluctuation_reducer_duration_in_seconds: 3600
        safety_margin_lower: 0.1
        safety_margin_upper: 0.15
    simple_mig_recommender:
      total_compute_slices: 7
  server_ports:
    metrics_server_port: 8090
  message_bus:
    keep_event_history: false
```

| Key | Default | Description |
|---|---|---|
| `algorithm_configs.vpa_pilot_rule.cpu_request`, `.cpu_limit`, `.memory` | see the chart | One independent rule-based estimator per quantity, each with the keys below |
| `...data_source` | `sp_95` (request), `max` (limit), `sp_98` (memory) | Utilization statistic of an execution that feeds the estimator: `sp_90`, `sp_95`, `sp_98` (percentiles), `avg` or `max` |
| `...policy` | `weighted_avg` (request), `max` (limit and memory) | How samples are combined: `max` or `weighted_avg`. Any other value is rejected |
| `...max_range_samples` | `10` | Size of the sample window of the estimator |
| `...weighted_avg_decay_half_life_in_seconds` | `43200` | Time for a sample to lose half its weight (used by `weighted_avg`) |
| `...fluctuation_reducer_duration_in_seconds` | `3600` | Duration of the fluctuation reducer window |
| `...safety_margin_lower`, `...safety_margin_upper` | `0.1`/`0.15` (request, memory), `0.2`/`0.3` (limit) | Margins applied around the estimate |
| `algorithm_configs.simple_mig_recommender.total_compute_slices` | `7` | Fallback used to read the MIG profile of an execution as a share of a card, see the note below. Optional |
| `algorithm_configs.simple_mig_recommender.compute_buckets` | `20` | Number of candidate shares of a card. Optional, not in the chart, and there is no reason to change it |
| `server_ports.metrics_server_port` | `8090` | Port of the Prometheus metrics endpoint, also used by the probes |
| `message_bus.keep_event_history` | `false` | Keep the history of the internal bus events in memory (debugging) |

!!! warning "Chart keys the service does not read"
    `server_ports.api_grpc_server_port` and
    `algorithm_configs.memory_oom_processor.bump_up_ratio` are present in the
    chart values, but the Python service reads neither. IntelliScale no longer
    runs a gRPC server (the port only names the port of the Kubernetes Service)
    and OOM bump-up is done by the Runner on retry, so changing them has no
    effect on the recommendations. Likewise the `otlp_endpoint` key of the file
    is ignored: the endpoint comes from `RYAX_OTLP_ENDPOINT`, that is from
    `global.monitoring.otlpEndpoint`.

!!! note
    To recommend GPU MIG instances, the GPU nodes must be pre-partitioned into
    MIG instances by the cluster administrator. See
    [GPU node pools and MIG](../howto/gpu_node_pools.md) for how to label your
    GPU nodes with `nvidia.com/mig.config` and how to keep actions off a GPU
    node until its MIG geometry is in place.

!!! note "IntelliScale recommends a size, not a profile"
    A GPU recommendation is an amount of **GPU memory in GB** and a **share of
    a card** between 0 and 1 — not a MIG profile name. IntelliScale knows what
    a workload used, not what hardware exists; the Runner resolves the pair
    against the partitions its node pools actually registered and picks one,
    under `RYAX_SCHEDULER_GPU_FIT_POLICY`. See
    [GPU node pools and MIG](../howto/gpu_node_pools.md).

    The candidates it ranks are an even split of a card into 20 buckets and
    describe no real hardware. A 0.05 step is finer than any MIG geometry, so
    the Runner can always round the answer up to a partition that exists.

    It learns from the share each execution actually had, which Ryax resolves
    from the node pool's GPU model and sends with the execution.
    `total_compute_slices` (under `algorithm_configs.simple_mig_recommender`)
    is the fallback for an execution that arrives without it — an older worker,
    or a pool with no model recorded — and reads the reported MIG profile as a
    fraction of that many slices. It is cluster-wide, so it is only right on
    homogeneous hardware; set it to 4 for an all-A30 cluster, or record the
    models and it goes unused. It never limits what can be recommended.

    The old `gpu_mig_instance` field is gone and its field number reserved. A
    Runner that predates the memory/compute pair therefore receives no GPU
    recommendation and keeps its own default, the largest partition available.

!!! note "One model per piece of hardware, not per site"
    A recommendation is only valid for the machine it was measured on. The GPU
    share is learned per **GPU model**, CPU and memory per **instance type**.
    Site is not part of the key: two sites holding the same card are one
    population and learn faster together, while two node pools in one site
    holding different cards no longer contaminate each other.

    Hardware that cannot be identified — a node pool with no `gpu_model`
    recorded, or an HPC site, which has no instance type — is one shared
    population, which is how every recommendation behaved before this key
    existed. Nothing fragments on upgrade.

    The Runner resolves a recommendation **after** it has chosen a node pool,
    against that pool's hardware, rather than at execution-creation time when
    no hardware has been chosen yet. So one action can be offered a different
    number on each candidate pool, and runs with the one belonging to the pool
    it lands on.

## API

IntelliScale has no REST or gRPC API and reads no annotation of the
deployments. It communicates over the RabbitMQ broker with the messages defined
in
`ryax/intelliscale/infrastructure/messaging/messages/intelliscale_messaging.proto`
(package `intelliscale_messaging`) in the IntelliScale repository.

| Message | Direction | Routing prefix | Producer |
|---|---|---|---|
| `ExecutionMetricsUpdated` | inbound | `Worker` | the Worker of every site. Carries the `execution_id` and a `metrics` Struct (utilization, allocation, site, node pool) |
| `CompleteExecutionMetric` | inbound | `Runner` | the Runner, when an execution ends. Carries the image, final state, resources and timing |
| `Recommendation` | outbound | `Intelliscale` | IntelliScale, consumed by the Runner |

Both inbound messages are read from the queue `IntelliscaleQ`. On each of them
IntelliScale publishes the recommendation for the action; on
`ExecutionMetricsUpdated` it first feeds the metrics to its estimators
(`CompleteExecutionMetric` carries no utilization and only triggers a
recommendation). A `Recommendation` contains:

- `site_id` and `action_container_image`, which identify the action;
- `cpu_request_m`, `cpu_limit_m` and `memory`, all optional;
- `gpu_memory_gb` and `gpu_compute_fraction`, optional, the GPU size needed;
- `gpu_model` and `instance_type`, optional, the hardware it was measured on and
  is valid for. Both are absent when the hardware is unknown.

Field 6 (`gpu_mig_instance`) is reserved. The recommendation is the raw one:
IntelliScale never applies it and does not bump it up after an OOM. The Runner
reads it, resolves it against the node pool an execution is placed on and
owns the OOM bump-up.

!!! warning "The Runner keeps a copy of the `.proto`"
    `Recommendation` is consumed by the Runner, which keeps its own copy of the
    file at `ryax/common/messaging/messages/intelliscale_messages.proto` in the
    Runner repository. The two must stay wire-compatible: same field numbers,
    same types. Regenerate both with the same toolchain, or the generated
    headers disagree on the protobuf runtime version.

## Behaviour and architecture

```text
  Worker (each site)  --ExecutionMetricsUpdated-->  +----------------------+
  Runner              --CompleteExecutionMetric-->  |    IntelliScale      |
                                                    |  vpa_pilot_rule      |
  Runner  <-----------------Recommendation--------  |  simple_mig_recommender
                                                    +----------------------+
                                                       state kept in memory
```

The service follows the layout of the Runner and the Worker:

- `domain/` : entities, the algorithms (`domain/algorithms/<name>/`), their
  volatile states and the commands and events of the internal bus.
- `application/` : the handlers and services that run the algorithms
  (`application/algorithms/<name>/`) and the internal message bus.
- `infrastructure/` : RabbitMQ consumer and publisher, the protobuf messages,
  the in-memory repositories, the Prometheus metrics server and the
  OpenTelemetry tracer.
- `container.py` : the dependency injection container, which is where the
  configuration above is bound to the algorithms.

A recommendation is computed and published every time an inbound message is
received. Nothing is polled, nothing is persisted: the learned state is lost
when the pod restarts, and the estimators start again from the next executions.
