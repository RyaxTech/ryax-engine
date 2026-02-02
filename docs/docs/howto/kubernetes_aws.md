# Set up kubernetes cluster for Ryax in AWS

This how-to section explain the step-by-step to instantiate a kubernetes cluster on AWS to run Ryax.
To start we will use environment variables to avoid miss-spell the cluster name and region later. Please,
change name and region accordingly to your requirements.

```shell
export RYAX_CLUSTER_NAME=ryax-demo
export RYAX_CLUSTER_REGION=eu-north-1
```


The best way to create and configure a cluster for Ryax is using a yaml configuration. In our experience,
Ryax works best with at least 2 dedicated `nodegroups`:
* `ryax-exec-nodes`: Tainted for only run pods on namespace `ryaxns-execs`, this taint must follow this exact key, value, effect because pods for actions will automatically add toleration for them;
* `ryax-infra-nodes`: Nodes for general purpose needed to execute the ryax basic services.

!!! warning
    AWS uses `nodegroups` but in Ryax and Kubernetes the term is `nodepools`, we use `nodegroup` and `nodepool` interchangebly throughout this text.

```yaml
cat >cluster-config.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: $RYAX_CLUSTER_NAME
  region: $RYAX_CLUSTER_REGION
  version: "1.34"
managedNodeGroups:
- name: ryax-exec-nodes
  instanceType: m5d.xlarge
  amiFamily: AmazonLinux2023
  minSize: 0
  maxSize: 10
  iam:
    withAddonPolicies:
      autoScaler: true
  labels:
    ryax.tech/nodepool: ryax-exec-nodes
  taints:
  - key: ryax.tech/ryaxns-execs
    value: only
    effect: NoSchedule
  tags:
    k8s.io/cluster-autoscaler/node-template/taint/ryax.tech/ryaxns-execs: "only:NoSchedule"
    k8s.io/cluster-autoscaler/node-template/label/ryax.tech/nodepool: ryax-exec-nodes
- name: ryax-infra-nodes
  instanceType: m5d.xlarge
  minSize: 3
  maxSize: 6
  amiFamily: AmazonLinux2023
  iam:
    withAddonPolicies:
      autoScaler: true
  labels:
    ryax.tech/nodepool: ryax-infra-nodes
  tags:
    k8s.io/cluster-autoscaler/node-template/label/ryax.tech/nodepool: ryax-infra-nodes
EOF
```

Check the content of the file is correct.

```shell
cat cluster-config.yaml
```

Apply the configuration on AWS, feel free to change the kubernetes version and other parameters as fit you best however
keep in mind that we recommend at least kubernetes' version `1.33` to support the latest Linux VMs.

```shell
eksctl create cluster -f cluster-config.yaml
```

While the cluster is deploying you are going to see the 3 stacks for CloudFormation: 1 for the kubernetes cluster
itself; 2 for the 2 requested nodegroups. You can check further by connecting to the
[AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/).

