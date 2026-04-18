# --- 1. Get latest Ubuntu 24.04 AMI ---
#data "aws_ami" "ubuntu-latest" {
#  provider    = aws.mumbai
#  most_recent = true
#  owners      = ["099720109477"] # Canonical (Official Ubuntu Owner ID)
#
#  filter {
#    name   = "name"
#    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-24.04-amd64-server-*"]
#  }
#
#  filter {
#    name   = "virtualization-type"
#    values = ["hvm"]
#  }
#}


# --- 5. Security Group ---
resource "aws_security_group" "mongo-redis-dev_sg" {
  provider    = aws.mumbai
  name        = "mongo-redis-dev-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id


  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.11.0.0/16", "192.168.0.0/16", "0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.11.0.0/16", "192.168.0.0/16", "110.227.248.141/32", "10.10.0.0/16"]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.11.0.0/16", "192.168.0.0/16"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.11.0.0/16", "192.168.0.0/16"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mongo-redis-dev-sg"
  }
}

# --- 6. The Bastion Host Instance (UPDATED TO t2.medium) ---
resource "aws_instance" "mongo-redis-dev" {
  provider      = aws.mumbai
  ami           = "ami-0a524481113ca6b94"
  instance_type = "t3a.medium" # Updated from t2.micro

  # Place in the first Public Subnet
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.mongo-redis-dev_sg.id]
  key_name                    = aws_key_pair.bastion_auth.key_name
  associate_public_ip_address = true
  # --- Updated Storage to 50 GB ---
  root_block_device {
    volume_size = 50
    volume_type = "gp3" # Latest high-performance SSD
  }  
  tags = {
    Name = "mongo-redis-dev"
    Env  = "Dev"
    ENV_Component = "DEV_Redis"
  }
}


# --- 9. Manage Instance State (Stop the Bastion) ---
resource "aws_ec2_instance_state" "mongo-redis-dev_state" {
  provider    = aws.mumbai
  instance_id = aws_instance.mongo-redis-dev.id
  state       = "running" # Options: "running", "stopped"
}
