locals {
  # k3s release tag: accept plain semver or tagged release
  k3s_release = can(regex("\\+k3s", var.k8s_version)) ? var.k8s_version : "${var.k8s_version}+k3s1"

  # Docker/container socket path per runtime (on the remote host)
  docker_socket = {
    k3s      = "/var/run/docker.sock"
    colima   = "/var/run/docker.sock"
    podman   = "/run/podman/podman.sock"
    minikube = "/var/run/docker.sock"
    microk8s = "/var/run/docker.sock"
  }

  # Path where kubeconfig will be readable on the primary node
  kubeconfig_remote_path = {
    k3s      = "/etc/rancher/k3s/k3s.yaml"
    colima   = "~/.kube/config"
    podman   = "/etc/rancher/k3s/k3s.yaml"
    minikube = "~/.kube/config"
    microk8s = "~/.kube/config"
  }

  # Workers supported with: k3s, microk8s, colima
  active_workers = contains(["k3s", "microk8s", "colima"], var.runtime) ? var.worker_nodes : {}

  # ---------------------------------------------------------------------------
  # Exposure model — internal | tailnet | public
  # ---------------------------------------------------------------------------

  cf_enabled        = var.cloudflare_api_token != "" && var.cloudflare_account_id != "" && var.cloudflare_domain != ""
  tailscale_enabled = var.tailscale_auth_key != ""

  # All managed services with routing metadata
  _all_services = {
    argocd   = { enabled = var.enable_argocd, exposure = var.argocd_exposure, svc_ns = "argocd", svc_name = "argocd-server", svc_port = 80, hostname = var.argocd_hostname }
    kite     = { enabled = var.enable_dashboard && var.enable_kite, exposure = var.kite_exposure, svc_ns = "kube-system", svc_name = "kite", svc_port = 80, hostname = var.kite_hostname }
    dockge   = { enabled = var.enable_dashboard && var.enable_dockge, exposure = var.dockge_exposure, svc_ns = "default", svc_name = "dockge", svc_port = 5001, hostname = var.dockge_hostname }
    homepage = { enabled = var.enable_homepage, exposure = var.homepage_exposure, svc_ns = "default", svc_name = "homepage", svc_port = 3000, hostname = var.homepage_hostname }
    minio    = { enabled = var.enable_minio, exposure = var.minio_console_exposure, svc_ns = "minio", svc_name = "minio", svc_port = 9001, hostname = var.minio_console_hostname }
    longhorn = { enabled = var.enable_longhorn, exposure = var.longhorn_exposure, svc_ns = "longhorn-system", svc_name = "longhorn-frontend", svc_port = 80, hostname = var.longhorn_hostname }
    registry = { enabled = var.enable_registry, exposure = var.registry_exposure, svc_ns = "default", svc_name = "registry", svc_port = 5000, hostname = var.registry_hostname }
    pulse    = { enabled = var.enable_pulse, exposure = var.pulse_exposure, svc_ns = "default", svc_name = "pulse", svc_port = 7655, hostname = var.pulse_hostname }
    polaris  = { enabled = var.enable_polaris, exposure = var.polaris_exposure, svc_ns = "polaris", svc_name = "polaris-dashboard", svc_port = 80, hostname = var.polaris_hostname }
  }

  active_services = { for slug, svc in local._all_services : slug => svc if svc.enabled }

  # Public: Cloudflare Tunnel + DNS. Public hostname = <subdomain>.<cloudflare_domain>
  # e.g. argocd.drksci.local + blake.id.au → argocd.blake.id.au
  public_services = {
    for slug, svc in local.active_services : slug => merge(svc, {
      public_hostname = "${split(".", svc.hostname)[0]}.${var.cloudflare_domain}"
    })
    if svc.exposure == "public" && local.cf_enabled
  }

  # Tailnet: annotated for Tailscale operator → <slug>.<tailnet>.ts.net
  tailnet_services = {
    for slug, svc in local.active_services : slug => svc
    if svc.exposure == "tailnet" && local.tailscale_enabled
  }

  # JSON for shell scripts
  public_services_json  = jsonencode(local.public_services)
  tailnet_services_json = jsonencode(local.tailnet_services)
}
