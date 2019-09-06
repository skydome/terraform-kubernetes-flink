resource "kubernetes_config_map" "flink_config" {
  metadata {
    name = "${var.job_name}-flink-config"
    namespace = "${var.namespace}"

    labels = {
      app = "${var.job_name}"
    }
  }

  data = {
    "flink-conf.yaml" = "blob.server.port: 6124\njobmanager.rpc.address: ${var.job_name}-jobmanager\njobmanager.rpc.port: 6123\njobmanager.heap.mb: 1024\ntaskmanager.heap.mb: 1024\ntaskmanager.numberOfTaskSlots: 1\nweb.upload.dir: /opt/flink/lib/jobs"

    "log4j-console.properties" = "log4j.rootLogger=INFO, console, file\n\n# Uncomment this if you want to _only_ change Flink's logging\n#log4j.logger.org.apache.flink=INFO\n\n# The following lines keep the log level of common libraries/connectors on\n# log level INFO. The root logger does not override this. You have to manually\n# change the log levels here.\nlog4j.logger.akka=INFO\nlog4j.logger.org.apache.kafka=INFO\nlog4j.logger.org.apache.hadoop=INFO\nlog4j.logger.org.apache.zookeeper=INFO\n\n# Suppress the irrelevant (wrong) warnings from the Netty channel handler\nlog4j.logger.org.jboss.netty.channel.DefaultChannelPipeline=ERROR, console\n\n# Log all infos to the console\nlog4j.appender.console=org.apache.log4j.ConsoleAppender\nlog4j.appender.console.layout=org.apache.log4j.PatternLayout\nlog4j.appender.console.layout.ConversionPattern=%d{yyyy-MM-dd HH:mm:ss,SSS} %-5p %-60c %x - %m%n\n"
  }
}

resource "kubernetes_config_map" "flink_hadoop_config" {
  metadata {
    name = "${var.job_name}-hadoop-config"
    namespace = "${var.namespace}"

    labels = {
      app = "${var.job_name}"
    }
  }

  data = {
    "core-site.xml" = "<?xml version=\"1.0\"?>\n<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>\n<configuration/>\n"
  }
}

resource "kubernetes_deployment" "flink_jobmanager" {
  metadata {
    name      = "${var.job_name}-jobmanager"
    namespace = "${var.namespace}"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "${var.job_name}-jobmanager"
      }
    }


    template {
      metadata {
        labels = {
          app = "${var.job_name}-jobmanager"

          component = "jobmanager"
        }
      }

      spec {
        volume {
          name = "${var.job_name}-flink-config"

          config_map {
            name = "${var.job_name}-flink-config"
          }
        }

        volume {
          name = "${var.job_name}-hadoop-config"

          config_map {
            name = "${var.job_name}-hadoop-config"
          }
        }

        container {
          name    = "jobmanager"
          image   = "${var.image}"
          command = ["/bin/bash", "-c", "/opt/flink/bin/standalone-job.sh start-foreground job-cluster; while :; do if [[ -f $(find log -name '*jobmanager*.log' -print -quit) ]]; then tail -f -n +1 log/*jobmanager*.log; fi; done"]

          port {
            name           = "rpc"
            container_port = 6123
          }

          port {
            name           = "blob"
            container_port = 6124
          }

          port {
            name           = "ui"
            container_port = 8081
          }

          env {
            name  = "FLINK_CONF_DIR"
            value = "/etc/flink"
          }

          resources {
            limits {
              cpu    = "1"
              memory = "1280Mi"
            }

            requests {
              cpu    = "1"
              memory = "1280Mi"
            }
          }

          volume_mount {
            name       = "${var.job_name}-flink-config"
            mount_path = "/etc/flink"
          }

          liveness_probe {
            http_get {
              path = "/overview"
              port = "8081"
            }

            initial_delay_seconds = 30
            period_seconds        = 10
          }

          image_pull_policy = "Always"
        }

        image_pull_secrets {
          name = "${var.image_pull_secret}"
        }
      }
    }
  }
}

resource "kubernetes_deployment" "flink_taskmanager" {
  metadata {
    name      = "${var.job_name}-taskmanager"
    namespace = "${var.namespace}"
  }

  spec {
    replicas = "${var.task_manager_count}"

    selector {
      match_labels = {
        app = "${var.job_name}-taskmanager"
      }
    }


    template {
      metadata {
        labels = {
          app = "${var.job_name}-taskmanager"

          component = "taskmanager"
        }
      }

      spec {
        volume {
          name = "${var.job_name}-flink-config"

          config_map {
            name = "${var.job_name}-flink-config"
          }
        }

        volume {
          name = "${var.job_name}-hadoop-config"

          config_map {
            name = "${var.job_name}-hadoop-config"
          }
        }

        container {
          name        = "taskmanager"
          image       = "${var.image}"
          command     = ["/bin/bash", "-c", "/opt/flink/bin/taskmanager.sh start; while :; do if [[ -f $(find log -name '*taskmanager*.log' -print -quit) ]]; then tail -f -n +1 log/*taskmanager*.log; fi; done"]
          working_dir = "/opt/flink"

          port {
            name           = "data"
            container_port = 6121
          }

          port {
            name           = "rpc"
            container_port = 6122
          }

          port {
            name           = "query"
            container_port = 6125
          }

          env {
            name  = "FLINK_CONF_DIR"
            value = "/etc/flink"
          }

          resources {
            limits {
              cpu    = "1"
              memory = "1280Mi"
            }

            requests {
              cpu    = "1"
              memory = "1280Mi"
            }
          }

          volume_mount {
            name       = "${var.job_name}-flink-config"
            mount_path = "/etc/flink"
          }

          volume_mount {
            name       = "${var.job_name}-hadoop-config"
            mount_path = "/etc/hadoop/conf"
          }

          image_pull_policy = "Always"
        }

        image_pull_secrets {
          name = "${var.image_pull_secret}"
        }
      }
    }
  }
}

resource "kubernetes_service" "flink_jobmanager" {
  metadata {
    name = "${var.job_name}-jobmanager"
    namespace = "${var.namespace}"
  }

  spec {
    port {
      name = "rpc"
      port = 6123
    }

    port {
      name = "blob"
      port = 6124
    }

    port {
      name = "ui"
      port = 8081
    }

    selector = {
      app = "${var.job_name}-jobmanager"

      component = "jobmanager"
    }
  }
}