```shell
2025-11-04 10:37:56 [ℹ]  eksctl version 0.208.0-dev+0.208.0.19700101-00:00:00
2025-11-04 10:37:56 [ℹ]  using region eu-north-1
2025-11-04 10:37:56 [ℹ]  setting availability zones to [eu-north-1b eu-north-1c eu-north-1a]
2025-11-04 10:37:56 [ℹ]  subnets for eu-north-1b - public:192.168.0.0/19 private:192.168.96.0/19
2025-11-04 10:37:56 [ℹ]  subnets for eu-north-1c - public:192.168.32.0/19 private:192.168.128.0/19
2025-11-04 10:37:56 [ℹ]  subnets for eu-north-1a - public:192.168.64.0/19 private:192.168.160.0/19
2025-11-04 10:37:56 [ℹ]  nodegroup "ryax-exec-nodes" will use "" [AmazonLinux2023/1.34]
2025-11-04 10:37:56 [ℹ]  nodegroup "ryax-infra-nodes" will use "" [AmazonLinux2023/1.34]
2025-11-04 10:37:56 [ℹ]  using Kubernetes version 1.34
2025-11-04 10:37:56 [ℹ]  creating EKS cluster "ryax-demo" in "eu-north-1" region with managed nodes
2025-11-04 10:37:56 [ℹ]  2 nodegroups (ryax-exec-nodes, ryax-infra-nodes) were included (based on the include/exclude rules)
2025-11-04 10:37:56 [ℹ]  will create a CloudFormation stack for cluster itself and 2 managed nodegroup stack(s)
2025-11-04 10:37:56 [ℹ]  if you encounter any issues, check CloudFormation console or try 'eksctl utils describe-stacks --region=eu-north-1 --cluster=ryax-demo'
2025-11-04 10:37:56 [ℹ]  Kubernetes API endpoint access will use default of {publicAccess=true, privateAccess=false} for cluster "ryax-demo" in "eu-north-1"
2025-11-04 10:37:56 [ℹ]  CloudWatch logging will not be enabled for cluster "ryax-demo" in "eu-north-1"
2025-11-04 10:37:56 [ℹ]  you can enable it with 'eksctl utils update-cluster-logging --enable-types={SPECIFY-YOUR-LOG-TYPES-HERE (e.g. all)} --region=eu-north-1 --cluster=ryax-demo'
2025-11-04 10:37:56 [ℹ]  default addons metrics-server, vpc-cni, kube-proxy, coredns were not specified, will install them as EKS addons
2025-11-04 10:37:56 [ℹ]
2 sequential tasks: { create cluster control plane "ryax-demo",
    2 sequential sub-tasks: {
        2 sequential sub-tasks: {
            1 task: { create addons },
            wait for control plane to become ready,
        },
        2 parallel sub-tasks: {
            create managed nodegroup "ryax-exec-nodes",
            create managed nodegroup "ryax-infra-nodes",
        },
    }
}
2025-11-04 10:37:56 [ℹ]  building cluster stack "eksctl-ryax-demo-cluster"
2025-11-04 10:37:57 [ℹ]  deploying stack "eksctl-ryax-demo-cluster"
2025-11-04 10:38:27 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-cluster"
2025-11-04 10:38:57 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-cluster"
2025-11-04 10:39:58 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-cluster"
2025-11-04 10:40:58 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-cluster"
2025-11-04 10:41:58 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-cluster"
2025-11-04 10:42:58 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-cluster"
2025-11-04 10:43:59 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-cluster"
2025-11-04 10:44:59 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-cluster"
2025-11-04 10:45:59 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-cluster"
2025-11-04 10:47:00 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-cluster"
2025-11-04 10:47:02 [ℹ]  creating addon: metrics-server
2025-11-04 10:47:02 [ℹ]  successfully created addon: metrics-server
2025-11-04 10:47:03 [!]  recommended policies were found for "vpc-cni" addon, but since OIDC is disabled on the cluster, eksctl cannot configure the requested permissions; the recommended way to provide IAM permissions for "vpc-cni" addon is via pod identity associations; after addon creation is completed, add all recommended policies to the config file, under `addon.PodIdentityAssociations`, and run `eksctl update addon`
2025-11-04 10:47:03 [ℹ]  creating addon: vpc-cni
2025-11-04 10:47:03 [ℹ]  successfully created addon: vpc-cni
2025-11-04 10:47:03 [ℹ]  creating addon: kube-proxy
2025-11-04 10:47:04 [ℹ]  successfully created addon: kube-proxy
2025-11-04 10:47:04 [ℹ]  creating addon: coredns
2025-11-04 10:47:05 [ℹ]  successfully created addon: coredns
2025-11-04 10:49:06 [ℹ]  building managed nodegroup stack "eksctl-ryax-demo-nodegroup-ryax-exec-nodes"
2025-11-04 10:49:06 [ℹ]  building managed nodegroup stack "eksctl-ryax-demo-nodegroup-ryax-infra-nodes"
2025-11-04 10:49:06 [ℹ]  deploying stack "eksctl-ryax-demo-nodegroup-ryax-exec-nodes"
2025-11-04 10:49:06 [ℹ]  deploying stack "eksctl-ryax-demo-nodegroup-ryax-infra-nodes"
2025-11-04 10:49:06 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-nodegroup-ryax-exec-nodes"
2025-11-04 10:49:07 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-nodegroup-ryax-infra-nodes"
2025-11-04 10:49:37 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-nodegroup-ryax-exec-nodes"
2025-11-04 10:49:37 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-nodegroup-ryax-infra-nodes"
2025-11-04 10:50:15 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-nodegroup-ryax-infra-nodes"
2025-11-04 10:50:23 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-nodegroup-ryax-exec-nodes"
2025-11-04 10:51:24 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-nodegroup-ryax-infra-nodes"
2025-11-04 10:51:39 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-nodegroup-ryax-exec-nodes"
2025-11-04 10:53:03 [ℹ]  waiting for CloudFormation stack "eksctl-ryax-demo-nodegroup-ryax-exec-nodes"
2025-11-04 10:53:03 [ℹ]  waiting for the control plane to become ready
2025-11-04 10:53:05 [✔]  saved kubeconfig as "/home/velho/.kube/kubeconfig-ryax-general-purpose-2.yaml"
2025-11-04 10:53:05 [ℹ]  no tasks
2025-11-04 10:53:05 [✔]  all EKS cluster resources for "ryax-demo" have been created
2025-11-04 10:53:05 [ℹ]  nodegroup "ryax-exec-nodes" has 2 node(s)
2025-11-04 10:53:05 [ℹ]  node "ip-192-168-17-9.eu-north-1.compute.internal" is ready
2025-11-04 10:53:05 [ℹ]  node "ip-192-168-41-149.eu-north-1.compute.internal" is ready
2025-11-04 10:53:05 [ℹ]  waiting for at least 2 node(s) to become ready in "ryax-exec-nodes"
2025-11-04 10:53:05 [ℹ]  nodegroup "ryax-exec-nodes" has 2 node(s)
2025-11-04 10:53:05 [ℹ]  node "ip-192-168-17-9.eu-north-1.compute.internal" is ready
2025-11-04 10:53:05 [ℹ]  node "ip-192-168-41-149.eu-north-1.compute.internal" is ready
2025-11-04 10:53:05 [✔]  created 2 managed nodegroup(s) in cluster "ryax-demo"
2025-11-04 10:53:07 [ℹ]  kubectl command should work with "/home/velho/.kube/kubeconfig-ryax-general-purpose-2.yaml", try 'kubectl --kubeconfig=/home/velho/.kube/kubeconfig-ryax-general-purpose-2.yaml get nodes'

```

