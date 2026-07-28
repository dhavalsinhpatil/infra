# Fill in bucket/dynamodb_table with the outputs from `bootstrap` after
# running it once. terraform init -backend-config values can also be
# passed via CLI/CI instead of hardcoding here.
terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_STATE_BUCKET_NAME"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "employee-management-terraform-locks"
    encrypt        = true
  }
}
