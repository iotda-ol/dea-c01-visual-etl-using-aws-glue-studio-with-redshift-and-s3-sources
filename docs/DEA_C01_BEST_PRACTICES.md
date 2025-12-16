# DEA-C01 Best Practices for Visual ETL with AWS Glue Studio

## Overview

This document outlines AWS Certified Data Engineer - Associate (DEA-C01) best practices for building ETL pipelines using AWS Glue Studio. These practices align with the exam objectives and real-world data engineering requirements.

## Domain 1: Data Ingestion and Transformation

### 1.1 Choose Appropriate Ingestion Methods

#### Best Practice: Use AWS Glue Data Catalog for Data Discovery
**Why:** Centralized metadata repository improves data governance and enables multiple services to access data with consistent schema.

**Implementation:**
```terraform
resource "aws_glue_catalog_table" "customers" {
  name          = "customers"
  database_name = aws_glue_catalog_database.etl_database.name
  table_type    = "EXTERNAL_TABLE"
  # Schema and storage descriptor
}
```

**Benefits:**
- Schema versioning and evolution
- Integration with Athena, Redshift Spectrum, EMR
- Central source of truth for metadata

#### Best Practice: Use S3 as Data Lake Storage
**Why:** S3 provides durable, scalable, and cost-effective storage for data lakes.

**Implementation:**
- Separate buckets for source, scripts, and temporary data
- Enable versioning for data protection
- Implement lifecycle policies for cost optimization

### 1.2 Design Efficient Transformation Pipelines

#### Best Practice: Implement Data Quality Checks Early
**Why:** Catch data quality issues before expensive transformations or loading to target systems.

**Implementation:**
```python
customers_dq_result = EvaluateDataQuality.apply(
    frame=customers_source,
    ruleset=customers_dq_ruleset,
    publishing_options={
        "enableDataQualityCloudWatchMetrics": True,
        "enableDataQualityResultsPublishing": True
    }
)
```

**DEA-C01 Key Points:**
- Validate completeness, uniqueness, and format
- Publish metrics to CloudWatch for monitoring
- Separate failed records for analysis

#### Best Practice: Use Visual ETL for Standard Transformations
**Why:** Faster development, easier maintenance, visual documentation.

**When to Use:**
- Joins, filters, aggregations with simple conditions
- Standard data type conversions
- Field selection and renaming

**When to Use Custom Code:**
- Window functions, complex aggregations
- Custom business logic
- Advanced Spark optimizations

### 1.3 Handle Schema Evolution

#### Best Practice: Use Glue Schema Registry or Catalog Updates
**Why:** Maintain backward compatibility and track schema changes over time.

**Implementation:**
```terraform
# Glue Catalog automatically tracks schema versions
# Use crawler for automatic schema discovery
resource "aws_glue_crawler" "source_data" {
  name          = "source-data-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.etl_database.name
  
  s3_target {
    path = "s3://${aws_s3_bucket.source_data.bucket}/"
  }
}
```

## Domain 2: Data Store Management

### 2.1 Choose Appropriate Data Stores

#### Best Practice: Use Redshift for Analytics Workloads
**Why:** Optimized for complex queries and aggregations on large datasets.

**DEA-C01 Key Decision Factors:**
- **Redshift**: Complex queries, joins, aggregations (OLAP)
- **RDS**: Transactional workloads (OLTP)
- **DynamoDB**: Key-value lookups, high throughput
- **S3**: Data lake, raw data storage

**Implementation:**
```terraform
resource "aws_redshift_cluster" "etl_cluster" {
  cluster_identifier = "etl-cluster"
  node_type         = "dc2.large"
  encrypted         = true  # Required for compliance
  # Multi-AZ deployment for production
}
```

### 2.2 Optimize Data Storage

#### Best Practice: Use Columnar Storage in Redshift
**Why:** Faster query performance and better compression for analytical queries.

**Implementation:**
```sql
-- Use SORTKEY for frequently filtered columns
CREATE TABLE customer_order_summary (
    customer_id VARCHAR(50) PRIMARY KEY,
    total_order_amount DECIMAL(10,2),
    order_count INTEGER
)
SORTKEY(customer_id);

-- Use DISTKEY for join optimization
DISTKEY(customer_id);
```

#### Best Practice: Partition S3 Data
**Why:** Reduce data scanned, improve query performance, lower costs.

**Implementation:**
```
s3://bucket/orders/
  year=2023/
    month=01/
    month=02/
  year=2024/
    month=01/
```

## Domain 3: Data Operations and Support

### 3.1 Implement Monitoring and Logging

#### Best Practice: Enable Comprehensive Logging
**Why:** Troubleshoot issues, audit data processing, meet compliance requirements.

**Implementation:**
```terraform
# Glue job with logging enabled
resource "aws_glue_job" "visual_etl_job" {
  default_arguments = {
    "--enable-metrics"                   = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://bucket/spark-logs/"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-job-insights"              = "true"
  }
}
```

