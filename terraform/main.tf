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
# DYNAMIC AMI DISCOVERY (Role-Based Search)
# ------------------------------------------------------------------

# Find the latest Nginx-related AMI
data "aws_ami" "nginx_latest" {
  most_recent = true
  owners      = ["self"] 
  filter {
    name   = "name"
    # Matches any image name containing 'nginx'
    values = ["*nginx*"] 
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Find the latest Java-related AMI
data "aws_ami" "java_latest" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    # Matches any image name containing 'java'
    values = ["*java*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# ------------------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------------------

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH and Port 80"
  vpc_id      = var.project_vpc

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Allow SSH and App Ports"
  vpc_id      = var.project_vpc

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Python/App Port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Java App Port"
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
}

# ------------------------------------------------------------------
# EC2 INSTANCES (Task Nodes)
# ------------------------------------------------------------------

# Node 1: Java Node
resource "aws_instance" "java-node" {
  ami                    = data.aws_ami.java_latest.id
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = var.project_keyname
  tags                   = { Name = "Java-Node" } 
}

# Node 2: Nginx Node
resource "aws_instance" "nginx-node" {
  ami                    = data.aws_ami.nginx_latest.id
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.project_keyname
  tags                   = { Name = "Nginx-Node" } 
}

# Node 3: Ansible Server
resource "aws_instance" "ansible-server" {
  # Using the Java base image to ensure it's a Linux environment for Ansible
  ami                    = data.aws_ami.java_latest.id 
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