### Get kubectl config

Once your cluster is correctly configured, you can download the kubernetes configuration and use `kubectl` that
will be required for the next steps.

```shell
export KUBECONFIG=~/.kube/kubeconfig-$RYAX_CLUSTER_NAME.yaml
aws eks update-kubeconfig --name $RYAX_CLUSTER_NAME --region $RYAX_CLUSTER_REGION
```

### Check running pods

```shell
kubectl get pods -A
```

In the output verify that all pods are running correctly like below.

```shell
NAMESPACE     NAME                              READY   STATUS    RESTARTS   AGE
kube-system   aws-node-j4gqn                    2/2     Running   0          9m42s
kube-system   aws-node-tms7d                    2/2     Running   0          9m49s
kube-system   coredns-f6495559c-98wnm           1/1     Running   0          13m
kube-system   coredns-f6495559c-pfbgw           1/1     Running   0          13m
kube-system   kube-proxy-gwvfj                  1/1     Running   0          9m42s
kube-system   kube-proxy-vdt95                  1/1     Running   0          9m49s
kube-system   metrics-server-7ff5f5bd6c-cfbf5   1/1     Running   0          13m
kube-system   metrics-server-7ff5f5bd6c-cgz7b   1/1     Running   0          13m
```

### Check labels across nodes

The labels need to be used for the ryax worker, to check the current available node labels you can use the
command below.

```shell
kubectl get nodes -o json | jq -r '.items[] | .metadata.name, .metadata.labels["ryax.tech/nodepool"]'
```

The output should correctly show the label ryax.tech/nodepool added in the configuration.

```shell
kubectl get nodes -o json | jq -r '.items[] | .metadata.name, .metadata.labels["ryax.tech/nodepool"]'                                                                                                                                   ─╯
ip-192-168-18-137.eu-north-1.compute.internal
ryax-infra-nodes
ip-192-168-59-241.eu-north-1.compute.internal
ryax-infra-nodes
ip-192-168-69-203.eu-north-1.compute.internal
ryax-infra-nodes
```

## Enable persistentvolume support on AWS

Ryax requires stateful services that need persistent storage access. By default, in a freshly instantiated AWS EKS kubernetes
cluster this is not the case. Next we are going to do the necessary so Ryax's services can persistent volume claims (PVC)
correctly.

