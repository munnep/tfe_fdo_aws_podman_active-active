variable "tag_prefix" {
  description = "default prefix of names"
}

variable "region" {
  description = "region to create the environment"
}

variable "vpc_cidr" {
  description = "which private subnet do you want to use for the VPC. Subnet mask of /16"
}

variable "dns_hostname" {
  type        = string
  description = "DNS name you use to access the website"
}

variable "dns_zonename" {
  type        = string
  description = "DNS zone the record should be created in"
}

variable "certificate_email" {
  type        = string
  description = "email adress that the certificate will be associated with on Let's Encrypt"
}

variable "rds_password" {
  description = "password for the RDS postgres database user"
}

variable "tfe_password" {
  description = "password for tfe user"
}

variable "asg_min_size" {
  description = "Autoscaling group minimal size"
  default     = 1
}

variable "asg_max_size" {
  description = "Autoscaling group maximal size"
  default     = 1
}

variable "asg_desired_capacity" {
  description = "Autoscaling group running number of instances"
  default     = 1
}

variable "public_key" {
  type        = string
  description = "public to use on the instances"
}

variable "terraform_client_version" {
  description = "Terraform client installed on the terraform client machine"
}

variable "tfe_license" {
  description = "TFE license as a string"
}

variable "tfe_release" {
  description = "Which release version of TFE to install"
}