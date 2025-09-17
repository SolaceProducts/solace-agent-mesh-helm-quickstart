# Solace Agent Mesh Helm Quickstart
> :warning: This Helm chart is **not ready yet** for production use.
> We are actively developing and testing this chart. Expect breaking changes and incomplete functionality.
> Please check back later or follow the repository for updates.

## Install Solace Agent Mesh

```sh
helm repo add solace-agent-mesh https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/
helm repo update
helm install my-first-deployment solace-agent-mesh/solace-agent-mesh --values <Your-values>
```