**DEA-C01 Monitoring Components:**
- CloudWatch Logs for job execution
- CloudWatch Metrics for performance
- Spark UI for detailed Spark analysis
- Data Quality metrics

#### Best Practice: Set Up Alerts for Job Failures
**Why:** Proactive issue detection and faster incident response.

**Implementation:**
```terraform
resource "aws_cloudwatch_metric_alarm" "glue_job_failure" {
  alarm_name          = "glue-job-failure"
  comparison_operator = "GreaterThanThreshold"
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  threshold           = "0"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

### 3.2 Implement Job Orchestration

#### Best Practice: Use Job Bookmarks for Incremental Processing
**Why:** Avoid reprocessing data, reduce costs, improve performance.

**Implementation:**
```terraform
resource "aws_glue_job" "visual_etl_job" {
  default_arguments = {
    "--job-bookmark-option" = "job-bookmark-enable"
  }
}
```

**How It Works:**
- Glue tracks processed files/partitions
- Only new data is processed on subsequent runs
- State stored in Glue Data Catalog

#### Best Practice: Use AWS Step Functions for Complex Workflows
**Why:** Orchestrate multiple jobs, handle dependencies, implement error handling.

**Use Cases:**
- Multi-stage ETL pipelines
- Conditional job execution
- Parallel processing with coordination
- Error handling and retries

### 3.3 Optimize Performance

#### Best Practice: Right-Size Glue Workers
**Why:** Balance cost and performance based on workload requirements.

**DEA-C01 Worker Types:**
- **G.025X**: Light workloads, small datasets
- **G.1X**: Standard workloads (4 vCPU, 16 GB)
- **G.2X**: Heavy transformations, large datasets (8 vCPU, 32 GB)

**Decision Factors:**
- Data volume
- Transformation complexity
- Performance requirements
- Budget constraints

#### Best Practice: Use Pushdown Predicates
**Why:** Reduce data transferred and processed by filtering at source.

**Implementation:**
```python
# Filter pushed down to S3/Redshift
datasource = glueContext.create_dynamic_frame.from_catalog(
    database="db",
    table_name="table",
    push_down_predicate="year='2024' and month='01'"
)
```

## Domain 4: Data Security and Governance

### 4.1 Implement Data Encryption

#### Best Practice: Encrypt Data at Rest and in Transit
**Why:** Protect sensitive data, meet compliance requirements (GDPR, HIPAA, etc.).

**Implementation:**
```terraform
# S3 encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "source_data" {
  bucket = aws_s3_bucket.source_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"  # Use KMS for production
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
  }
}

# Redshift encryption
resource "aws_redshift_cluster" "etl_cluster" {
  encrypted         = true
  kms_key_id        = aws_kms_key.redshift_key.arn
}

# Glue job bookmark encryption
resource "aws_glue_security_configuration" "etl_security" {
  name = "etl-security-config"
  
  encryption_configuration {
    s3_encryption {
      s3_encryption_mode = "SSE-KMS"
      kms_key_arn        = aws_kms_key.s3_key.arn
    }
    
    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "CSE-KMS"
      kms_key_arn                   = aws_kms_key.glue_key.arn
    }
  }
}
```

### 4.2 Implement Access Control

#### Best Practice: Use IAM Roles with Least Privilege
**Why:** Minimize security risk, follow AWS security best practices.

**Implementation:**
```terraform
# Minimal permissions for Glue role
resource "aws_iam_role_policy" "glue_s3_policy" {
  policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject"]
        Resource = [
          "${aws_s3_bucket.source_data.arn}/*",
          "${aws_s3_bucket.glue_temp.arn}/*"
        ]
      }
    ]
  })
}
```

**DEA-C01 Security Principles:**
- Grant minimum necessary permissions
- Use resource-level restrictions
- Avoid wildcard (*) permissions
- Regular access reviews

#### Best Practice: Use AWS Secrets Manager for Credentials
**Why:** Avoid hardcoded credentials, enable rotation, audit access.

**Implementation:**
```terraform
# Store Redshift credentials in Secrets Manager
resource "aws_secretsmanager_secret" "redshift_creds" {
  name = "redshift/credentials"
}

