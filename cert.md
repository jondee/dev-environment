# RKE2 Certificate Rotation Process
To rotate certificates on an RKE2 cluster, you'll need to follow a specific process. RKE2 (Rancher Kubernetes Engine 2) provides commands to handle certificate rotation safely.
## Basic Certificate Rotation
For a standard certificate rotation on all RKE2 cluster nodes:
1. **On the server (control plane) nodes**:
   ```bash
   rke2 certificate rotate
   ```
2. **Verify the rotation**:
   ```bash
   kubectl get nodes
   ```
   The nodes should remain in Ready status after the rotation.
3. **Check certificate expiration** (optional):
   ```bash
   kubeadm certs check-expiration
   ```
## More Detailed Approach
For a more controlled rotation, you should:
1. **Backup your cluster first**:
   ```bash
   cp -r /var/lib/rancher/rke2/server/tls /var/lib/rancher/rke2/server/tls.bak
   ```
2. **Rotate certificates on the first server node**:
   ```bash
   rke2 certificate rotate
   ```
3. **Restart the RKE2 service**:
   ```bash
   systemctl restart rke2-server
   ```
4. **Wait for the node to be Ready again**:
   ```bash
   kubectl get nodes -w
   ```
5. **Proceed to the next server node** and repeat steps 2-4.
6. **Finally, rotate certificates on worker nodes** (if applicable):
   ```bash
   rke2 certificate rotate
   systemctl restart rke2-agent
   ```
## Important Considerations
- Certificate rotation causes temporary API server unavailability
- Perform this during a maintenance window
- Ensure you have cluster access through an alternative path during rotation
- For production clusters, consider rotating one node at a time
- Some workloads might need to reconnect after certificate changes
