# O provider aws_msk_cluster depende de DescribeClusterV2, que o MiniStack não
# implementa (só /v1/clusters). Por isso o cluster é criado via aws cli.
resource "null_resource" "create_cluster" {
  triggers = {
    cluster_name  = var.cluster_name
    kafka_version = var.kafka_version
    instance_type = var.instance_type
    endpoint      = var.endpoint
    region        = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=${self.triggers.region}
      aws --endpoint-url "${self.triggers.endpoint}" kafka create-cluster \
        --cluster-name "${self.triggers.cluster_name}" \
        --kafka-version "${self.triggers.kafka_version}" \
        --number-of-broker-nodes 1 \
        --broker-node-group-info "InstanceType=${self.triggers.instance_type},ClientSubnets=${join(",", var.subnet_ids)}" \
        >/dev/null || true
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=${self.triggers.region}
      arn=$(aws --endpoint-url "${self.triggers.endpoint}" kafka list-clusters --output json 2>/dev/null \
        | python3 -c "import json,sys; d=json.load(sys.stdin); print(next((c['ClusterArn'] for c in d.get('ClusterInfoList',[]) if c.get('ClusterName')=='${self.triggers.cluster_name}'), ''))")
      if [ -n "$arn" ]; then
        aws --endpoint-url "${self.triggers.endpoint}" kafka delete-cluster --cluster-arn "$arn" >/dev/null || true
      fi
    EOT
  }
}
