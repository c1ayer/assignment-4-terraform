terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-west-2"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "MainVPC"
  }
}

# Subnets
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"
  tags = {
    Name = "PublicSubnetA"
  }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "PrivateSubnetA"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2b"
  tags = {
    Name = "PublicSubnetB"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-west-2b"
  tags = {
    Name = "PrivateSubnetB"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MainIGW"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id
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
  tags = {
    Name = "WebServerSG"
  }
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "RDS_SG"
  }
}

# EC2 Instances
resource "aws_instance" "instance1" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_a.id
  security_groups = [aws_security_group.web_sg.name]
  tags = {
    Name = var.instance1_name
  }
}

resource "aws_instance" "instance2" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_b.id
  security_groups = [aws_security_group.web_sg.name]
  tags = {
    Name = var.instance2_name
  }
}

# RDS Instance
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds_subnet_group"
  subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
}

resource "aws_db_instance" "rds" {
  allocated_storage    = 20
  engine               = "mysql"
  instance_class       = "db.t2.micro"
  username             = "admin"
  password             = "password"
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot  = true
}

# Variables
variable "instance1_name" {
  description = "Name of the first EC2 instance"
  type        = string
  default     = "WebServer1"
}

variable "instance2_name" {
  description = "Name of the second EC2 instance"
  type        = string
  default     = "WebServer2"
}

# Outputs
output "instance1_public_ip" {
  description = "Public IP address of the first EC2 instance"
  value       = aws_instance.instance1.public_ip
}

output "instance2_public_ip" {
  description = "Public IP address of the second EC2 instance"
  value       = aws_instance.instance2.public_ip
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.rds.endpoint
}
