# Solace Agent Mesh Helm Quickstart
> :warning: This Helm chart is **not ready yet** for production use.
> We are actively developing and testing this chart. Expect breaking changes and incomplete functionality.
> Please check back later or follow the repository for updates.

## Prerequisite 
* Helm: Download Helm from https://helm.sh/docs/intro/install/
* Add this project to Helm repo
  ```sh
  helm repo add solace-agent-mesh https://solaceproducts.github.io/solace-agent-mesh-helm-quickstart/
  helm repo update
  ```

## Install Solace Agent Mesh

### Prepare and update Helm values
Sample values: https://github.com/SolaceProducts/solace-agent-mesh-helm-quickstart/tree/main/samples/values

### Install in your cluster
```
helm install my-first-deployment solace-agent-mesh/solace-agent-mesh --values <Your-values>
```
