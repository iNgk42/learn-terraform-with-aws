#####################
# Define some outputs
#####################

output "lb_dns_name" {
  value = aws_lb.webserver_lb.dns_name
}

output "webserver_port_listening" {
  value = var.webserver_port
}