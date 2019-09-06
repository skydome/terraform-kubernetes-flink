# terraform-kubernetes-flink
Apache Flink on Kubernetes

Tested on GKE but it should work for any kubernetes cluster given the right terraform-provider-kubernetes setup.

## Inputs

- **namespace**          : kubernetes namespace to be deployed
- **job_name**           : name of the job
- **task_manager_count** : count of task manager for the job
- **image**              : docker image (i.e. skydome/my-flink-app)
- **image_pull_secret**  : image pull secret for fetching image from private registry

## Dependencies

Terraform Kubernetes Provider

## Tested With

- terraform-providers/kubernetes : 1.9.0
- kubernetes 1.13.7-gke.8

## Credits

This module was initially generated from helm/incubator/kafka via [k2tf](https://github.com/sl1pm4t/k2tf) project.
