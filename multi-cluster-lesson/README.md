## Multi-Cluster Setup

<b> Main Components </b>
- 2 k8s cluters
- a reverse proxy (for balacing the incoming traffic)

### This lab assumes that you have two other Kubernetes clusters on two different machines + a load balancer on a third one. Please replace the IP addresses as appropriate

The `cluster.yaml` for the clusters should look something like this (so that the API server is reachable from outside the cluster):

   ```yaml
   kind: Cluster
   apiVersion: kind.x-k8s.io/v1alpha4
   networking:
     apiServerAddress: "192.168.1.11" # Where this should be the external IP address of the virtual machine
     apiServerPort: 6443
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
   ```

Create a new directory inside `multi-cluster-lesson` :

   ````bash
   mkdir dummypageapp
   ````

Create a new file inside the directory called `workload.yaml` and add the following:

   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: http-server-content
   data:
     index.html: |
       <!DOCTYPE html>
       <html lang="en">
       <head>
           <meta charset="UTF-8">
           <meta name="viewport" content="width=device-width, initial-scale=1.0">
           <title>Dummy Content</title>
       </head>
       <body>
           <h1>Welcome to the Dummy HTTP Server!</h1>
           <p>This is some dummy content.</p>
       </body>
       </html>
   
   ---
   
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: http-server
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: http-server
     template:
       metadata:
         labels:
           app: http-server
       spec:
         containers:
         - name: nginx
           image: nginx:1.21
           ports:
           - containerPort: 80
           volumeMounts:
           - name: html-content
             mountPath: /usr/share/nginx/html
         volumes:
         - name: html-content
           configMap:
             name: http-server-content
   
   ---
   
   apiVersion: v1
   kind: Service
   metadata:
     name: http-server
   spec:
     selector:
       app: http-server
     ports:
       - protocol: TCP
         port: 80
         targetPort: 80
     type: ClusterIP
   
   ---
   
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: http-server
     annotations:
       kubernetes.io/ingress.class: "nginx"
   spec:
     rules:
     - http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: http-server
               port:
                 number: 80
   ```

Save the file.

Login to Argo CD using the command line as follows:

   ```bash
   argocd login --insecure
   #username: admin
   #password: your password
   ```

Add the primary and secondary clusters using their kubeconfig files as follows:

   ```bash
   argocd cluster add kind-primary --name primary --kubeconfig ./primary
   argocd cluster add kind-secondary --name secondary --kubeconfig ./secondary
   ```

In the `argocd` directory, we create a new file called `onepageserver-primary.yaml` with the following contents:

   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: onepageserver-primary
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: 'https://gitlab.com/[username]/samplegitopsapp.git'
       path: onepageserver
       targetRevision: main
     destination:
       server: 'https://192.168.2.35:6443'
       namespace: default
     syncPolicy:
       automated:
         selfHeal: true
         prune: true
   ```

We duplicate the file `cp dummypageserver-primary.yaml dummypageserver-secondary.yaml`:

   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: dummypageserver-secondary
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: 'https://gitlab.com/[username]/k8s-local-cluster-playground.git'
       path: dummypageserver
       targetRevision: main
     destination:
       server: 'https://192.168.2.36:6443'
       namespace: default
     syncPolicy:
       automated:
         selfHeal: true
         prune: true
   ```

Push the changes to the remote repository:

    ```bash
    git add -A
    git commit -m "feat: Adds the dummy page server to the primary and secondary clusters"
    git push
    ```

Go to the UI of Argo CD and refresh the `argocd` application.

Go to each server and view the page including the load balancer: 192.168.1.11(primay), 192.168.1.22(secondary), 192.168.1.33(load balancer).

```ascii
                                           ┌─────────────────┐  
                                           │                 │  
                                           │                 │  
                                      ┌───►│   192.168.1.11  │  
                                      │    │                 │  
                                      │    │ Primary Cluster │  
┌──────────────────┐                  │    │                 │  
│                  │                  │    └─────────────────┘  
│                  ├──────────────────┘                         
│   192.168.1.33   │                                            
│                  ├──────────────────┐                         
│   Load Balancer  │                  │                         
│                  │                  │    ┌───────────────────┐
└──────────────────┘                  │    │                   │
                                      │    │                   │
                                      │    │   192.168.1.22    │
                                      └───►│                   │
                                           │ Secondary Cluster │
                                           │                   │
                                           └───────────────────┘

```