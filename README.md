# Solace Agent Mesh Helm Quickstart


## Install Solace Agent Mesh

```sh
helm repo add solace-agent-mesh https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/
helm repo update
helm install my-first-deployment solace-agent-mesh/solace-agent-mesh --values <Your-values>
```