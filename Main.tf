
provider "aws" {
  region = "us-east-2"
}

variable "vpc_cidr_block" {}
variable "subnet_cdir_block" {}
variable "availability_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}

resource "aws_subnet" "nicedev-subnet-1" {
  vpc_id            = aws_vpc.nicedev-vpc.id
  cidr_block        = var.subnet_cdir_block
  availability_zone = var.availability_zone
  tags = {
    Name : "${var.env_prefix}-subnet-1"
  }
}

resource "aws_vpc" "nicedev-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name : "${var.env_prefix}-vpc"
  }
}


resource "aws_internet_gateway" "nicedev-igw" {
  vpc_id = aws_vpc.nicedev-vpc.id
  tags = {
    name : "${var.env_prefix}-igw"
  }
}

resource "aws_route_table" "nicedev-route-table" {
  vpc_id = aws_vpc.nicedev-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nicedev-igw.id
  }
  tags = {
    name : "${var.env_prefix}-rtb"
  }
}

resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id      = aws_subnet.nicedev-subnet-1.id
  route_table_id = aws_route_table.nicedev-route-table.id


}


resource "aws_security_group" "nicedev-sg" {
  name   = "nicedev-sg"
  vpc_id = aws_vpc.nicedev-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = [var.my_ip]
  }


  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    name : "${var.env_prefix}-nicedev-sg"
  }

}

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
resource "aws_instance" "nicedev-server" {
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type

  subnet_id              = aws_subnet.nicedev-subnet-1.id
  vpc_security_group_ids = [aws_security_group.nicedev-sg.id]
  availability_zone      = var.availability_zone

  associate_public_ip_address = true
  key_name                    = aws_key_pair.ssh-key.key_name

  user_data = file("entry-script.sh")

  user_data_replace_on_change = true

  tags = {
    name : "${var.env_prefix}-nicedev"
    foo = "bar"
  }
}

output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image

}

output "ec2_public_ip" {
  value = aws_instance.nicedev-server.public_ip

}


resource "aws_key_pair" "ssh-key" {
  key_name   = "tf-key"
  public_key = file(var.public_key_location)
}

