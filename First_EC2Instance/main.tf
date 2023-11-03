provider "aws" {
    region="us-east-1"

    #keys are keept as variables in a local file
    access_key = var.AccessKey
    secret_key = var.SecretKey
}

resource "aws_instance" "EC2Instance_HelloWorld" {
  ami           = "ami-01bc990364452ab3e"
  instance_type = "t2.micro"
  tags = {
    Name = "My first instance created via Terraform"
  }
}