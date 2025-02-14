# rock8s

> a universal kubernetes cluster

![](./rock8t.jpg)

Rock8s is a universal cloud-agnostic Kubernetes cluster deployment solution using Terraform and Kubespray. VMK allows you to deploy and manage Kubernetes clusters on any platform where you have SSH access to virtual machines.

## Features

- Cloud-agnostic deployment
- Dynamic node management (add/remove nodes)
- Automated cluster backup and restore
- Comprehensive monitoring setup
- Multi-platform support
- Secure deployment practices
- Idempotent operations

## Prerequisites

- Terraform >= 1.0.0
- Python 3.x
- SSH access to target nodes
- Admin user with sudo privileges on target nodes
- SSH key pair for node access

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/yourusername/vmk.git
cd vmk
```

2. Copy the example configuration:
```bash
cp example.tf main.tf
```

3. Set your node IP addresses:
```bash
# For a single master and two workers
export MASTER_IPS="192.168.1.10"
export WORKER_IPS="192.168.1.11 192.168.1.12"
```

4. Initialize Terraform:
```bash
make init
```

5. Deploy the cluster:
```bash
make apply
```

## Configuration

### Node Configuration

Simply provide space-separated lists of IP addresses for master and worker nodes:

```bash
# Single master
export MASTER_IPS="192.168.1.10"

# Multiple workers
export WORKER_IPS="192.168.1.11 192.168.1.12 192.168.1.13"
```

The script will automatically generate appropriate hostnames and configurations.

### SSH Configuration

```bash
# Optional: Set custom SSH key path (defaults to ~/.ssh/id_rsa)
export SSH_PRIVATE_KEY="/path/to/your/key"

# Optional: Set custom SSH user (defaults to admin)
export USER="your-ssh-user"
```

### Kubernetes Configuration

The default configuration in example.tf:

```hcl
kubernetes_version = "1.28.0"        # Kubernetes version
network_plugin    = "calico"         # CNI plugin
container_runtime = "containerd"      # Container runtime
pod_network_cidr  = "10.244.0.0/16"  # Pod network CIDR
service_network_cidr = "10.96.0.0/12" # Service network CIDR
```

## Node Management

### Adding Nodes

To add new worker nodes:

```bash
# Add the new node IPs to your worker list
export WORKER_IPS="192.168.1.11 192.168.1.12 192.168.1.13"
make apply
```

### Removing Nodes

To remove nodes:

```bash
# Update the IP list, excluding the nodes to remove
export WORKER_IPS="192.168.1.11 192.168.1.12"
make apply
```

## Cluster Management

### Backup

To create a backup of the cluster state:

```bash
make backup
```

Backups are stored in `/opt/vmk/backups/` with timestamps.

### Restore

To restore from a backup:

```bash
make restore BACKUP=/path/to/backup.tar.gz
```

### Validation

To validate cluster health:

```bash
make validate
```

### Cleanup

To clean up local Terraform files:

```bash
make clean
```

## Monitoring

The cluster comes with a pre-configured monitoring stack:

- Prometheus for metrics collection
- Grafana for visualization
- AlertManager for alerting
- Custom dashboards for cluster monitoring

Access Grafana:
1. Get the admin password:
```bash
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode
```

2. Port-forward the Grafana service:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

3. Access the dashboard at `http://localhost:3000`

## Security Considerations

1. Use secure SSH key pairs
2. Use proper network segmentation
3. Follow the principle of least privilege
4. Regularly update Kubernetes and dependencies
5. Implement network policies
6. Enable audit logging
7. Use RBAC for access control

## Troubleshooting

1. Check SSH connectivity to nodes
2. Verify prerequisites are met
3. Check Kubespray logs in case of deployment issues
4. Verify network connectivity between nodes
5. Ensure sufficient resources on nodes
6. Check system logs on nodes
7. Verify firewall rules

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License

## Support

For support, please open an issue in the GitHub repository.
