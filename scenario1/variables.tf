variable "aws_region" {
  default = "ap-southeast-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "bucket_name" {
  default = ""
}

variable "asg_desired" {
  default = 3
}
