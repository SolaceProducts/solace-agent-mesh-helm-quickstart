# Troubleshooting SAM Deployments

This guide provides solutions for common issues when deploying and running Solace Agent Mesh (SAM).

## Diagnostic Commands

**Note:** The commands below use `app.kubernetes.io/instance=agent-mesh` where `agent-mesh` is the Helm release name. Replace `agent-mesh` with your actual release name if different.

### Check Pod Status

```bash
kubectl get pods -l app.kubernetes.io/instance=agent-mesh
```

### View Pod Logs

```bash
kubectl logs -l app.kubernetes.io/instance=agent-mesh --tail=100 -f
```

### Check ConfigMaps

```bash
kubectl get configmaps -l app.kubernetes.io/instance=agent-mesh
```

### Check Secrets

```bash
kubectl get secrets -l app.kubernetes.io/instance=agent-mesh
```

### Verify Service

```bash
kubectl get service -l app.kubernetes.io/instance=agent-mesh
```

## Common Issues

### Pod fails to start

- Check that the image is accessible
- Verify resource limits are sufficient
- Review pod events: `kubectl describe pod <pod-name>`

### Cannot connect to Solace broker

- Verify `solaceBroker.url` is correct and reachable
- Check credentials in `solaceBroker.username` and `solaceBroker.password`
- Ensure the VPN name is correct

### TLS issues

- Verify certificate and key are properly formatted
- Check certificate expiration
- Ensure certificate matches the hostname

### Database connection issues

- Verify database URLs are correct
- Check database credentials
- Ensure databases exist and are accessible from the cluster

## Getting Help

For issues, questions, or contributions, please open an issue in [GitHub Issues](../../../issues).
