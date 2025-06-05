terraform {
  backend "s3"{
    bucket                 = "mundose-alefinir1"
    region                 = "us-east-1"
    key                    = "backend.tfstate"
    dynamodb_table         = "terraformstatelock"
  }
}

