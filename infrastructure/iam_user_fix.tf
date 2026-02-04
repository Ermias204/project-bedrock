# Data source for existing IAM user (created manually)
data "aws_iam_user" "dev_view" {
  user_name = "bedrock-dev-view-final"
}

# Use the existing user for access keys
resource "aws_iam_access_key" "dev_view" {
  user = data.aws_iam_user.dev_view.user_name
}

# Attach ReadOnlyAccess policy to existing user
resource "aws_iam_user_policy_attachment" "dev_view_readonly" {
  user       = data.aws_iam_user.dev_view.user_name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
