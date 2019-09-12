variable "namespace" {}

variable "job_name" {}
variable "task_manager_count" {}

variable "image" {}
variable "image_pull_secret" {}

variable "job_custom_env_variables"{
  description = "map"
  type        = map(string)
  default = {}
}
