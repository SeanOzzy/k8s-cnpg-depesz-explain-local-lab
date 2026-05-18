# Test deployment

## Bootstrap the kind env
```
$ make bootstrap 
INFO: Creating kind cluster 'explain-cluster'...
Creating cluster "explain-cluster" ...
 ✓ Ensuring node image (kindest/node:v1.30.0) 🖼
 ✓ Preparing nodes 📦 📦 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
 ✓ Joining worker nodes 🚜 
 ✓ Waiting ≤ 1m30s for control-plane = Ready ⏳ 
 • Ready after 0s 💚
Set kubectl context to "kind-explain-cluster"
You can now use your cluster with:

kubectl cluster-info --context kind-explain-cluster

Have a nice day! 👋
kubectl config use-context kind-explain-cluster
Switched to context "kind-explain-cluster".
kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.23/releases/cnpg-1.23.1.yaml
namespace/cnpg-system serverside-applied
customresourcedefinition.apiextensions.k8s.io/backups.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/clusterimagecatalogs.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/clusters.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/imagecatalogs.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/poolers.postgresql.cnpg.io serverside-applied
customresourcedefinition.apiextensions.k8s.io/scheduledbackups.postgresql.cnpg.io serverside-applied
serviceaccount/cnpg-manager serverside-applied
clusterrole.rbac.authorization.k8s.io/cnpg-manager serverside-applied
clusterrolebinding.rbac.authorization.k8s.io/cnpg-manager-rolebinding serverside-applied
configmap/cnpg-default-monitoring serverside-applied
service/cnpg-webhook-service serverside-applied
deployment.apps/cnpg-controller-manager serverside-applied
mutatingwebhookconfiguration.admissionregistration.k8s.io/cnpg-mutating-webhook-configuration serverside-applied
validatingwebhookconfiguration.admissionregistration.k8s.io/cnpg-validating-webhook-configuration serverside-applied
kubectl rollout status deployment/cnpg-controller-manager \
  -n cnpg-system --timeout=180s
Waiting for deployment "cnpg-controller-manager" rollout to finish: 0 of 1 updated replicas are available...
deployment "cnpg-controller-manager" successfully rolled out
CNPG v1.23.1 installed.

INFO: Bootstrap complete.
INFO: Next steps run: make build && make load && make deploy
```

## Fetch the source for the app
```
$ ./scripts/fetch-upstream.sh 
Cloning https://gitlab.com/depesz/explain.depesz.com.git (ref: master)...
Cloning into '/home/sean/workplace/k8s-cnpg-depesz-explain-local-lab/scripts/../app/docker/src/explain.depesz.com'...
remote: Enumerating objects: 1781, done.
remote: Counting objects: 100% (716/716), done.
remote: Compressing objects: 100% (336/336), done.
remote: Total 1781 (delta 375), reused 705 (delta 372), pack-reused 1065 (from 1)
Receiving objects: 100% (1781/1781), 868.45 KiB | 4.88 MiB/s, done.
Resolving deltas: 100% (868/868), done.

Source ready at: /home/sean/workplace/k8s-cnpg-depesz-explain-local-lab/scripts/../app/docker/src/explain.depesz.com
Commit          : ddcb0e4

Review the upstream LICENSE before publishing a derived image:
  /home/sean/workplace/k8s-cnpg-depesz-explain-local-lab/scripts/../app/docker/src/explain.depesz.com/LICENSE

Next: make build
```

