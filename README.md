# Visual ETL Pipeline using AWS Glue Studio with Redshift and S3 Sources

[![AWS](https://img.shields.io/badge/AWS-Glue%20Studio-orange)](https://aws.amazon.com/glue/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![DEA-C01](https://img.shields.io/badge/AWS-DEA--C01-blue)](https://aws.amazon.com/certification/certified-data-engineer-associate/)

This repository demonstrates how to build a **visual, low-code ETL pipeline** using AWS Glue Studio with Infrastructure as Code (Terraform). The pipeline reads data from multiple Amazon S3 sources, performs joins, aggregations, and data quality checks, and loads results into Amazon Redshift.

## 🎯 Project Goals

- Build a production-ready visual ETL pipeline using AWS Glue Studio
- Demonstrate Terraform-based infrastructure deployment
- Implement comprehensive data quality validation
- Showcase AWS Certified Data Engineer - Associate (DEA-C01) best practices
- Document limitations of visual ETL vs. custom PySpark code
- Provide clear guidance on when to use visual vs. scripted approaches

## 📋 Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [ETL Pipeline Details](#etl-pipeline-details)
- [Visual ETL Limitations](#visual-etl-limitations)
- [Documentation](#documentation)
- [Cost Estimates](#cost-estimates)
- [Contributing](#contributing)

## 🏗️ Architecture

The solution implements a complete ETL pipeline with the following components:

```
S3 Sources (Customers & Orders)
    ↓
AWS Glue Data Catalog
    ↓
AWS Glue Visual ETL Job
    ├── Data Quality Validation
    ├── Join Transformation
    ├── Aggregation
    └── Field Selection
    ↓
Amazon Redshift (Analytics)
```

**Key Components:**
- **3 S3 Buckets**: Source data, Glue scripts, temporary storage
- **AWS Glue Database**: Centralized metadata catalog
- **2 Catalog Tables**: Customers and Orders
- **Glue Connection**: JDBC connection to Redshift
- **Visual ETL Job**: 9-node pipeline with data quality checks
- **Redshift Cluster**: Single-node development cluster (scalable to multi-node)
- **VPC Infrastructure**: Private subnets, security groups, VPC endpoints
- **IAM Roles**: Least-privilege access for Glue and Redshift

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture documentation.

## ✨ Features

### Visual ETL Capabilities
- ✅ **Drag-and-drop ETL development** in AWS Glue Studio
- ✅ **Multiple S3 sources** with Glue Data Catalog integration
- ✅ **Built-in data quality checks** with customizable rules
- ✅ **Visual transformations**: Join, Filter, Aggregate, Select Fields
- ✅ **Redshift integration** via JDBC connections
- ✅ **Auto-generated PySpark code** for transparency

### Infrastructure & DevOps
- ✅ **Terraform-based deployment** for reproducible infrastructure
- ✅ **VPC and network security** with private subnets
- ✅ **Comprehensive monitoring** with CloudWatch logs and metrics
- ✅ **Job bookmarking** for incremental processing
- ✅ **Spark UI integration** for performance analysis

### Data Quality
- ✅ **Automated validation rules**: Completeness, uniqueness, format checks
- ✅ **Row-level data quality** outcomes tracking
- ✅ **CloudWatch metrics** for DQ monitoring
- ✅ **Configurable thresholds** for data quality acceptance

### Security
- ✅ **Encryption at rest**: S3 and Redshift
- ✅ **Encryption in transit**: JDBC/SSL connections
- ✅ **IAM role-based access** with least privilege
- ✅ **VPC isolation** with no public internet access
- ✅ **Security groups** for fine-grained network control

## 📦 Prerequisites

Before deploying this solution, ensure you have:

1. **AWS Account** with administrative access
2. **Terraform** >= 1.0 installed ([Download](https://www.terraform.io/downloads))
3. **AWS CLI** configured with credentials ([Setup Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html))
4. **Basic knowledge** of:
   - AWS Glue and ETL concepts
   - Amazon S3 and Redshift
   - Terraform basics
   - SQL for querying Redshift

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/iotda-ol/dea-c01-visual-etl-using-aws-glue-studio-with-redshift-and-s3-sources.git
cd dea-c01-visual-etl-using-aws-glue-studio-with-redshift-and-s3-sources
```

### 2. Configure Terraform Variables

Create `terraform/terraform.tfvars`:

```hcl
aws_region                = "us-east-1"
environment               = "dev"
project_name              = "visual-etl-glue"
redshift_master_username  = "admin"
redshift_master_password  = "YourSecurePassword123!"  # Change this!
```

### 3. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Deployment takes approximately **10-15 minutes**.

### 4. Upload Sample Data

```bash
SOURCE_BUCKET=$(terraform output -raw source_bucket_name)
aws s3 cp ../sample-data/customers.csv s3://$SOURCE_BUCKET/customers/
aws s3 cp ../sample-data/orders.csv s3://$SOURCE_BUCKET/orders/
```

### 5. Upload Glue Script

```bash
SCRIPTS_BUCKET=$(terraform output -raw glue_scripts_bucket_name)
aws s3 cp ../data/visual_etl_job.py s3://$SCRIPTS_BUCKET/scripts/
```

### 6. Create Redshift Table

Connect to Redshift and run:

```sql
CREATE TABLE public.customer_order_summary (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_name VARCHAR(100),
    email VARCHAR(255),
    country VARCHAR(50),
    total_order_amount DECIMAL(10,2),
    order_count INTEGER,
    avg_order_amount DECIMAL(10,2),
    last_order_date VARCHAR(50)
) SORTKEY(customer_id);
```

### 7. Run the ETL Job

```bash
JOB_NAME=$(terraform output -raw glue_job_name)
aws glue start-job-run --job-name $JOB_NAME
```

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment instructions.

## 📁 Project Structure

```
.
├── README.md                          # This file
├── .gitignore                         # Git ignore rules
├── terraform/                         # Infrastructure as Code
│   ├── providers.tf                   # Terraform and AWS provider config
│   ├── variables.tf                   # Input variables
│   ├── outputs.tf                     # Output values
│   ├── s3.tf                          # S3 bucket resources
│   ├── iam.tf                         # IAM roles and policies
│   ├── vpc.tf                         # VPC, subnets, security groups
│   ├── redshift.tf                    # Redshift cluster configuration
│   └── glue.tf                        # Glue database, tables, jobs
├── data/                              # ETL scripts
│   └── visual_etl_job.py              # Generated Glue Studio script
├── sample-data/                       # Sample source data
│   ├── customers.csv                  # Customer data
│   └── orders.csv                     # Orders data
└── docs/                              # Documentation
    ├── ARCHITECTURE.md                # Architecture details
    ├── DEPLOYMENT.md                  # Deployment guide
    ├── VISUAL_ETL_LIMITATIONS.md      # Limitations & when to use custom code
    └── DEA_C01_BEST_PRACTICES.md      # DEA-C01 exam best practices
```

## 🔄 ETL Pipeline Details

### Data Sources

**Customers (S3)**
- Customer ID, Name, Email, Country, Signup Date
- Format: CSV with headers
- Location: `s3://bucket/customers/`

**Orders (S3)**
- Order ID, Customer ID, Date, Amount, Status
- Format: CSV with headers
- Location: `s3://bucket/orders/`

### Visual ETL Workflow

The pipeline consists of 9 visual nodes:

1. **S3 Source (Customers)** - Read customer data via Glue Catalog
2. **S3 Source (Orders)** - Read orders data via Glue Catalog
3. **Data Quality (Customers)** - Validate customer data (completeness, format)
4. **Data Quality (Orders)** - Validate order data (completeness, ranges)
5. **Filter** - Keep only completed orders
6. **Join** - Inner join customers and orders on customer_id
7. **Aggregate** - Calculate total/average order amounts per customer
8. **Select Fields** - Choose final output columns
9. **Redshift Target** - Write results to Redshift table

### Transformations

**Data Quality Rules:**
- Customer ID: Complete, Unique, Length validation
- Email: Format validation with regex
- Order Amount: Must be > 0
- Order Status: Must be in predefined list

**Aggregations:**
- Total order amount per customer
- Order count per customer
- Average order amount
- Last order date

## ⚠️ Visual ETL Limitations

While AWS Glue Studio's visual interface is powerful for standard ETL workflows, it has limitations compared to custom PySpark code:

### ✅ Visual ETL Works Well For:
- Simple joins (equi-joins on single keys)
- Basic aggregations (sum, count, avg, min, max)
- Simple filters (equality, comparison)
- Field selection and renaming
- Standard data quality checks

### ❌ Custom Code Required For:
- **Complex aggregations**: Percentiles, stddev, collect_list
- **Window functions**: Ranking, running totals, lag/lead
- **Complex filtering**: Multi-condition boolean logic
- **String operations**: Regex, split, concat, substring
- **Conditional logic**: Case/when statements, nested conditions
- **Array/Map operations**: Explode, array manipulation
- **Custom UDFs**: Business-specific transformations
- **Performance tuning**: Repartition, broadcast joins, caching
- **Advanced Spark features**: Custom partitioning, skew handling

### Hybrid Approach (Recommended)

For optimal results, combine visual ETL nodes with custom transform nodes:

```
[Visual] S3 Source → Data Quality
    ↓
[Custom Code] Complex Window Function Aggregation
    ↓
[Visual] Select Fields → Redshift Target
```

See [VISUAL_ETL_LIMITATIONS.md](docs/VISUAL_ETL_LIMITATIONS.md) for comprehensive details.

## 📚 Documentation

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Detailed architecture, component descriptions, data flow
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Step-by-step deployment guide, troubleshooting, cost optimization
- **[VISUAL_ETL_LIMITATIONS.md](docs/VISUAL_ETL_LIMITATIONS.md)** - Comprehensive comparison of visual vs. custom ETL
- **[DEA_C01_BEST_PRACTICES.md](docs/DEA_C01_BEST_PRACTICES.md)** - AWS DEA-C01 exam best practices and patterns

## 💰 Cost Estimates

**Development Environment (us-east-1):**

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| Redshift | dc2.large, single-node | ~$180 |
| Glue ETL | 2 DPUs, 0.5 hrs/day | ~$13 |
| S3 Storage | <1 GB | <$1 |
| Data Transfer | Within region | Minimal |
| **Total** | | **~$195/month** |

**Cost Optimization Tips:**
- Pause Redshift cluster when not in use
- Use `terraform destroy` to tear down entire environment
- Enable job bookmarking to avoid reprocessing data
- Use S3 lifecycle policies (already configured)

**Production Scaling:**
- Multi-node Redshift cluster: $180-$1,800+/month
- Increased Glue workers: $0.44/DPU-hour
- Consider Redshift Serverless for variable workloads

## 🔒 Security Best Practices

This project implements DEA-C01 security best practices:

- ✅ Encryption at rest (S3, Redshift)
- ✅ Encryption in transit (SSL/TLS)
- ✅ IAM roles with least privilege
- ✅ Private subnets for compute resources
- ✅ Security groups with minimal access
- ✅ VPC endpoints for AWS services
- ✅ No hardcoded credentials
- ✅ CloudTrail logging (enable separately)

**Production Recommendations:**
- Use AWS Secrets Manager for credentials
- Implement KMS customer-managed keys
- Enable AWS Config for compliance
- Use AWS Lake Formation for fine-grained access

## 🧪 Testing

Run the sample ETL job:

```bash
# Start job
JOB_NAME=$(terraform output -raw glue_job_name)
RUN_ID=$(aws glue start-job-run --job-name $JOB_NAME --query 'JobRunId' --output text)

# Check status
aws glue get-job-run --job-name $JOB_NAME --run-id $RUN_ID

# View logs
aws logs tail /aws-glue/jobs/output --follow
```

Verify results in Redshift:

```sql
SELECT * FROM public.customer_order_summary ORDER BY total_order_amount DESC;
```

## 🧹 Cleanup

To avoid ongoing charges, destroy all resources:

```bash
cd terraform
terraform destroy
```

This deletes all S3 buckets, Redshift cluster, VPC, and Glue resources.

## 📖 Learning Resources

### AWS Glue Studio
- [AWS Glue Studio Documentation](https://docs.aws.amazon.com/glue/latest/ug/what-is-glue-studio.html)
- [Visual ETL Best Practices](https://docs.aws.amazon.com/glue/latest/ug/glue-best-practices-visual.html)
- [Glue Data Quality](https://docs.aws.amazon.com/glue/latest/dg/glue-data-quality.html)

### DEA-C01 Certification
- [AWS Certified Data Engineer - Associate](https://aws.amazon.com/certification/certified-data-engineer-associate/)
- [Exam Guide](https://d1.awsstatic.com/training-and-certification/docs-data-engineer-associate/AWS-Certified-Data-Engineer-Associate_Exam-Guide.pdf)

### Terraform
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## 📄 License

This project is provided as-is for educational and reference purposes.

## 🙏 Acknowledgments

- AWS Glue Studio team for the visual ETL platform
- Terraform community for AWS provider
- DEA-C01 study community for best practices

---

**Built with ❤️ for AWS Data Engineers**

For questions or feedback, please open an issue in this repository.
