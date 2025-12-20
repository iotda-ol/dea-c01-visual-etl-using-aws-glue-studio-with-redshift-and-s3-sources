# Glue Catalog Database
resource "aws_glue_catalog_database" "etl_database" {
  name = "${var.project_name}_database_${var.environment}"
  
  description = "Database for visual ETL pipeline"
}

# Glue Catalog Table for Customers (S3 source 1)
resource "aws_glue_catalog_table" "customers" {
  name          = "customers"
  database_name = aws_glue_catalog_database.etl_database.name
  
  table_type = "EXTERNAL_TABLE"
  
  parameters = {
    "classification" = "csv"
    "skip.header.line.count" = "1"
  }
  
  storage_descriptor {
    location      = "s3://${aws_s3_bucket.source_data.bucket}/customers/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      
      parameters = {
        "field.delim" = ","
        "skip.header.line.count" = "1"
      }
    }
    
    columns {
      name = "customer_id"
      type = "string"
    }
    
    columns {
      name = "customer_name"
      type = "string"
    }
    
    columns {
      name = "email"
      type = "string"
    }
    
    columns {
      name = "country"
      type = "string"
    }
    
    columns {
      name = "signup_date"
      type = "string"
    }
  }
}

# Glue Catalog Table for Orders (S3 source 2)
resource "aws_glue_catalog_table" "orders" {
  name          = "orders"
  database_name = aws_glue_catalog_database.etl_database.name
  
  table_type = "EXTERNAL_TABLE"
  
  parameters = {
    "classification" = "csv"
    "skip.header.line.count" = "1"
  }
  
  storage_descriptor {
    location      = "s3://${aws_s3_bucket.source_data.bucket}/orders/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      
      parameters = {
        "field.delim" = ","
        "skip.header.line.count" = "1"
      }
    }
    
    columns {
      name = "order_id"
      type = "string"
    }
    
    columns {
      name = "customer_id"
      type = "string"
    }
    
    columns {
      name = "order_date"
      type = "string"
    }
    
    columns {
      name = "order_amount"
      type = "double"
    }
    
    columns {
      name = "order_status"
      type = "string"
    }
  }
}

# Glue Connection to Redshift
resource "aws_glue_connection" "redshift_connection" {
  name = "${var.project_name}-redshift-connection-${var.environment}"
  
  connection_type = "JDBC"
  
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://${aws_redshift_cluster.etl_cluster.endpoint}/${aws_redshift_cluster.etl_cluster.database_name}"
    USERNAME            = var.redshift_master_username
    PASSWORD            = var.redshift_master_password
  }
  
  physical_connection_requirements {
    availability_zone      = aws_subnet.private_1.availability_zone
    security_group_id_list = [aws_security_group.glue.id]
    subnet_id              = aws_subnet.private_1.id
  }
}

# Glue Visual ETL Job
resource "aws_glue_job" "visual_etl_job" {
  name     = "${var.project_name}-visual-etl-job-${var.environment}"
  role_arn = aws_iam_role.glue_role.arn
  
  glue_version      = var.glue_version
  worker_type       = var.glue_worker_type
  number_of_workers = var.glue_number_of_workers
  
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_scripts.bucket}/scripts/visual_etl_job.py"
    python_version  = "3"
  }
  
  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${aws_s3_bucket.glue_temp.bucket}/spark-logs/"
    "--enable-job-insights"              = "true"
    "--enable-glue-datacatalog"          = "true"
    "--TempDir"                          = "s3://${aws_s3_bucket.glue_temp.bucket}/temp/"
    "--enable-continuous-cloudwatch-log" = "true"
    "--datalake-formats"                 = "iceberg"
    
    # Custom arguments for the job
    "--source_database"                  = aws_glue_catalog_database.etl_database.name
    "--customers_table"                  = aws_glue_catalog_table.customers.name
    "--orders_table"                     = aws_glue_catalog_table.orders.name
    "--redshift_connection"              = aws_glue_connection.redshift_connection.name
    "--target_database"                  = aws_redshift_cluster.etl_cluster.database_name
    "--target_schema"                    = "public"
    "--target_table"                     = "customer_order_summary"
  }
  
  connections = [aws_glue_connection.redshift_connection.name]
  
  execution_property {
    max_concurrent_runs = 1
  }
  
  tags = {
    Name = "${var.project_name}-visual-etl-job-${var.environment}"
  }
}

# Data Quality Ruleset for customers table
resource "aws_glue_data_quality_ruleset" "customers_dq" {
  name = "${var.project_name}-customers-dq-${var.environment}"
  
  ruleset = <<-EOT
    Rules = [
      IsComplete "customer_id",
      IsUnique "customer_id",
      ColumnLength "customer_id" between 1 and 50,
      IsComplete "email",
      ColumnValues "email" matches "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
      ColumnValues "country" in ["USA", "UK", "Canada", "Australia", "Germany", "France"],
      ColumnLength "customer_name" between 2 and 100
    ]
  EOT
  
  target_table {
    database_name = aws_glue_catalog_database.etl_database.name
    table_name    = aws_glue_catalog_table.customers.name
  }
}

# Data Quality Ruleset for orders table
resource "aws_glue_data_quality_ruleset" "orders_dq" {
  name = "${var.project_name}-orders-dq-${var.environment}"
  
  ruleset = <<-EOT
    Rules = [
      IsComplete "order_id",
      IsUnique "order_id",
      IsComplete "customer_id",
      IsComplete "order_amount",
      ColumnValues "order_amount" > 0,
      ColumnValues "order_status" in ["pending", "completed", "cancelled", "shipped"],
      RowCount between 1 and 1000000
    ]
  EOT
  
  target_table {
    database_name = aws_glue_catalog_database.etl_database.name
    table_name    = aws_glue_catalog_table.orders.name
  }
}