## Build the image
```
$ make build
INFO: Building app image from local source...
docker build -t pg-explain-app:latest ./app/docker
[+] Building 0.3s (19/19) FINISHED                                                                                                             docker:default
 => [internal] load build definition from Dockerfile                                                                                                     0.0s
 => => transferring dockerfile: 3.18kB                                                                                                                   0.0s
 => [internal] load metadata for docker.io/library/perl:5.38-slim                                                                                        0.0s
 => [internal] load .dockerignore                                                                                                                        0.0s
 => => transferring context: 167B                                                                                                                        0.0s
 => [builder 1/7] FROM docker.io/library/perl:5.38-slim                                                                                                  0.0s
 => [internal] load build context                                                                                                                        0.2s
 => => transferring context: 1.44MB                                                                                                                      0.2s
 => CACHED [stage-1 2/9] RUN apt-get update && apt-get install -y --no-install-recommends     libpq5     ca-certificates     postgresql-client  && rm -  0.0s
 => CACHED [builder 2/7] RUN apt-get update  && apt-get install -y --no-install-recommends     curl     cpanminus     libpq-dev     gcc     make     ca  0.0s
 => CACHED [builder 3/7] RUN set -eux;     curl -fsSL       -o "pgFormatter-v5.9.tar.gz"       "https://github.com/darold/pgFormatter/archive/refs/tags  0.0s
 => CACHED [builder 4/7] COPY src/explain.depesz.com/cpanfile /tmp/app/cpanfile                                                                          0.0s
 => CACHED [builder 5/7] WORKDIR /tmp/app                                                                                                                0.0s
 => CACHED [builder 6/7] RUN cpanm --notest --installdeps .  && cpanm --notest LWP::Simple                                                               0.0s
 => CACHED [stage-1 3/9] COPY --from=builder /usr/local/lib/perl5 /usr/local/lib/perl5                                                                   0.0s
 => CACHED [stage-1 4/9] COPY --from=builder /usr/local/bin /usr/local/bin                                                                               0.0s
 => CACHED [stage-1 5/9] COPY src/explain.depesz.com/ /app/                                                                                              0.0s
 => CACHED [stage-1 6/9] COPY entrypoint.sh /usr/local/bin/entrypoint.sh                                                                                 0.0s
 => CACHED [stage-1 7/9] RUN chmod +x /usr/local/bin/entrypoint.sh                                                                                       0.0s
 => CACHED [stage-1 8/9] WORKDIR /app                                                                                                                    0.0s
 => CACHED [stage-1 9/9] RUN groupadd -r appuser && useradd -r -g appuser appuser  && chown -R appuser:appuser /app                                      0.0s
 => exporting to image                                                                                                                                   0.0s
 => => exporting layers                                                                                                                                  0.0s
 => => writing image sha256:e3c2a2528a0746d278b71ec42b355790032e4b2389e30c91af227642dc670a37                                                             0.0s
 => => naming to docker.io/library/pg-explain-app:latest                                                                                                 0.0s

View build details: docker-desktop://dashboard/build/default/default/mif0r6fsnxx2rkqxtg7bzv7zg

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview 
INFO: Built image: pg-explain-app:latest
INFO: You can view the image details using: docker images pg-explain-app:latest
INFO: Next steps run: make load && make deploy
```

## Load the image into the kind env
```
$ make load
kind load docker-image pg-explain-app:latest --name explain-cluster
Image: "pg-explain-app:latest" with ID "sha256:e3c2a2528a0746d278b71ec42b355790032e4b2389e30c91af227642dc670a37" not yet present on node "explain-cluster-worker", loading...
Image: "pg-explain-app:latest" with ID "sha256:e3c2a2528a0746d278b71ec42b355790032e4b2389e30c91af227642dc670a37" not yet present on node "explain-cluster-worker2", loading...
Image: "pg-explain-app:latest" with ID "sha256:e3c2a2528a0746d278b71ec42b355790032e4b2389e30c91af227642dc670a37" not yet present on node "explain-cluster-control-plane", loading...
```

## Deploy the services, pods and app
```
$ make deploy ENV=dev
Deploying overlay: dev
kustomize build k8s/overlays/dev | kubectl apply -f -
namespace/explain created
secret/pg-explain-app-secret created
secret/pg-explain-superuser-secret created
service/explain-app created
deployment.apps/explain-app created
cluster.postgresql.cnpg.io/pg-explain created
./scripts/wait-for-cluster.sh
[wait-cluster] Waiting for CNPG Cluster 'pg-explain' in namespace 'explain'...
cluster.postgresql.cnpg.io/pg-explain condition met
[wait-cluster] Cluster is Ready. Primary: pg-explain-1
kubectl rollout status deployment/explain-app -n explain --timeout=600s
deployment "explain-app" successfully rolled out
```

## Forward the port
```
$ make port-forward
Forwarding explain-app → http://localhost:8080  (Ctrl+C to stop)
kubectl port-forward svc/explain-app 8080:80 -n explain
Forwarding from [::1]:8080 -> 3000
```

