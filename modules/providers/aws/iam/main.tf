##############################################################
#
# IAM Role for ECR
#
##############################################################


resource "aws_iam_role" "ecr_iam_role" {
  name = "ecr_iam_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ecr_iam_policy" {
  name        = "ecr_iam_policy"
  description = "IAM policy for ecr instance"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-2:*:secret:portfolio-dev-backend-secrets*",
        "arn:aws:secretsmanager:us-east-2:*:secret:cloudflare-dev-tunnel*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecr_iam_role_policy_attachment" {
  policy_arn = aws_iam_policy.ecr_iam_policy.arn
  role       = aws_iam_role.ecr_iam_role.name
}