### Set storageclass as default

Check the available storage classes, you should have at least one as EBS for persistent storage and set as default.

```shell
kubectl get storageclass
```

The output should be something of the kind:

```yaml
NAME   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2    kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  22m
```

In the case above only one class exists it uses aws-ebs so it  is persistent
however it does not is the default one.
To set it as default use:

```shell
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

And then check again the storageclass list.

```shell
kubectl get storageclass
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  26m

```

The `(default)` aside with gp2 indicates that gp2 is now the default storageclass.

## Install EBS CSI driver

Here is draft of script to use for install EBS CSI drivers required to bound PVCs correctly on AWS.
This is based on the official documentation from [here](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html).

First create the OIDC for the new cluster.

```shell
# se IODC provider
eksctl utils associate-iam-oidc-provider --cluster=$RYAX_CLUSTER_NAME --region=$RYAX_CLUSTER_REGION --approve
```

Then we need to create an iamserviceaccount for the addon.

```shell
# create IAM role, you can check this step on cloud formation, if this step fail
# you may have to change the role-name, eventhough role-name is global our
# tests show that we need to specify the region here
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster=$RYAX_CLUSTER_NAME \
  --region=$RYAX_CLUSTER_REGION \
  --role-name AmazonEKS_EBS_CSI_DriverRole_${RYAX_CLUSTER_NAME}_${RYAX_CLUSTER_REGION} \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve
```

Finally create the addon on your cluster.

```shell
eksctl create addon --name aws-ebs-csi-driver   --cluster=$RYAX_CLUSTER_NAME  --region=$RYAX_CLUSTER_REGION --service-account-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AmazonEKS_EBS_CSI_DriverRole_${RYAX_CLUSTER_NAME}_${RYAX_CLUSTER_REGION} --force
```

If everything went fine you should see the addon on the list retrieved with
the command below.

```shell
aws eks list-addons --cluster $RYAX_CLUSTER_NAME --region $RYAX_CLUSTER_REGION
```

Check also that the pods for ebs-csi-controller are running and ready.

```shell
kubectl get pods -n kube-system
```

Healthy output looks like below.

```shell
NAME                                 READY   STATUS    RESTARTS   AGE
...
ebs-csi-controller-b7596bb84-9m4xd   6/6     Running   0          15m
ebs-csi-controller-b7596bb84-r6vlg   6/6     Running   0          15m
ebs-csi-node-26spf                   3/3     Running   0          15m
ebs-csi-node-6767f                   3/3     Running   0          15m
```


## Enable autoscaler (recommended)

The autoscaler enable kubernetes to automatically spawn nodes and shut nodes down on-demand. Without autoscaler
kubernetes will not be able to create nodes when the pods require more resources and if nodes are unused for
a long period kubernetes will not be able to shut nodes down. So, in spite of optional, we strongly advise AWS users
to enable autoscaler to optimize platform usage.

This tutorial is heavily inspired by : https://devopscube.com/cluster-autoscaler/ (Check it for more parameters).

First check that the created managedNodeGroups have auto-scaling-groups associated with the tags
`k8s.io/cluster-autoscaler` and `k8s.io/<cluster-name>` correctly set.

```shell
aws autoscaling describe-auto-scaling-groups --region $RYAX_CLUSTER_REGION --query "AutoScalingGroups[*].Tags" | jq -r '.[].[] | "\(.Key) -> \(.Value) :::::::::> \(.ResourceId)"'
```

Expected output should be like below.

```shell
eks:cluster-name -> ryax-general-purpose-2 :::::::::> eks-ryax-exec-nodes-82cd1a57-f6a6-0476-7faf-b993cbe102e3
eks:nodegroup-name -> ryax-exec-nodes :::::::::> eks-ryax-exec-nodes-82cd1a57-f6a6-0476-7faf-b993cbe102e3
k8s.io/cluster-autoscaler/enabled -> true :::::::::> eks-ryax-exec-nodes-82cd1a57-f6a6-0476-7faf-b993cbe102e3
k8s.io/cluster-autoscaler/ryax-general-purpose-2 -> owned :::::::::> eks-ryax-exec-nodes-82cd1a57-f6a6-0476-7faf-b993cbe102e3
kubernetes.io/cluster/ryax-general-purpose-2 -> owned :::::::::> eks-ryax-exec-nodes-82cd1a57-f6a6-0476-7faf-b993cbe102e3
eks:cluster-name -> ryax-general-purpose-2 :::::::::> eks-ryax-infra-nodes-5ccd1a57-f73f-fb6a-4851-0ee94b177f6f
eks:nodegroup-name -> ryax-infra-nodes :::::::::> eks-ryax-infra-nodes-5ccd1a57-f73f-fb6a-4851-0ee94b177f6f
k8s.io/cluster-autoscaler/enabled -> true :::::::::> eks-ryax-infra-nodes-5ccd1a57-f73f-fb6a-4851-0ee94b177f6f
k8s.io/cluster-autoscaler/ryax-general-purpose-2 -> owned :::::::::> eks-ryax-infra-nodes-5ccd1a57-f73f-fb6a-4851-0ee94b177f6f
kubernetes.io/cluster/ryax-general-purpose-2 -> owned :::::::::> eks-ryax-infra-nodes-5ccd1a57-f73f-fb6a-4851-0ee94b177f6f
```

Create a cluster autoScaler policy configuration file.

```shell
cat <<EoF > autoscaler_policy_${RYAX_CLUSTER_NAME}_${RYAX_CLUSTER_REGION}.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EoF
```

Create the policy.

```shell
aws iam create-policy   \
  --policy-name autoscaler_policy_${RYAX_CLUSTER_NAME}_${RYAX_CLUSTER_REGION} \
  --policy-document file://autoscaler_policy_${RYAX_CLUSTER_NAME}_${RYAX_CLUSTER_REGION}.json
