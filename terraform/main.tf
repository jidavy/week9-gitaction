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

# Node 1: Java Node
resource "aws_instance" "java-node" {
  ami                    = data.aws_ami.java_latest.id
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = var.project_keyname

  tags = { Name = "Java-Node" } # Required per Task 
}

# Node 2: Nginx Node
resource "aws_instance" "nginx-node" {
  ami                    = data.aws_ami.nginx_latest.id
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.project_keyname

  tags = { Name = "Nginx-Node" } # Required per Task 
}

# Node 3: Ansible Server
resource "aws_instance" "ansible-server" {
  # If you don't have an 'ansible_latest' data source, 
  # use one of your other AMIs or a standard one.
  ami                    = data.aws_ami.java_latest.id 
  instance_type          = var.project_instance_type
  subnet_id              = var.project_subnet
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = var.project_keyname

  tags = { Name = "Ansible-Server" } # Required per Task 
}

# ------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------

output "Node_1_Java_IP" {
  description = "Public IP of the Java Node"
  value       = aws_instance.java-node.public_ip
}

output "Node_2_Nginx_IP" {
  description = "Public IP of the Nginx Node"
  value       = aws_instance.nginx-node.public_ip
}

output "Node_3_Ansible_Server_IP" {
  description = "Public IP of the Ansible Control Server"
  value       = aws_instance.ansible-server.public_ip
}
