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
# DYNAMIC AMI DISCOVERY (The "Hands-Off" Secret)
# ------------------------------------------------------------------

# Find the latest Nginx AMI built by Packer
data "aws_ami" "nginx_latest" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["nginx-git-by-packer-*"]
  }
}

# Find the latest Java AMI built by Packer
data "aws_ami" "java_latest" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["java-git-by-packer-*"]
  }
}

# ------------------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------------------

# Web Node Security Group (Frontend)
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH and Port 80 inbound"
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

# Backend Security Group (Python & Java)
resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Allow SSH and Backend Ports"
  vpc_id      = var.project_vpc

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Python App Port (Per task requirements)
  ingress {
    description = "Python App"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Java App Port (Per task requirements)
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
# EC2 INSTANCES
# ------------------------------------------------------------------

# Node 1: Frontend (Nginx)
resource "aws_instance" "web-node" {
  ami                    = data.aws_ami.nginx_latest.id
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.project_keyname

  tags = { Name = "web-node" }
}

# Node 2: Backend (Python)
resource "aws_instance" "python-node" {
  ami                    = data.aws_ami.java_latest.id # Uses Java/Python image
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = var.project_keyname

  tags = { Name = "python-node" }
}

# Node 3: Backend (Java)
resource "aws_instance" "ansible-node" {
  ami                    = data.aws_ami.ansible_latest.id
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = var.project_keyname

  tags = { Name = "ansible-node" }
}

# ------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------

output "web_node_ip" {
  value = aws_instance.web-node.public_ip
}

output "python_node_ip" {
  value = aws_instance.python-node.public_ip
}

output "ansible-node_ip" {
  value = aws_instance.ansible-node.public_ip
}