```

Save the policy id on an environment variable.

```shell
export POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='autoscaler_policy_"${RYAX_CLUSTER_NAME}_${RYAX_CLUSTER_REGION}"'].Arn" --output text)
echo $POLICY_ARN
```

Create an IAM Role configuration.

```shell
cat <<EoF > autoscaler_role_${RYAX_CLUSTER_NAME}_${RYAX_CLUSTER_REGION}.json
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "pods.eks.amazonaws.com"
        },
        "Action": [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
}
EoF
```

Then create the role.

```shell
aws iam create-role \
    --role-name  autoscaler_role_${RYAX_CLUSTER_NAME}_${RYAX_CLUSTER_REGION} \
    --assume-role-policy-document file://autoscaler_role_${RYAX_CLUSTER_NAME}_${RYAX_CLUSTER_REGION}.json
```

And finally attach the policy to the role.

```shell
aws iam attach-role-policy \
    --role-name autoscaler_role_${RYAX_CLUSTER_NAME}_${RYAX_CLUSTER_REGION} \
    --policy-arn $POLICY_ARN
```


Wait for the role and policy commands to finish and then run the
following to store the role in an environment variable.

```shell
export ROLE_ARN=$(aws iam get-role --role-name autoscaler_role_${RYAX_CLUSTER_NAME}_${RYAX_CLUSTER_REGION} --query "Role.Arn" --output text)
echo $ROLE_ARN
```

You should see something like below.

```shell
#arn:aws:iam::134197477825:role/autoscaler_role_<RYAX_CLUSTER_NAME>_<RYAX_CLUSTER_REGION>
arn:aws:iam::134197477825:role/autoscaler_role_ryax-demo_eu-north-1
```

Get the autoscaler deployment file from github.

```shell
wget https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

Edit the file to match image version of your cluster.

```shell
kubectl version
```

The output show the server version.

```shell
Client Version: v1.33.3
Kustomize Version: v5.6.0
Server Version: v1.34.1-eks-113cf36
```

We want to set the image version as `v1.34.1` removing the `-eks-113cf36` part.

You can do it with an editor or a simple sed command like below.

```shell
 sed -i 's/autoscaler:v.*/autoscaler:v1.34.1/g' cluster-autoscaler-autodiscover.yaml
```

Also change `--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/<YOUR CLUSTER NAME>.` to have the correct match your cluster name like below.

```shell
sed -i 's/<YOUR CLUSTER NAME>/'$RYAX_CLUSTER_NAME'/g' cluster-autoscaler-autodiscover.yaml
```

Now deploy the autoscaler.

