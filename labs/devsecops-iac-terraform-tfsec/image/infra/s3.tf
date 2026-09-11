provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "dados" {
  bucket = "codisec-lab-exemplo-bucket"
}

# VULNERÁVEL: nenhum aws_s3_bucket_public_access_block associado —
# o bucket fica sujeito a ACLs/policies públicas sem bloqueio nenhum.
