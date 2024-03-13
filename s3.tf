variable "bucket_name" {
    type = string
}

resource "aws_s3_bucket" "bucket" {
    bucket = "${var.bucket_name}"

    tags = {
        Name        = "${var.bucket_name}"
        Environment = "${var.environment}"
    }
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
    bucket = aws_s3_bucket.bucket.id

    policy = <<EOT
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "AllowCloudFrontServicePrincipal",
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "cloudfront.amazonaws.com"
                    },
                    "Action": "s3:GetObject",
                    "Resource": "arn:aws:s3:::${var.bucket_name}/*",
                    "Condition": {
                        "StringEquals": {
                            "AWS:SourceArn": "${aws_cloudfront_distribution.s3-distribution.arn}"
                        }
                    }
                }
            ]
        }
    EOT
}
