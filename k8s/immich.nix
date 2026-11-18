{ kubenix, ... }:
let
  immichChart = kubenix.lib.helm.fetch {
    repo = "https://immich-app.github.io/immich-charts";
    chart = "immich";
    version = "0.12.0";
    sha256 = "sha256-Lfx0JwdG65oTeql/qEBF6OOgqYw9AMU+uEdI0Yi5fuQ=";
  };
in
{
  imports = with kubenix.modules; [
    k8s
    helm
  ];

  kubenix.project = "my-cluster";
  kubernetes.version = "1.37";

  kubernetes.resources.persistentVolumeClaims.immich-library = {
    metadata.namespace = "immich";
    spec = {
      accessModes = [ "ReadWriteOnce" ];
      resources.requests.storage = "100Gi";
    };
  };

  kubernetes.resources.persistentVolumeClaims.immich-postgres = {
    metadata.namespace = "immich";
    spec = {
      accessModes = [ "ReadWriteOnce" ];
      resources.requests.storage = "10Gi";
    };
  };

  kubernetes.resources.statefulSets.immich-postgres = {
    metadata.namespace = "immich";
    spec = {
      replicas = 1;
      serviceName = "immich-postgres";
      selector.matchLabels.app = "immich-postgres";
      template = {
        metadata.labels.app = "immich-postgres";
        spec = {
          containers.postgres = {
            image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";
            env = [
              {
                name = "POSTGRES_USER";
                value = "postgres";
              }
              {
                name = "POSTGRES_DB";
                value = "immich";
              }
              {
                name = "POSTGRES_INITDB_ARGS";
                value = "--data-checksums";
              }
              {
                name = "POSTGRES_PASSWORD";
                valueFrom.secretKeyRef = {
                  name = "immich-db";
                  key = "password";
                };
              }
            ];
            ports = [
              {
                name = "postgres";
                containerPort = 5432;
              }
            ];
            volumeMounts = [
              {
                name = "data";
                mountPath = "/var/lib/postgresql/data";
              }
              {
                name = "shm";
                mountPath = "/dev/shm";
              }
            ];
          };
          volumes = [
            {
              name = "data";
              persistentVolumeClaim.claimName = "immich-postgres";
            }
            {
              name = "shm";
              emptyDir = {
                medium = "Memory";
                sizeLimit = "128Mi";
              };
            }
          ];
        };
      };
    };
  };

  kubernetes.resources.services.immich-postgres = {
    metadata.namespace = "immich";
    spec = {
      selector.app = "immich-postgres";
      ports = [
        {
          name = "postgres";
          port = 5432;
          targetPort = 5432;
        }
      ];
    };
  };

  kubernetes.helm.releases.immich = {
    chart = immichChart;
    namespace = "immich";
    values = {
      immich.persistence.library.existingClaim = "immich-library";
      valkey.enabled = true;
      server = {
        service.main.type = "LoadBalancer";
        controllers.main.containers.main.env = {
          DB_HOSTNAME = "immich-postgres";
          DB_USERNAME = "postgres";
          DB_DATABASE_NAME = "immich";
          DB_PASSWORD.valueFrom.secretKeyRef = {
            name = "immich-db";
            key = "password";
          };
        };
      };
    };
  };
}
