terraform {
  backend "s3"{
    bucket                 = "mundose-alefinir"
    region                 = "us-east-2"
    key                    = "backend.tfstate"
    dynamodb_table         = "terraformstatelock"
  }
}

