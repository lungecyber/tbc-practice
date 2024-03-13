resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    tags       = {
        Name        = "${var.project}-${var.environment}-vpc"
        Environment = "${var.environment}"
    }
}

resource "aws_internet_gateway" "igw" {
  tags = {
    Name = "${var.project}-${var.environment}-igw"
  }
}

resource "aws_internet_gateway_attachment" "igw-attachment" {
    internet_gateway_id = aws_internet_gateway.igw.id
    vpc_id              = aws_vpc.vpc.id
}

resource "aws_route_table" "rt" {
    vpc_id = aws_vpc.vpc.id

    tags   = {
        Name = "${var.project}-${var.environment}-rt"
    }
}

resource "aws_route" "igw-route" {
    route_table_id         = aws_route_table.rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "subnet-1-rt-association" {
    subnet_id      = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "subnet-2-rt-association" {
    subnet_id      = aws_subnet.subnet-2.id
    route_table_id = aws_route_table.rt.id
}

resource "aws_subnet" "subnet-1" {
    vpc_id                  = aws_vpc.vpc.id
    cidr_block              = "10.0.1.0/24"
    availability_zone       = "eu-central-1a"
    map_public_ip_on_launch = true

    tags       = {
        Name        = "${var.project}-${var.environment}-public-subnet-1"
        Environment = "${var.environment}"
    }
}

resource "aws_subnet" "subnet-2" {
    vpc_id                  = aws_vpc.vpc.id
    cidr_block              = "10.0.2.0/24"
    availability_zone       = "eu-central-1b"
    map_public_ip_on_launch = true

    tags       = {
        Name = "${var.project}-${var.environment}-public-subnet-2"
        Environment = "${var.environment}"
    }
}

resource "aws_eip" "eip" {
    instance = aws_instance.web-1.id
    domain   = "vpc"
}
