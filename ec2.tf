variable "web_instance_ami" {
    type = string
}

variable "web_instance_type" {
    type = string
}

resource "aws_instance" "web-1" {
    ami                    = var.web_instance_ami
    instance_type          = var.web_instance_type
    subnet_id              = aws_subnet.subnet-1.id
    key_name               = "personal"
    iam_instance_profile   = aws_iam_instance_profile.web-instance-profile.id

    vpc_security_group_ids = [
        aws_security_group.web-1-sg.id
    ]

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update
                sudo apt install -y nginx
                sudo apt install python3-requests -y
                sudo apt install python3-schedule -y
                sudo apt install python3-boto3 -y
                sudo service nginx enable
                sudo service nginx start
                EOF

    tags = {
        Name        = "${var.project}-${var.environment}-web-1"
        Environment = "${var.environment}"
    }
}

resource "aws_instance" "web-2" {
    ami                          = var.web_instance_ami
    instance_type                = var.web_instance_type
    subnet_id                    = aws_subnet.subnet-2.id
    key_name                     = "personal"

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update
                sudo apt install -y nginx
                sudo apt install python3-requests -y
                sudo apt install python3-schedule -y
                sudo apt install python3-boto3 -y
                sudo service nginx enable
                sudo service nginx start
                EOF

    vpc_security_group_ids = [
        aws_security_group.web-2-sg.id
    ]

    tags = {
        Name        = "${var.project}-${var.environment}-web-2"
        Environment = "${var.environment}"
    }
}

resource "aws_security_group" "web-1-sg" {
    name        = "${var.project}-${var.environment}-web-1-sg"
    description = "Allow HTTP and SSH Traffic"
    vpc_id      = aws_vpc.vpc.id

    tags        = {
        Name = "${var.project}-${var.environment}-web-1-sg"
        Environment = "${var.environment}"
    }
}

resource "aws_vpc_security_group_ingress_rule" "web-1-sg-inbound-ssh" {
    cidr_ipv4         = "0.0.0.0/0"
    description       = "Allow SSH Traffic"
    from_port         = 22
    to_port           = 22
    ip_protocol       = "tcp"
    security_group_id = aws_security_group.web-1-sg.id
}

resource "aws_vpc_security_group_ingress_rule" "web-1-sg-inbound-http" {
    cidr_ipv4         = "0.0.0.0/0"
    description       = "Allow HTTP Traffic"
    from_port         = 80
    to_port           = 80
    ip_protocol       = "tcp"
    security_group_id = aws_security_group.web-1-sg.id
}

resource "aws_vpc_security_group_egress_rule" "web-1-sg-outbound-all" {
  security_group_id = aws_security_group.web-1-sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_security_group" "web-2-sg" {
    name        = "${var.project}-${var.environment}-web-2-sg"
    description = "Allow HTTP and SSH Traffic"
    vpc_id      = aws_vpc.vpc.id

    tags        = {
        Name = "${var.project}-${var.environment}-web-2-sg"
        Environment = "${var.environment}"
    }
}

resource "aws_vpc_security_group_ingress_rule" "web-2-sg-inbound-ssh" {
    cidr_ipv4         = "0.0.0.0/0"
    description       = "Allow SSH Traffic"
    from_port         = 22
    to_port           = 22
    ip_protocol       = "tcp"
    security_group_id = aws_security_group.web-2-sg.id
}

resource "aws_vpc_security_group_egress_rule" "web-2-sg-outbound-all" {
  security_group_id = aws_security_group.web-2-sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

resource "aws_iam_role" "web-role" {
    name = "${var.environment}-web-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
            Service = "ec2.amazonaws.com"
            }
        },
        ]
    })

    inline_policy {
        name = "web-${var.environment}-s3-access"

        policy = jsonencode({
            Version = "2012-10-17"
            Statement = [
                {
                    Action   = [
                        "s3:ListBucket",
                        "s3:ListBucketVersions",
                        "s3:GetObject",
                        "s3:GetObjectVersion",
                        "s3:PutObject",
                        "s3:DeleteObject",
                    ]
                    Effect   = "Allow"
                    Resource = [
                        "arn:aws:s3:::${var.bucket_name}/*",
                        "arn:aws:s3:::${var.bucket_name}"
                    ]
                },
            ]
    })
  }

  tags = {
    Environment = "${var.environment}"
  }
}

resource "aws_iam_instance_profile" "web-instance-profile" {
  name = "${var.project}-${var.environment}-web-instance-profile"
  role = aws_iam_role.web-role.name
}
