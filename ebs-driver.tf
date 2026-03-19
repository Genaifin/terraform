# ============================================================================
# EBS CSI Driver - IAM Role & Policy
# ============================================================================

# 1. Create the IAM Role for the EBS CSI Driver
# We use the existing OIDC provider from your iam.tf file
resource "aws_iam_role" "ebs_csi_role" {
  name = "Fvrk-dev-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        # LINKING TO YOUR EXISTING OIDC PROVIDER
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Condition = {
        StringEquals = {
          # LINKING TO YOUR EXISTING OIDC URL
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa",
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud": "sts.amazonaws.com"
        }
      }
    }]
  })
}

# 2. Attach the official AWS EBS CSI Driver Policy to the Role
resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_role.name
}

# 3. Install the EKS Add-on for EBS CSI Driver
resource "aws_eks_addon" "ebs_csi" {
  # LINKING TO YOUR EXISTING CLUSTER RESOURCE
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  #addon_version            = "v1.34.2-eks-ecaa3a6" # Ensure this version matches your K8s version
  service_account_role_arn = aws_iam_role.ebs_csi_role.arn
  
  # Optional: ensure node groups are ready before installing
  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_policy_attachment
  ]
}