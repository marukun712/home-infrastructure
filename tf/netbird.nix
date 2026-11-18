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

  resource.netbird_dns_zone.cluster = {
    name = "syakechan";
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
}
