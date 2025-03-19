# output "ssh_tf_client" {
#   value = "ssh ubuntu@${var.dns_hostname}-client.${var.dns_zonename}"
# }

# output "tfe_netdata_performance_dashboard" {
#   value = "http://${var.dns_hostname}.${var.dns_zonename}:19999"
# }

output "tfe_appplication" {
  value = "https://${var.dns_hostname}.${var.dns_zonename}"
}

data "aws_instances" "foo" {
  instance_tags = {
    "Name" = "${var.tag_prefix}-tfe-asg"
  }
  instance_state_names = ["running"]
}

output "ssh_tfe_server" {
  value = data.aws_instances.foo.ids
}

output "tfe_server_connection" {
  value = join("\n", [
    "# Make a connection using doormat. For example",
    "doormat session --account aws_patrick.munne_test --region ${var.region}"
  ])
}
