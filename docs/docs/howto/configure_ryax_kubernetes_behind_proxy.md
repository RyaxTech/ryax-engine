# Ryax Behind a Proxy

Behind a proxy we need to configure variables so essential services access the internet to download dependencies.
We must also completely turn off the feature of having an internet exposed registry. This will make a `NodePort`
kubernetes resource to expose the internal registry. With the internal registry exposed through localhost 
enables to deploy actions within the same kubernetes cluster and will require the worker to be installed inside 
the same kubernetes cluster. Multi-site behind proxy, although feasible, it is out of the scope of this tutorial.

First retrieve the values of you current ryax installed release with helm, assuming your release is named
`ryax` and installed on namespace `ryaxns`.

```shell
helm get values -n ryaxns ryax --output yaml > ryax-current-values.yaml
```

To be safe we can copy that file to another one so we can safely edit it to add the proxy support.

```shell
cp ryax-current-values.yaml ryax-proxy-values.yaml
```

Now we can edit the `ryax-proxy-values.yaml`. First, when behind a proxy, you need to first disable tls and
certificates so it does not deploy an internet exposed 
registry, creating all necessary changes to deploy your actions from localhost.

```yaml
certManager:
  enabled: false
global:
  tls:
    enabled: false
```

Secondly, we need to add `extraEnvVars` to `grafana` and `extraEnv` to `action-builder` so it enables these
services to access  the internet and download necessary dependencies.

```yaml
global:
  grafana:
    extraEnvVars:
    - name: HTTP_PROXY
      value: http://PROXY_IP:PROXY_PORT
    - name: HTTPS_PROXY
      value: http://PROXY_IP:PROXY_PORT
    - name: NO_PROXY
      value: localhost,127.0.0.1,::1,10.0.0.0/8,192.168.0.0/16,.svc,.cluster.local
action-builder:
  extraEnv:
  - name: HTTP_PROXY
    value: http://PROXY_IP:PROXY_PORT
  - name: HTTPS_PROXY
    value: http://PROXY_IP:PROXY_PORT
  - name: NO_PROXY
    value: localhost,127.0.0.1,::1,10.0.0.0/8,192.168.0.0/16,.svc,.cluster.local
  - name: NIX_CURL_FLAGS
    value: --proxy http://PROXY_IP:PROXY_PORT
  - name: UV_HTTP_PROXY
    value: http://PROXY_IP:PROXY_PORT
  - name: UV_HTTPS_PROXY
    value: http://PROXY_IP:PROXY_PORT
  - name: ALL_PROXY
    value: http://PROXY_IP:PROXY_PORT
  - name: NIX_CONFIG
    value: |-
      sandbox = false
      extra-sandbox-paths = /etc/proxy/proxy
  - name: PIP_INDEX_URL
    value: https://pypi.org/simple
  - name: PIP_TRUSTED_HOST
    value: pypi.org
  - name: UV_HTTP_TIMEOUT
    value: "600"
  - name: UV_HTTP_CONNECT_TIMEOUT
    value: "600"
  - name: RYAX_BUILD_ENV_HTTP_PROXY
    value: http://PROXY_IP:PROXY_PORT
  - name: RYAX_BUILD_ENV_HTTPS_PROXY
    value: http://PROXY_IP:PROXY_PORT
  - name: RYAX_BUILD_ENV_ALL_PROXY
    value: http://PROXY_IP:PROXY_PORT
  - name: RYAX_BUILD_ENV_UV_HTTP_PROXY
    value: http://PROXY_IP:PROXY_PORT
  - name: RYAX_BUILD_ENV_UV_HTTPS_PROXY
    value: http://PROXY_IP:PROXY_PORT
```

Finally, we can apply the new options by using the command above, where `ryax` is the release helm on your kubernetes,
and `ryaxns` the namespace where you have ryax installed.

```shell
helm upgrade ryax oci://registry.ryax.org/release-charts/ryax-engine -n ryaxns ---values ryax-proxy-values.yaml
```