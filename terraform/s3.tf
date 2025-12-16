# S3 bucket for source data
resource "aws_s3_bucket" "source_data" {
  bucket = "${var.project_name}-source-data-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "source_data" {
  bucket = aws_s3_bucket.source_data.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "source_data" {
  bucket = aws_s3_bucket.source_data.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket for Glue scripts
resource "aws_s3_bucket" "glue_scripts" {
  bucket = "${var.project_name}-glue-scripts-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "glue_scripts" {
  bucket = aws_s3_bucket.glue_scripts.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "glue_scripts" {
  bucket = aws_s3_bucket.glue_scripts.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket for Glue temporary data
resource "aws_s3_bucket" "glue_temp" {
  bucket = "${var.project_name}-glue-temp-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_lifecycle_configuration" "glue_temp" {
  bucket = aws_s3_bucket.glue_temp.id

  rule {
    id     = "delete-old-temp-files"
    status = "Enabled"

    expiration {
      days = 7
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "glue_temp" {
  bucket = aws_s3_bucket.glue_temp.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Data source to get AWS account ID
data "aws_caller_identity" "current" {}
