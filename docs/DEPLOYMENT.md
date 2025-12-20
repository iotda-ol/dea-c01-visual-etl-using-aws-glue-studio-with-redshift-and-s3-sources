# Deployment Guide

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **AWS CLI** configured with credentials
4. **S3 Access** for storing source data and scripts

## Architecture Overview

This project deploys:
- **3 S3 Buckets**: Source data, Glue scripts, temporary data
- **Redshift Cluster**: Target data warehouse (single-node for dev)
- **VPC Infrastructure**: Private subnets, security groups, VPC endpoints
- **AWS Glue Resources**: Database, catalog tables, connections, visual ETL job
- **IAM Roles**: For Glue and Redshift with least-privilege policies
- **Data Quality Rules**: Automated validation for source data

## Step-by-Step Deployment

### 1. Clone the Repository

```bash
git clone <repository-url>
cd dea-c01-visual-etl-using-aws-glue-studio-with-redshift-and-s3-sources
```

### 2. Configure Variables

Create a `terraform.tfvars` file in the `terraform/` directory:

```hcl
aws_region                = "us-east-1"
environment               = "dev"
project_name              = "visual-etl-glue"
redshift_master_username  = "admin"
redshift_master_password  = "YourSecurePassword123!"  # Change this!
redshift_node_type        = "dc2.large"
redshift_number_of_nodes  = 1
glue_version              = "4.0"
glue_worker_type          = "G.1X"
glue_number_of_workers    = 2
```

**Security Note:** Never commit `terraform.tfvars` to version control. Use AWS Secrets Manager or Parameter Store for production.

### 3. Initialize Terraform

```bash
cd terraform
terraform init
```

### 4. Review the Deployment Plan

```bash
terraform plan
```

Review the resources that will be created:
- S3 buckets (3)
- VPC, subnets, security groups
- Redshift cluster
- Glue database, tables, connection
- Glue ETL job
- IAM roles and policies

### 5. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes approximately 10-15 minutes.

### 6. Upload Sample Data to S3

After deployment, upload sample data:

```bash
# Get bucket name from Terraform output
SOURCE_BUCKET=$(terraform output -raw source_bucket_name)

# Upload customers data
aws s3 cp ../sample-data/customers.csv s3://$SOURCE_BUCKET/customers/

# Upload orders data
aws s3 cp ../sample-data/orders.csv s3://$SOURCE_BUCKET/orders/
```

### 7. Upload Glue Script

```bash
# Get scripts bucket name
SCRIPTS_BUCKET=$(terraform output -raw glue_scripts_bucket_name)

# Upload the ETL script
aws s3 cp ../data/visual_etl_job.py s3://$SCRIPTS_BUCKET/scripts/
```

### 8. Create Target Table in Redshift

Connect to Redshift using your preferred SQL client:

**Connection Details:**
- Endpoint: `terraform output -raw redshift_cluster_endpoint`
- Database: `etl_database`
- Username: `admin` (or your configured username)
- Password: Your configured password

**Create Target Table:**

```sql
CREATE TABLE IF NOT EXISTS public.customer_order_summary (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_name VARCHAR(100),
    email VARCHAR(255),
    country VARCHAR(50),
    total_order_amount DECIMAL(10,2),
    order_count INTEGER,
    avg_order_amount DECIMAL(10,2),
    last_order_date VARCHAR(50)
)
SORTKEY(customer_id);
```

### 9. Run the Glue Job

#### Option A: AWS Console

1. Open AWS Glue Console
2. Navigate to **ETL Jobs** → **Visual ETL**
3. Find your job: `visual-etl-glue-visual-etl-job-dev`
4. Click **Run**
5. Monitor progress in the **Runs** tab

#### Option B: AWS CLI

```bash
JOB_NAME=$(terraform output -raw glue_job_name)

aws glue start-job-run --job-name $JOB_NAME
```

### 10. Verify Results

Query Redshift to verify data:

```sql
SELECT 
    customer_id,
    customer_name,
    country,
    total_order_amount,
    order_count,
    avg_order_amount
FROM public.customer_order_summary
ORDER BY total_order_amount DESC;
```

## Visual ETL Studio Workflow

To view and edit the visual workflow in AWS Glue Studio:

1. **Open Glue Studio Console**
   - Navigate to AWS Glue → Visual ETL

2. **Open the Job**
   - Click on your job name
   - The visual graph will display all nodes

3. **Visual Nodes in the Pipeline:**
   - **Node 1**: S3 Source (Customers) via Data Catalog
   - **Node 2**: S3 Source (Orders) via Data Catalog
   - **Node 3**: Evaluate Data Quality (Customers)
   - **Node 4**: Evaluate Data Quality (Orders)
   - **Node 5**: Filter (Completed Orders)
   - **Node 6**: Join (Customers + Orders)
   - **Node 7**: Aggregate (Custom Transform Node)
   - **Node 8**: Select Fields
   - **Node 9**: Redshift Target