# Reference in Glue connection
resource "aws_glue_connection" "redshift_connection" {
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://..."
    SECRET_ID           = aws_secretsmanager_secret.redshift_creds.arn
  }
}
```

### 4.3 Implement Data Governance

#### Best Practice: Use Glue Data Catalog for Centralized Metadata
**Why:** Central governance, consistent access control, data discovery.

**DEA-C01 Data Catalog Benefits:**
- Schema discovery and versioning
- Resource-based access policies
- Integration with Lake Formation
- Searchable metadata

#### Best Practice: Implement Fine-Grained Access with Lake Formation
**Why:** Column-level and row-level security, centralized permissions.

**Use Cases:**
- PII data masking
- Department-level data access
- Compliance requirements (GDPR, CCPA)

## Domain 5: DEA-C01 Exam-Specific Topics

### 5.1 When to Use Glue vs. EMR

#### AWS Glue (Serverless)
**Use When:**
- Standard ETL transformations
- Serverless architecture preferred
- Pay-per-use pricing model
- Quick setup and deployment

#### Amazon EMR
**Use When:**
- Custom Spark applications
- Long-running clusters
- Machine learning workloads
- Cost optimization for large-scale processing

### 5.2 Glue Job Types

#### Python Shell Jobs
**Use For:**
- Lightweight transformations
- API integrations
- Non-Spark workloads
**Cost:** Lower than Spark jobs

#### PySpark Jobs (Visual ETL)
**Use For:**
- Large-scale data transformations
- Join, aggregate, filter operations
- S3, Redshift, RDS integration
**Cost:** Based on DPU hours

#### Streaming Jobs
**Use For:**
- Real-time data processing
- Kinesis, Kafka integration
- Micro-batch processing

### 5.3 Data Quality Considerations

#### DEA-C01 Data Quality Checks
1. **Completeness**: No null values in required fields
2. **Uniqueness**: Primary key constraints
3. **Validity**: Value within expected range
4. **Consistency**: Cross-field validation
5. **Accuracy**: Match reference data

**Implementation Strategy:**
```python
# Use Glue Data Quality rules
ruleset = """
    Rules = [
        IsComplete "customer_id",
        IsUnique "customer_id",
        ColumnValues "order_amount" > 0,
        ColumnValues "email" matches "[regex]",
        RowCount between 1000 and 100000
    ]
"""
```

### 5.4 Cost Optimization Strategies

#### Best Practice: Optimize Glue Job Execution
1. **Use appropriate worker types** (don't over-provision)
2. **Enable job bookmarks** (avoid reprocessing)
3. **Use partition filters** (reduce data scanned)
4. **Optimize file sizes** (avoid small files)
5. **Schedule during off-peak** (if applicable)

#### Cost Comparison Example
**Scenario:** Process 1 TB daily
- **Glue (2 DPUs, 1 hour/day)**: ~$0.44 × 2 × 30 = $26.40/month
- **EMR (m5.xlarge, 1 hour/day)**: ~$0.192 × 1 × 30 = $5.76/month + overhead

**Choose Glue for:** Sporadic jobs, serverless, quick setup
**Choose EMR for:** Continuous processing, custom apps, cost-sensitive at scale

## Quick Reference: DEA-C01 Decision Matrix

| Requirement | Solution |
|-------------|----------|
| Visual ETL development | AWS Glue Studio |
| Complex Spark code | Custom PySpark or EMR |
| Real-time processing | Glue Streaming or Kinesis |
| Batch ETL | Glue batch jobs |
| Analytics queries | Redshift |
| Transactional DB | RDS |
| Key-value store | DynamoDB |
| Data lake storage | S3 |
| Metadata catalog | Glue Data Catalog |
| Data quality checks | Glue Data Quality |
| Job orchestration | Step Functions |
| Fine-grained access | Lake Formation |
| Serverless queries | Athena |

## Exam Tips

1. **Understand service limits**: Glue concurrent runs, Redshift nodes, etc.
2. **Know pricing models**: DPU-hours for Glue, node-hours for Redshift
3. **Security patterns**: Encryption, IAM roles, VPC configurations
4. **Performance optimization**: Partitioning, compression, file formats
5. **Integration patterns**: When services work together vs. separately

## Common Pitfalls to Avoid

1. ❌ **Using visual ETL for complex transformations**
   - Use custom PySpark code for advanced logic

2. ❌ **Not enabling job bookmarks**
   - Results in reprocessing all data every run

3. ❌ **Insufficient worker resources**
   - Causes out-of-memory errors, slow processing

4. ❌ **Not implementing data quality checks**
   - Bad data propagates to downstream systems

5. ❌ **Hardcoding credentials**
   - Security risk, use Secrets Manager

6. ❌ **Ignoring monitoring**
   - Unable to troubleshoot issues or optimize

7. ❌ **Not using VPC for sensitive data**
   - Exposes data to public internet

8. ❌ **Over-provisioning resources**
   - Unnecessary costs

## Summary

This visual ETL pipeline demonstrates DEA-C01 best practices:
- ✅ Visual ETL for standard transformations
- ✅ Custom code for complex aggregations
- ✅ Data quality checks with automated rules
- ✅ Secure network configuration (VPC, security groups)
- ✅ Encryption at rest and in transit
- ✅ IAM roles with least privilege
- ✅ Comprehensive monitoring and logging
- ✅ Job bookmarking for incremental processing
- ✅ Cost-optimized resource configuration
- ✅ Scalable architecture

Use this as a reference implementation for DEA-C01 exam preparation and real-world data engineering projects.
