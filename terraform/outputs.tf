output "source_bucket_name" {
  description = "Name of the S3 bucket for source data"
  value       = aws_s3_bucket.source_data.id
}

output "glue_scripts_bucket_name" {
  description = "Name of the S3 bucket for Glue scripts"
  value       = aws_s3_bucket.glue_scripts.id
}

output "glue_temp_bucket_name" {
  description = "Name of the S3 bucket for Glue temporary data"
  value       = aws_s3_bucket.glue_temp.id
}

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = aws_glue_catalog_database.etl_database.name
}

output "glue_job_name" {
  description = "Name of the Glue visual ETL job"
  value       = aws_glue_job.visual_etl_job.name
}

output "glue_connection_name" {
  description = "Name of the Glue connection to Redshift"
  value       = aws_glue_connection.redshift_connection.name
}

output "redshift_cluster_endpoint" {
  description = "Endpoint of the Redshift cluster"
  value       = aws_redshift_cluster.etl_cluster.endpoint
}

output "redshift_cluster_id" {
  description = "ID of the Redshift cluster"
  value       = aws_redshift_cluster.etl_cluster.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role for Glue"
  value       = aws_iam_role.glue_role.arn
}
