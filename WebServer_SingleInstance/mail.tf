provider "aws" {
  region = "us-east-1"

  #keys are keept as variables in a local file
  access_key = var.AccessKey
  secret_key = var.SecretKey
}

# 1. create vpc

resource "aws_vpc" "vpc_webserver_singleinstance" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "vpc for web server on a single instance"
  }
}

# 2. create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_webserver_singleinstance.id
}

# 3. create custom route table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc_webserver_singleinstance.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "enable the internet access for subnet"
  }
}

# 4. create a subnet
resource "aws_subnet" "subnet_public_a" {
  vpc_id            = aws_vpc.vpc_webserver_singleinstance.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "for the web server instance"
  }
}

# 5. associate the subnet with the custom route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_public_a.id
  route_table_id = aws_route_table.rt.id
}

# 6. create security group to allow income traffic on port 22, 80 and 443
resource "aws_security_group" "allow_22_80_443" {
  name        = "allow_22_80_443"
  description = "Allow inbound traffic on 22, 80 and 443"
  vpc_id      = aws_vpc.vpc_webserver_singleinstance.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ping from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow 22, 80 and 443"
  }
}

# 7. create a network interface with an IP in the subnet created in step 4
resource "aws_network_interface" "web_server_nip" {
  subnet_id       = aws_subnet.subnet_public_a.id
  private_ips     = ["10.0.1.101"]
  security_groups = [aws_security_group.allow_22_80_443.id]
}

# 8. assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.web_server_nip.id
  associate_with_private_ip = "10.0.1.101"

  depends_on = [aws_internet_gateway.igw,aws_instance.web_server]
}

# 9. create Amazon Linux server and install/endable apache2
resource "aws_instance" "web_server" {
  ami               = "ami-01bc990364452ab3e"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "keypair_for_terraform"


  network_interface {    
    network_interface_id = aws_network_interface.web_server_nip.id
    device_index         = 0
  }

/*
  user_data = <<EOF
#!/bin/bash
# Use this for your user data (script from top to bottom)
# install httpd (Linux 2 version)
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
EOF
*/

user_data = file("${path.module}/user-data.txt")

  tags = {
    Name = "web server"
  }
}
