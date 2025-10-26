output "alb_dns" {
  value = aws_lb.alb.dns_name
}
output "bucket" {
  value = aws_s3_bucket.site.bucket
}
output "asg_name" {
  value = aws_autoscaling_group.asg.name
}
