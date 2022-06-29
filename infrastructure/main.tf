terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "wp-vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = {
    Name = "wp-vpc"
  }
}

resource "aws_internet_gateway" "wp-gw" {
  vpc_id = aws_vpc.wp-vpc.id
}

resource "aws_route_table" "wp-route-table" {
  vpc_id = aws_vpc.wp-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wp-gw.id
  }
  tags = {
    Name = "route-table-public"
  }
}

resource "aws_subnet" "wp-subnet" {
  vpc_id                  = aws_vpc.wp-vpc.id
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "wp-subnet-10-10-1-0"
    Tier = "Public"
  }
}

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.wp-subnet.id
  route_table_id = aws_route_table.wp-route-table.id
}

resource "aws_security_group" "wp-security-group" {
  name        = "wp-security-group"
  description = "wp-security-group"
  vpc_id      = aws_vpc.wp-vpc.id

  ingress {
    description = "http"
    from_port   = 0
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP traffic"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "wp-server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.wp-subnet.id

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update && sudo apt upgrade -y && sudo apt install -y ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

    sudo usermod -aG docker ubuntu

    git clone https://github.com/SadGecko/demo-cloud.git
    cd demo-cloud
    docker compose up -d
  EOF

  vpc_security_group_ids = [
    aws_security_group.wp-security-group.id
  ]

  tags = {
    Name = "wp-server"
  }
}

resource "local_file" "prometheus-config" {
  content  = templatefile("prometheus.tmpl", {
    server_ip = aws_instance.wp-server.public_ip,
  })
  filename = "../app/prometheus.yml"
}