```shell
kubectl apply -f cluster-autoscaler-autodiscover.yaml
```

Check the deployment is running and annotate it with the command below.

```shell
kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"
```

Finally, check we have addon `eks-pod-identity-agent` on our cluster.

```shell
aws eks list-addons --cluster-name $RYAX_CLUSTER_NAME --region $RYAX_CLUSTER_REGION
```

If not installed, you can install it with:

```shell
aws eks create-addon --cluster-name $RYAX_CLUSTER_NAME --region $RYAX_CLUSTER_REGION --addon-name eks-pod-identity-agent
```

Once the  addon is available use the following command to associate the pod of the autoscaler with the created role

```shell
eksctl create podidentityassociation \
  --cluster $RYAX_CLUSTER_NAME \
  --region $RYAX_CLUSTER_REGION \
  --namespace kube-system \
  --service-account-name cluster-autoscaler \
  --role-arn $ROLE_ARN
```

## Add GPU Node Groups

If you need a GPU nodegroup, you will have to add first a nodegroup with an instance that has gpu, you can check
a list of instance types that support CPU here https://instances.vantage.sh/.
One you know the instance type that matches your requirements for GPU hardware edit the cluster-config.yaml file
created on the first step. We need to add a nodegroup like the example below, the
taints are important because those taints guarantee only actions that require gpus will be deployed on GPU nodes.

**Useful reading**
* https://hackernoon.com/a-guide-on-how-to-use-gpu-nodes-in-amazon-eks
* https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: $RYAX_CLUSTER_NAME
  region: $RYAX_CLUSTER_REGION
  version: "1.34"
managedNodeGroups:
  - name: ryax-exec-nodes
    ...
  - name: ryax-infra-nodes
    ...
  # NEW node group
  - name: gpu-spot-l4-a10g-24gb
    instanceTypes:
    - g6.xlarge #	G6 GPU Extra Large 16 GiB, 4 vCPUs, 1 NVIDIA L4, VRAM 24GB, 250 GB NVMe SSD
    - g5.xlarge # G5 Machine Learning GPU Extra Large 16 GiB, 4 vCPUs, 1 NVIDIA A10G, VRAM 24GB, 250 GB NVMe SSD
    spot: true # get instances for a good price by accepting some probability of premption
    amiFamily: AmazonLinux2023
    minSize: 0
    maxSize: 6
    iam:
      withAddonPolicies:
        autoScaler: true
    labels:
      ryax.tech/nodepool: gpu-spot-l4-a10g-24gb
    taints:
    - key: ryax.tech/ryaxns-execs
      value: only
      effect: NoSchedule
    - key: sku
      value: gpu
      effect: NoSchedule
    tags:
      k8s.io/cluster-autoscaler/node-template/taint/ryax.tech/ryaxns-execs: "only:NoSchedule"
      k8s.io/cluster-autoscaler/node-template/label/ryax.tech/nodepool: gpu-spot-l4-a10g-24gb
      k8s.io/cluster-autoscaler/node-template/taint/sku: "gpu:NoSchedule"
```

Once you edit the cluster config file, `cluster-config.yaml`  and add a node pool for GPU with the  correct
taints and label you can trigger cloudFromation stacks with the command below (node that nodegroups that have already stacks
on cloudFormation will be ignored).


```shell
eksctl create nodegroup -f cluster-config-ryax-demo-main-site.yaml
```

Meanwhile the cloudFormation provisioning is happening you can go ahead and install the nvidia operator through helm.

```shell
helm repo add nvidia https://nvidia.github.io/gpu-operator
helm repo update
```

Now let's edit a values file to parametize the `nvidia/gpu-operator`. It is important to allow the nvidia operator deamonsets to run on
the gpu nodes by adding tolerations for the 2 added taints.

```shell
cat >nvidia-gpu-operator-values.yaml <<EOF
daemonsets:
  tolerations:
  - key: sku
    value: gpu
    effect: NoSchedule
  - key: ryax.tech/ryaxns-execs
    value: only
    effect: NoSchedule
# if you need to enable MIG check the full parameters list with
#  helm show values nvidia/gpu-operator
EOF
```

Now install the operator by using the configuration given.

```shell
helm upgrade --install -n kube-system gpu-operator nvidia/gpu-operator -f nvidia-gpu-operator-values.yaml
```
