terraform {
  backend "s3" {
    bucket  = "texxclass"
    key     = "envs/dev/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# ------------------------------------------------------------------
# DYNAMIC AMI DISCOVERY (Amazon Linux 2023 - Official AWS)
# ------------------------------------------------------------------

# This replaces the Packer searches. It finds the latest official 
# Amazon Linux 2023 AMI which is Free Tier eligible.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ------------------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------------------

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH and Port 80 inbound" # Description matched to avoid recreation
  vpc_id      = var.project_vpc

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Web port 80"
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

  tags = { Name = "web-security_group" }
}

resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Allow SSH and Backend Ports" # Description matched to avoid recreation
  vpc_id      = var.project_vpc

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Python App"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Java App"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "backend-security_group" }
}

# ------------------------------------------------------------------
# EC2 INSTANCES (Using Amazon Linux 2023 Data Source)
# ------------------------------------------------------------------

# Node 1: Java Node
resource "aws_instance" "java-node" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = var.project_keyname
  tags                   = { Name = "Java-Node" } 
}

# Node 2: Nginx Node
resource "aws_instance" "nginx-node" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.project_keyname
  tags                   = { Name = "Nginx-Node" } 
}

# Node 3: Ansible Server
resource "aws_instance" "ansible-server" {
  ami                    = data.aws_ami.amazon_linux_2023.id 
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = var.project_keyname
  tags                   = { Name = "Ansible-Server" } 
}

# ------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------

output "Node_1_Java_IP" {
  value = aws_instance.java-node.public_ip
}

output "Node_2_Nginx_IP" {
  value = aws_instance.nginx-node.public_ip
}

output "Node_3_Ansible_Server_IP" {
  value = aws_instance.ansible-server.public_ip
}
