# --- 10. The Airflow-dev Instance ---
resource "aws_instance" "airflow" {
  provider      = aws.mumbai
  ami           = "ami-07216ac99dc46a187" # Using the dynamic AMI from step 1
  instance_type = "t3.large" 

  # Place in the public subnet
  subnet_id                   = aws_subnet.public[0].id
  
  # Reusing the Security Group created in Step 5
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  
  # Reusing the SSH Key Pair created in Step 3
  key_name                    = aws_key_pair.bastion_auth.key_name
  
  tags = {
    Name = "Airflow-dev"
  }
}

# --- 11. Create Elastic IP (EIP) for Airflow ---


# --- 12. Attach Elastic IP to the Airflow Instance ---


# --- 13. Ensure Airflow Instance is Running ---
resource "aws_ec2_instance_state" "airflow_state" {
  provider    = aws.mumbai
  instance_id = aws_instance.airflow.id
  state       = "running"
}
