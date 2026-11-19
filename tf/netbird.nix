{ ... }:
{
  terraform.required_providers.netbird = {
    source = "netbirdio/netbird";
    version = "0.0.11";
  };

  provider.netbird.management_url = "https://netbird.maril.blue";

  resource.netbird_group.kubernetes_clients = {
    name = "kubernetes-clients";
    lifecycle = [
      {
        ignore_changes = [
          "peers"
          "resources"
        ];
      }
    ];
  };

  resource.netbird_group.kubernetes_services = {
    name = "kubernetes-services";
    lifecycle = [
      {
        ignore_changes = [
          "peers"
          "resources"
        ];
      }
    ];
  };

  resource.netbird_group.admin = {
    name = "admin";
    lifecycle = [
      {
        ignore_changes = [
          "peers"
          "resources"
        ];
      }
    ];
  };

  resource.netbird_group.guest = {
    name = "guest";
    lifecycle = [
      {
        ignore_changes = [
          "peers"
          "resources"
        ];
      }
    ];
  };

  data.netbird_group.all = {
    name = "All";
  };

  # operatorはdnsZoneRef.nameをゾーンのnameと比較するため、nameはdomainと同じにする
  # https://github.com/netbirdio/kubernetes-operator/blob/v0.9.0/internal/netbirdutil/zone.go
  resource.netbird_dns_zone.cluster = {
    name = "syakechan.internal";
    domain = "syakechan.internal";
    enabled = true;
    enable_search_domain = true;
    distribution_groups = [ "\${netbird_group.kubernetes_clients.id}" ];
  };

  resource.netbird_policy.kubernetes_services = {
    name = "kubernetes-services";
    enabled = true;
    rule = [
      {
        name = "kubernetes-services";
        action = "accept";
        enabled = true;
        bidirectional = true;
        protocol = "tcp";
        sources = [ "\${netbird_group.kubernetes_clients.id}" ];
        destinations = [ "\${netbird_group.kubernetes_services.id}" ];
      }
    ];
  };

  resource.netbird_policy.default = {
    name = "Default";
    enabled = false;
    rule = [
      {
        name = "Default";
        action = "accept";
        enabled = false;
        bidirectional = true;
        protocol = "all";
        sources = [ "\${data.netbird_group.all.id}" ];
        destinations = [ "\${data.netbird_group.all.id}" ];
      }
    ];
  };

  # 1ポリシーにルールは1つまでなので、sshと全プロトコルでポリシーを分ける
  resource.netbird_policy.admin_ssh = {
    name = "admin-ssh";
    enabled = true;
    rule = [
      {
        name = "admin-ssh";
        action = "accept";
        enabled = true;
        bidirectional = true;
        protocol = "netbird-ssh";
        sources = [ "\${netbird_group.admin.id}" ];
        destinations = [ "\${netbird_group.admin.id}" ];
      }
    ];
  };

  resource.netbird_policy.admin_all = {
    name = "admin-all";
    enabled = true;
    rule = [
      {
        name = "admin-all";
        action = "accept";
        enabled = true;
        bidirectional = true;
        protocol = "all";
        sources = [ "\${netbird_group.admin.id}" ];
        destinations = [ "\${netbird_group.admin.id}" ];
      }
    ];
  };

  resource.netbird_policy.guest = {
    name = "guest";
    enabled = true;
    rule = [
      {
        name = "guest-all";
        action = "accept";
        enabled = true;
        bidirectional = true;
        protocol = "all";
        sources = [ "\${netbird_group.guest.id}" ];
        destinations = [ "\${netbird_group.guest.id}" ];
      }
    ];
  };
}