4. **Editing the Workflow:**
   - Click any node to configure
   - Drag new nodes from the palette
   - Connect nodes by dragging arrows
   - Save changes

## Monitoring and Troubleshooting

### CloudWatch Logs

View Glue job logs:

```bash
aws logs tail /aws-glue/jobs/output --follow
aws logs tail /aws-glue/jobs/error --follow
```

### Data Quality Metrics

View data quality metrics in CloudWatch:
- Navigate to CloudWatch → Metrics → Glue
- Look for `glue.driver.aggregate.DataQuality` metrics

### Job Run History

```bash
JOB_NAME=$(terraform output -raw glue_job_name)

aws glue get-job-runs --job-name $JOB_NAME --max-results 5
```

### Common Issues

#### 1. Redshift Connection Timeout
**Cause:** Security group or network configuration
**Solution:** Verify Glue security group has access to Redshift security group on port 5439

#### 2. S3 Access Denied
**Cause:** IAM permissions
**Solution:** Verify Glue role has S3 read/write permissions

#### 3. Data Quality Failures
**Cause:** Data doesn't meet quality rules
**Solution:** Review DQ metrics in CloudWatch, check source data format

#### 4. Out of Memory Errors
**Cause:** Insufficient worker resources
**Solution:** Increase `glue_number_of_workers` or change `glue_worker_type` to G.2X

## Cost Optimization

### Development Environment
- Use single-node Redshift (dc2.large)
- Use G.1X workers with 2 workers
- Enable job bookmarking to avoid reprocessing
- Set S3 lifecycle policies for temp data (already configured)

### Production Environment
- Consider Redshift Serverless for variable workloads
- Use spot instances where possible (not available for Glue, but consider for EMR alternative)
- Enable CloudWatch metrics to monitor costs
- Use Glue job metrics to optimize DPU usage

### Estimated Monthly Costs (us-east-1)

**Development:**
- Redshift dc2.large: ~$180/month (on-demand, single-node)
- Glue ETL job: ~$0.44/DPU-hour (G.1X = 1 DPU)
  - Example: 2 workers × 0.5 hours/day × 30 days = ~$13/month
- S3 storage: ~$0.023/GB/month (negligible for sample data)
- Data transfer: Minimal (within same region)

**Total Development:** ~$195-200/month

**Cost Reduction Tips:**
- Stop Redshift cluster when not in use: `terraform destroy` or pause cluster
- Use Terraform to easily tear down and recreate environment
- Consider AWS Glue Development Endpoints only when actively developing

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted.

**Note:** This will delete:
- All S3 buckets and their contents
- Redshift cluster (final snapshot skipped by default)
- VPC and networking resources
- Glue database, tables, and jobs
- IAM roles and policies

## Production Considerations

### Security Enhancements

1. **Secrets Management**
   ```hcl
   # Use AWS Secrets Manager for Redshift credentials
   data "aws_secretsmanager_secret_version" "redshift_creds" {
     secret_id = "prod/redshift/credentials"
   }
   ```

2. **Encryption**
   - Enable S3 bucket encryption with KMS (upgrade from AES256)
   - Use encrypted Redshift cluster (already enabled)
   - Encrypt Glue job bookmarks

3. **Network Security**
   - Use private VPC endpoints for all AWS services
   - Implement VPC flow logs
   - Use AWS PrivateLink for Redshift

4. **IAM Best Practices**
   - Use IAM roles with minimal permissions
   - Enable CloudTrail for audit logging
   - Implement resource-based policies

### High Availability

1. **Redshift**
   - Multi-node cluster for production
   - Automated snapshots
   - Cross-region snapshot copy

2. **S3**
   - Enable versioning (already configured)
   - Cross-region replication for critical data
   - Implement S3 Intelligent-Tiering

3. **Glue Jobs**
   - Configure retries and timeout
   - Implement error handling
   - Set up SNS notifications for failures

### Monitoring and Alerting

```hcl
# Example CloudWatch alarm for Glue job failures
resource "aws_cloudwatch_metric_alarm" "glue_job_failure" {
  alarm_name          = "glue-job-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "Glue"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

## Next Steps

1. **Customize the ETL Logic**
   - Modify transformations in Glue Studio UI
   - Add custom transform nodes for complex logic
   - Implement incremental loading

2. **Add More Data Sources**
   - Configure additional S3 sources
   - Add RDS or DynamoDB connections
   - Integrate with external APIs

3. **Implement CI/CD**
   - Use GitHub Actions or AWS CodePipeline
   - Automate Terraform deployments
   - Version control Glue scripts

4. **Enhance Data Quality**
   - Add more DQ rules
   - Implement custom DQ checks
   - Set up automated remediation

5. **Optimize Performance**
   - Analyze Spark UI logs
   - Tune partition strategies
   - Implement caching where appropriate
