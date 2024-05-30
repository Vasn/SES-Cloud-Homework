terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "website" {
  bucket = "website-bucket-1009"

  tags = {
    Name        = "Website bucket"
    Environment = "Prod"
  }
}

resource "aws_s3_bucket_ownership_controls" "website_ownership" {
  bucket = aws_s3_bucket.website.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "unblock_policy" {
  bucket = aws_s3_bucket.website.id

  block_public_policy     = false // unblock public policy
  restrict_public_buckets = false // same as above
  block_public_acls       = false
  ignore_public_acls      = false
}


resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website.bucket

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "website_files" {
  for_each = { for file in fileset("${path.module}/../", "**") : file => file if !can(regex("^terraform-deployment($|/)", file)) && file != ".git" }

  bucket = aws_s3_bucket.website.bucket
  key    = each.key
  source = "${path.module}/../${each.key}"

  content_type = lookup({
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "gif"  = "image/gif"
    "ico"  = "image/x-icon"
    "svg"  = "image/svg+xml"
  }, split(".", each.key)[length(split(".", each.key)) - 1], "application/octet-stream")

}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website.bucket 

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"  # ARN of your S3 bucket
      }
    ]
  })

  depends_on = [ aws_s3_bucket_public_access_block.unblock_policy ]
}

output "website_url" {
  value = "${aws_s3_bucket.website.bucket}.${aws_s3_bucket_website_configuration.website_config.website_domain}"
}