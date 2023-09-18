terraform {
  backend "s3" {
    bucket         = "yon133"
    key            = "eks/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-2"
  }
}
