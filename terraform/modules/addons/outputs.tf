output "argocd_namespace" {
  value = var.argocd_enabled ? var.argocd_namespace : null
}

output "argocd_release_status" {
  value = try(helm_release.argocd[0].status, null)
}

output "karpenter_namespace" {
  value = var.karpenter_enabled ? var.karpenter_namespace : null
}

output "karpenter_release_status" {
  value = try(helm_release.karpenter[0].status, null)
}

output "coredns_hosts_applied" {
  value = null_resource.coredns_hosts.id
}
