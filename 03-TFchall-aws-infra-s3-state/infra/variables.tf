##################################################
# Define variables to allow configurable resources
##################################################

variable "webserver_port" {
  description = "TCP port that webserver listen to"
  type        = number
  default     = 8000
}

variable "webserver_name" {
  description = "Name of web server"
  type        = string
  default     = "Web Server"
}

variable "Webserver_instance_type" {
  description = "Instance type of webserver"
  type        = string
  default     = "t2.micro"
}

variable "webserver_template_name_prefix" {
  description = "prefix of launch template name"
  type        = string
  default     = "tmpl-ws-"
}

variable "webserver_asg_name_prefix" {
  description = "prefix of auto scaling group name"
  type        = string
  default     = "asg-ws-"
}

variable "webserver_lb_name" {
  description = "Name of aws application loadbalancer used in front of auto scaling group"
  type        = string
  default     = "lb-webserver"
}