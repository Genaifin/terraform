# --- 1. Athena SIT Instance ---
resource "aws_instance" "athena_sit" {
  provider      = aws.mumbai
  ami           = "ami-07216ac99dc46a187" # References bastionhost.tf
  instance_type = "c7i.large"

  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id] 
  key_name               = aws_key_pair.bastion_auth.key_name 

  # --- Updated Storage to 30 GB ---
  root_block_device {
    volume_size = 30
    volume_type = "gp3" # Latest high-performance SSD
  }

  tags = {
    Name = "Athena-sit"
    ENV_Product = "DEV_Athena"
  }
}

# --- 2. Elastic IP for Athena SIT ---
resource "aws_eip" "athena_sit_eip" {
  provider = aws.mumbai
  domain   = "vpc"

  tags = {
    Name = "athena-sit-eip"
  }
}

# --- 3. Attach EIP to Athena SIT ---
resource "aws_eip_association" "sit_eip_assoc" {
  provider      = aws.mumbai
  instance_id   = aws_instance.athena_sit.id
  allocation_id = aws_eip.athena_sit_eip.id
}

# --- 4. Athena UAT Instance ---
resource "aws_instance" "athena_uat" {
  provider      = aws.mumbai
  ami           = "ami-07216ac99dc46a187" # References bastionhost.tf
  instance_type = "c7i.large"

  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = aws_key_pair.bastion_auth.key_name

  # --- Updated Storage to 30 GB ---
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "Athena-uat"
    ENV_Product = "UAT_Athena"
  }
}

# --- 5. Elastic IP for Athena UAT ---
resource "aws_eip" "athena_uat_eip" {
  provider = aws.mumbai
  domain   = "vpc"

  tags = {
    Name = "athena-uat-eip"
  }
}

# # --- 6. Attach EIP to Athena UAT ---
# resource "aws_eip_association" "uat_eip_assoc" {
#   provider      = aws.mumbai
#   instance_id   = "i-0f1c3724dc8e75aa8"
#   allocation_id = aws_eip.athena_uat_eip.id
# }

#--- 7. Outputs ---
output "athena_sit_static_ip" {
  value = aws_eip.athena_sit_eip.public_ip
}

output "athena_uat_static_ip" {
  value = aws_eip.athena_uat_eip.public_ip
}

# --- 8. Instance State Management (Stop/Start) ---

resource "aws_ec2_instance_state" "athena_sit_state" {
  provider    = aws.mumbai
  instance_id = aws_instance.athena_sit.id
  state       = "running" # Change to "running" to start
}

resource "aws_ec2_instance_state" "athena_uat_state" {
  provider    = aws.mumbai
  instance_id = aws_instance.athena_uat.id
  state       = "running" # Change to "running" to start
}
