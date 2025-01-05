# k8s-local-cluster-playground


## Prerequisite
- install `kind` using this instruction below
  ```sh
    wget https://github.com/kubernetes-sigs/kind/releases/download/v0.26.0/kind-darwin-arm64
  ```

  ```sh
    sudo mv kind-darwin-arm64 /usr/local/bin/kind
  ```

  ```sh
    sudo chmod +x /usr/local/bin/kind
  ```

  then try to run `kind version` command



## Setup step

<b>Local Cluster Setup:</b>
  
```sh
cat <<EOF > cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
```
then, create the cluster by run the command below

```sh
kind create cluster --config=cluster.yaml
```

<b>Install Helm:</b>
  

```sh
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

<b>Install Argo CD on the cluster using Helm as follows:</b>

```sh
helm repo add argo https://argoproj.github.io/argo-helm
kubectl create namespace argocd
helm install argocd -n argocd argo/argo-cd

```

<b>Get the administrator password (or just copy the command from the Helm output):</b>

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

<b>Create a port-forward to access the UI of the server by running:</b>


```sh
kubectl port-forward service/argocd-server -n argocd 8080:443
```

<b>Return back to the terminal and install the Nginx ingress controller by running the following command:</b>
```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
```

<b>Retun the Helm command enabling Ingress and the other required options:</b>

```sh
helm upgrade argocd --set configs.params."server\.insecure"=true --set server.ingress.enabled=true  --set server.ingress.ingressClassName="nginx" -n argocd argo/argo-cd
```

### Add the target repository for argoCD

```sh
argocd repo add $REPO_URL --username $USER_NAME --password $PASSWORD
```