## Test failover
```
$ date +%FT%H%M%S; make test-failover ; date +%FT%H%M%S
2026-05-18T213832
./scripts/test-failover.sh
[failover] === Before failover ===
NAME           READY   STATUS    RESTARTS   AGE   IP           NODE                      NOMINATED NODE   READINESS GATES   LABELS
pg-explain-1   1/1     Running   0          20m   10.244.2.5   explain-cluster-worker2   <none>           <none>            cnpg.io/cluster=pg-explain,cnpg.io/instanceName=pg-explain-1,cnpg.io/instanceRole=primary,cnpg.io/podRole=instance,role=primary
pg-explain-2   1/1     Running   0          19m   10.244.1.5   explain-cluster-worker    <none>           <none>            cnpg.io/cluster=pg-explain,cnpg.io/instanceName=pg-explain-2,cnpg.io/instanceRole=replica,cnpg.io/podRole=instance,role=replica

[failover] Current primary: pg-explain-1
[failover] Deleting it now to trigger CNPG failover...

pod "pg-explain-1" deleted from explain namespace
[failover] === Waiting for cluster to recover (up to 5 minutes) ===
[failover] Watch what happens: in another terminal run:
[failover]   kubectl get pods -n explain -w

[failover] Waiting... currentPrimary=pg-explain-1 readyInstances=1

[failover] === After failover ===
NAME           READY   STATUS    RESTARTS   AGE   IP           NODE                      NOMINATED NODE   READINESS GATES
pg-explain-1   0/1     Running   0          5s    10.244.2.6   explain-cluster-worker2   <none>           <none>
pg-explain-2   1/1     Running   0          19m   10.244.1.5   explain-cluster-worker    <none>           <none>

[failover] Failover complete.
[failover]   Old primary : pg-explain-1
[failover]   New primary : pg-explain-2
[failover] 
[failover] The pg-explain-rw Service now points to pg-explain-2.
[failover] The app experienced a brief connection interruption and nothing else.
2026-05-18T213839
```

## Display the k8s nodes
```
$ kubectl get nodes -n explain
NAME                            STATUS   ROLES           AGE    VERSION
explain-cluster-control-plane   Ready    control-plane   107s   v1.30.0
explain-cluster-worker          Ready    <none>          86s    v1.30.0
explain-cluster-worker2         Ready    <none>          85s    v1.30.0
```
## Display the running kind docker containers 
```
$ docker ps
CONTAINER ID   IMAGE                  COMMAND                  CREATED         STATUS         PORTS                                                                                                  NAMES
e90b29c59173   kindest/node:v1.30.0   "/usr/local/bin/entr…"   2 minutes ago   Up 2 minutes                                                                                                          explain-cluster-worker
958f682c660f   kindest/node:v1.30.0   "/usr/local/bin/entr…"   2 minutes ago   Up 2 minutes                                                                                                          explain-cluster-worker2
1f47f62c89e2   kindest/node:v1.30.0   "/usr/local/bin/entr…"   2 minutes ago   Up 2 minutes   127.0.0.1:33865->6443/tcp, 0.0.0.0:3000->30030/tcp, 0.0.0.0:8080->30080/tcp, 0.0.0.0:9090->30090/tcp   explain-cluster-control-plane
```
## Display the image details
```
$ docker images pg-explain-app
REPOSITORY       TAG       IMAGE ID       CREATED       SIZE
pg-explain-app   latest    e3c2a2528a07   2 hours ago   351MB
```

## Display the persistent volume information
```
$ kubectl get persistentvolumeclaims -n explain
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pg-explain-1   Bound    pvc-97331d27-3a4c-4596-934b-fff2e0945c0e   1Gi        RWO            standard       <unset>                 6m25s
pg-explain-2   Bound    pvc-04844acc-037e-435f-9817-e34136a7e6b8   1Gi        RWO            standard       <unset>                 5m40s

$ kubectl get persistentvolumes -n explain
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-04844acc-037e-435f-9817-e34136a7e6b8   1Gi        RWO            Delete           Bound    explain/pg-explain-2   standard       <unset>                          5m44s
pvc-97331d27-3a4c-4596-934b-fff2e0945c0e   1Gi        RWO            Delete           Bound    explain/pg-explain-1   standard       <unset>                          6m29s

$ kubectl get storageclass -n explain
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  7m35s
```

