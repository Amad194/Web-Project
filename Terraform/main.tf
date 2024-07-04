provider "aws" {
  region = "us-east-1" # Change to your preferred region
}

# Generate RSA key pair
resource "tls_private_key" "webkeypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# EC2 Key Pair
resource "aws_key_pair" "webkeypair" {
  key_name   = "webkeypair"  # Replace with your desired key pair name
  public_key = tls_private_key.webkeypair.public_key_openssh

  tags = {
    Name = "WebKeyPair"
  }
}

output "private_key" {
  value = tls_private_key.webkeypair.private_key_pem
  sensitive = true  # Marking the output as sensitive
}

output "public_key" {
  value = aws_key_pair.webkeypair.key_name
}

# Fetch information about the current IAM user
data "aws_iam_user" "current" {
  user_name = "s3admin"  # Replace with your IAM user name
}

# Data for Availability Zones
data "aws_availability_zones" "available" {}

# VPC ID
variable "vpc_id" {
  default = "vpc-00a27aad9988998e3"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/24"  # Replace with your actual VPC CIDR block
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "MainVPC"
  }
}

# Internet Gateway ID
variable "igw_id" {
  default = "igw-044b0050722277626"
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 4, count.index)  # Creates /28 subnets within 10.0.0.0/24 
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 4, count.index + 8)  # Creates /28 subnets within 10.0.0.0/24  
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = "rtb-0bdfa61fdf0b6a17c"  # Replace with your actual route table ID
}

# Security Group for Web Server
resource "aws_security_group" "web_sg" {
  vpc_id = var.vpc_id

  # Ingress rule for HTTP (Port 80) from 0.0.0.0/0
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress rule for SSH (Port 22) from your specific IP address
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.175.72.56/32"] # Replace with your actual IP address
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  vpc_id = var.vpc_id

  # Ingress rule for MySQL (Port 3306) from the Web Server's subnet
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Allow from Web Server SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami           = "ami-06c68f701d8090592" # Amazon Linux 2023 AMI for us-east-1
  instance_type = "t2.micro"
  subnet_id     = element(aws_subnet.public.*.id, 0)
  security_groups = [aws_security_group.web_sg.id]
  key_name      = aws_key_pair.webkeypair.key_name  # Use the key_name attribute

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1.12 -y
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "WebServer"
  }
}

# Load Balancer
resource "aws_lb" "public" {
  name               = "public-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = aws_subnet.public.*.id

  tags = {
    Name = "public-lb"
  }
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  tags = {
    Name = "web-tg"
  }
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.public.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }

  tags = {
    Name = "web-listener"
  }
}

resource "aws_lb_target_group_attachment" "web_tg_attachment" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web.id
  port             = 80
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "unique-web-subnet-group-rds" # Updated name
  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name = "main-subnet-group"
  }
}

# RDS Instance
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0.37" # Supported MySQL version
  instance_class       = "db.c6gd.medium" # Supported instance class
  identifier           = "mydb" # Use identifier instead of name
  username             = "admin"
  password             = "password" # Store this securely in production
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible  = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  tags = {
    Name = "default-rds-instance"
  }
}
