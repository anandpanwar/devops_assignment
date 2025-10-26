data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "private" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = cidrsubnet(data.aws_vpc.default.cidr_block, 8, 20)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "nphc-private-subnet" }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  vpc_id      = data.aws_vpc.default.id
  description = "Allow HTTP only"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name   = "ec2-sg"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "site" {
  bucket        = var.bucket_name != "" ? var.bucket_name : "nphc-site-${random_id.bucket_suffix.hex}"
  force_destroy = true
  acl           = "private"
}

resource "aws_iam_role" "ec2_role" {
  name = "nphc-ec2-s3-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "s3_read" {
  name = "nphc-s3-read"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["s3:GetObject", "s3:ListBucket"],
      Resource = [
        aws_s3_bucket.site.arn,
        "${aws_s3_bucket.site.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_read.arn
}

resource "aws_iam_instance_profile" "profile" {
  name = "nphc-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_launch_template" "lt" {
  name_prefix   = "nphc-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  iam_instance_profile {
    name = aws_iam_instance_profile.profile.name
  }
  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    bucket = aws_s3_bucket.site.bucket
    region = var.aws_region
  }))
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }
}

resource "aws_lb" "alb" {
  name               = "nphc-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_vpc.default.subnets
}

resource "aws_lb_target_group" "tg" {
  name     = "nphc-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_autoscaling_group" "asg" {
  name                 = "nphc-asg"
  max_size             = var.asg_desired
  min_size             = var.asg_desired
  desired_capacity     = var.asg_desired
  vpc_zone_identifier  = [aws_subnet.private.id]
  target_group_arns    = [aws_lb_target_group.tg.arn]
  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "nphc-server"
    propagate_at_launch = true
  }
}
