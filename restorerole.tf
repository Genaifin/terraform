resource "aws_iam_role" "backup_restore_role" {
  name = "EFS-Restore-Role"

  # This is the CRITICAL part your SSO role was missing:
  # It allows the Backup Service to assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the official AWS policy for Restores
resource "aws_iam_role_policy_attachment" "restore_policy" {
  role       = aws_iam_role.backup_restore_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}