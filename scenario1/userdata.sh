#!/bin/bash
yum update -y
yum install -y awscli nginx
systemctl enable nginx
systemctl start nginx
WEBROOT="/usr/share/nginx/html"
aws s3 sync s3://${bucket}/ $WEBROOT --region ${region}