## Display the cluster, pods and service info
```
$ kubectl get cluster -n explain
NAME         AGE     INSTANCES   READY   STATUS                     PRIMARY
pg-explain   2m51s   2           2       Cluster in healthy state   pg-explain-1

$ kubectl get pods -n explain
NAME                         READY   STATUS    RESTARTS   AGE
explain-app-9fc699dd-smcrb   1/1     Running   0          3m20s
pg-explain-1                 1/1     Running   0          2m45s
pg-explain-2                 1/1     Running   0          91s

$ kubectl get svc -n explain
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
explain-app     NodePort    10.96.106.70    <none>        80:30161/TCP   3m46s
pg-explain-r    ClusterIP   10.96.14.195    <none>        5432/TCP       3m46s
pg-explain-ro   ClusterIP   10.96.177.199   <none>        5432/TCP       3m46s
pg-explain-rw   ClusterIP   10.96.219.79    <none>        5432/TCP       3m46s

$ kubectl get deployments -n explain
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
explain-app   1/1     1            1           8m2s

```
## Display the events

```
$ kubectl get events -n explain
LAST SEEN   TYPE     REASON                        OBJECT                                   MESSAGE
10m         Normal   Scheduled                     pod/explain-app-9fc699dd-smcrb           Successfully assigned explain/explain-app-9fc699dd-smcrb to explain-cluster-worker2
10m         Normal   Pulling                       pod/explain-app-9fc699dd-smcrb           Pulling image "postgres:16-alpine"
10m         Normal   Pulled                        pod/explain-app-9fc699dd-smcrb           Successfully pulled image "postgres:16-alpine" in 8.57s (8.57s including waiting). Image size: 110036633 bytes.
10m         Normal   Created                       pod/explain-app-9fc699dd-smcrb           Created container wait-for-postgres
10m         Normal   Started                       pod/explain-app-9fc699dd-smcrb           Started container wait-for-postgres
9m26s       Normal   Pulled                        pod/explain-app-9fc699dd-smcrb           Container image "pg-explain-app:latest" already present on machine
9m26s       Normal   Created                       pod/explain-app-9fc699dd-smcrb           Created container explain-app
9m26s       Normal   Started                       pod/explain-app-9fc699dd-smcrb           Started container explain-app
10m         Normal   SuccessfulCreate              replicaset/explain-app-9fc699dd          Created pod: explain-app-9fc699dd-smcrb
10m         Normal   ScalingReplicaSet             deployment/explain-app                   Scaled up replica set explain-app-9fc699dd to 1
10m         Normal   Scheduled                     pod/pg-explain-1-initdb-vjssq            Successfully assigned explain/pg-explain-1-initdb-vjssq to explain-cluster-worker2
10m         Normal   Pulling                       pod/pg-explain-1-initdb-vjssq            Pulling image "ghcr.io/cloudnative-pg/cloudnative-pg:1.23.1"
10m         Normal   Pulled                        pod/pg-explain-1-initdb-vjssq            Successfully pulled image "ghcr.io/cloudnative-pg/cloudnative-pg:1.23.1" in 6.459s (10.63s including waiting). Image size: 31751056 bytes.
10m         Normal   Created                       pod/pg-explain-1-initdb-vjssq            Created container bootstrap-controller
10m         Normal   Started                       pod/pg-explain-1-initdb-vjssq            Started container bootstrap-controller
9m59s       Normal   Pulling                       pod/pg-explain-1-initdb-vjssq            Pulling image "ghcr.io/cloudnative-pg/postgresql:16.2"
9m45s       Normal   Pulled                        pod/pg-explain-1-initdb-vjssq            Successfully pulled image "ghcr.io/cloudnative-pg/postgresql:16.2" in 13.529s (13.529s including waiting). Image size: 216081484 bytes.
9m45s       Normal   Created                       pod/pg-explain-1-initdb-vjssq            Created container initdb
9m45s       Normal   Started                       pod/pg-explain-1-initdb-vjssq            Started container initdb
10m         Normal   SuccessfulCreate              job/pg-explain-1-initdb                  Created pod: pg-explain-1-initdb-vjssq
9m41s       Normal   Completed                     job/pg-explain-1-initdb                  Job completed
10m         Normal   WaitForFirstConsumer          persistentvolumeclaim/pg-explain-1       waiting for first consumer to be created before binding
10m         Normal   ExternalProvisioning          persistentvolumeclaim/pg-explain-1       Waiting for a volume to be created either by the external provisioner 'rancher.io/local-path' or manually by the system administrator. If volume creation is delayed, please verify that the provisioner is running and correctly registered.
10m         Normal   Provisioning                  persistentvolumeclaim/pg-explain-1       External provisioner is provisioning volume for claim "explain/pg-explain-1"
10m         Normal   ProvisioningSucceeded         persistentvolumeclaim/pg-explain-1       Successfully provisioned volume pvc-97331d27-3a4c-4596-934b-fff2e0945c0e
9m40s       Normal   Scheduled                     pod/pg-explain-1                         Successfully assigned explain/pg-explain-1 to explain-cluster-worker2
9m40s       Normal   Pulled                        pod/pg-explain-1                         Container image "ghcr.io/cloudnative-pg/cloudnative-pg:1.23.1" already present on machine
9m40s       Normal   Created                       pod/pg-explain-1                         Created container bootstrap-controller
9m40s       Normal   Started                       pod/pg-explain-1                         Started container bootstrap-controller
9m39s       Normal   Pulled                        pod/pg-explain-1                         Container image "ghcr.io/cloudnative-pg/postgresql:16.2" already present on machine
9m39s       Normal   Created                       pod/pg-explain-1                         Created container postgres
9m39s       Normal   Started                       pod/pg-explain-1                         Started container postgres
9m26s       Normal   Scheduled                     pod/pg-explain-2-join-qt7hc              Successfully assigned explain/pg-explain-2-join-qt7hc to explain-cluster-worker
9m25s       Normal   Pulled                        pod/pg-explain-2-join-qt7hc              Container image "ghcr.io/cloudnative-pg/cloudnative-pg:1.23.1" already present on machine
9m25s       Normal   Created                       pod/pg-explain-2-join-qt7hc              Created container bootstrap-controller
9m25s       Normal   Started                       pod/pg-explain-2-join-qt7hc              Started container bootstrap-controller
9m25s       Normal   Pulling                       pod/pg-explain-2-join-qt7hc              Pulling image "ghcr.io/cloudnative-pg/postgresql:16.2"
9m15s       Normal   Pulled                        pod/pg-explain-2-join-qt7hc              Successfully pulled image "ghcr.io/cloudnative-pg/postgresql:16.2" in 9.934s (9.934s including waiting). Image size: 216081484 bytes.
9m15s       Normal   Created                       pod/pg-explain-2-join-qt7hc              Created container join
9m15s       Normal   Started                       pod/pg-explain-2-join-qt7hc              Started container join
9m30s       Normal   SuccessfulCreate              job/pg-explain-2-join                    Created pod: pg-explain-2-join-qt7hc
8m26s       Normal   Completed                     job/pg-explain-2-join                    Job completed
9m30s       Normal   WaitForFirstConsumer          persistentvolumeclaim/pg-explain-2       waiting for first consumer to be created before binding
9m27s       Normal   ExternalProvisioning          persistentvolumeclaim/pg-explain-2       Waiting for a volume to be created either by the external provisioner 'rancher.io/local-path' or manually by the system administrator. If volume creation is delayed, please verify that the provisioner is running and correctly registered.
9m30s       Normal   Provisioning                  persistentvolumeclaim/pg-explain-2       External provisioner is provisioning volume for claim "explain/pg-explain-2"
9m27s       Normal   ProvisioningSucceeded         persistentvolumeclaim/pg-explain-2       Successfully provisioned volume pvc-04844acc-037e-435f-9817-e34136a7e6b8
8m26s       Normal   Scheduled                     pod/pg-explain-2                         Successfully assigned explain/pg-explain-2 to explain-cluster-worker
8m25s       Normal   Pulled                        pod/pg-explain-2                         Container image "ghcr.io/cloudnative-pg/cloudnative-pg:1.23.1" already present on machine
8m25s       Normal   Created                       pod/pg-explain-2                         Created container bootstrap-controller
8m25s       Normal   Started                       pod/pg-explain-2                         Started container bootstrap-controller
8m25s       Normal   Pulled                        pod/pg-explain-2                         Container image "ghcr.io/cloudnative-pg/postgresql:16.2" already present on machine
8m25s       Normal   Created                       pod/pg-explain-2                         Created container postgres
8m25s       Normal   Started                       pod/pg-explain-2                         Started container postgres
10m         Normal   NoPods                        poddisruptionbudget/pg-explain-primary   No matching pods found
10m         Normal   CreatingPodDisruptionBudget   cluster/pg-explain                       Creating PodDisruptionBudget pg-explain-primary
10m         Normal   CreatingServiceAccount        cluster/pg-explain                       Creating ServiceAccount
10m         Normal   CreatingRole                  cluster/pg-explain                       Creating Cluster Role
10m         Normal   CreatingInstance              cluster/pg-explain                       Primary instance (initdb)
9m30s       Normal   CreatingInstance              cluster/pg-explain                       Creating instance pg-explain-2
```
