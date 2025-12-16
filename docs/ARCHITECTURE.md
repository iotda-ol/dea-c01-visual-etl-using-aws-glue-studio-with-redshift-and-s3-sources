# Architecture Documentation

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           AWS Cloud Environment                          │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                        VPC (10.0.0.0/16)                        │    │
│  │                                                                  │    │
│  │  ┌─────────────────┐         ┌─────────────────┐              │    │
│  │  │  Private Subnet  │         │  Private Subnet  │              │    │
│  │  │   10.0.1.0/24   │         │   10.0.2.0/24   │              │    │
│  │  │   (AZ-1)        │         │   (AZ-2)        │              │    │
│  │  │                 │         │                 │              │    │
│  │  │  ┌───────────┐  │         │                 │              │    │
│  │  │  │  Glue Job │  │         │  ┌───────────┐  │              │    │
│  │  │  │  (ENI)    │──┼─────────┼──│ Redshift  │  │              │    │
│  │  │  └───────────┘  │         │  │  Cluster  │  │              │    │
│  │  │                 │         │  └───────────┘  │              │    │
│  │  └─────────────────┘         └─────────────────┘              │    │
│  │           │                           │                        │    │
│  │           │                           │                        │    │
│  │           ├───────────────────────────┤                        │    │
│  │           │     Security Groups       │                        │    │
│  │           │   - Glue SG (egress all)  │                        │    │
│  │           │   - Redshift SG (5439)    │                        │    │
│  │           └───────────────────────────┘                        │    │
│  │                                                                  │    │
│  │  ┌───────────────────────────────────────────────────┐         │    │
│  │  │           VPC Endpoint (S3 Gateway)               │         │    │
│  │  └───────────────────────────────────────────────────┘         │    │
│  │                         │                                       │    │
│  └─────────────────────────┼───────────────────────────────────────┘    │
│                            │                                            │
│  ┌─────────────────────────┴─────────────────────────────┐             │
│  │                      Amazon S3                         │             │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │             │
│  │  │ Source Data  │  │ Glue Scripts │  │  Temp Data  │ │             │
│  │  │              │  │              │  │             │ │             │
│  │  │ /customers/  │  │  /scripts/   │  │ /spark-logs/│ │             │
│  │  │ /orders/     │  │              │  │ /temp/      │ │             │
│  │  └──────────────┘  └──────────────┘  └─────────────┘ │             │
│  └────────────────────────────────────────────────────────┘             │
│                                                                          │
│  ┌────────────────────────────────────────────────────────┐             │
│  │              AWS Glue Data Catalog                     │             │
│  │  ┌──────────────────────────────────────────────────┐ │             │
│  │  │  Database: visual_etl_glue_database_dev          │ │             │
│  │  │    - Table: customers (S3 location)              │ │             │
│  │  │    - Table: orders (S3 location)                 │ │             │
│  │  │    - Connection: Redshift (JDBC)                 │ │             │
│  │  │    - DQ Rulesets: customers_dq, orders_dq        │ │             │
│  │  └──────────────────────────────────────────────────┘ │             │
│  └────────────────────────────────────────────────────────┘             │
│                                                                          │
│  ┌────────────────────────────────────────────────────────┐             │
│  │                    IAM Roles                           │             │
│  │  - Glue Service Role (S3, Redshift, Glue permissions) │             │
│  │  - Redshift Role (S3 read permissions)                │             │
│  └────────────────────────────────────────────────────────┘             │
│                                                                          │
│  ┌────────────────────────────────────────────────────────┐             │
│  │              CloudWatch & Monitoring                   │             │
│  │  - Glue Job Logs                                       │             │
│  │  - Data Quality Metrics                                │             │
│  │  - Spark UI Logs (S3)                                  │             │
│  └────────────────────────────────────────────────────────┘             │
└──────────────────────────────────────────────────────────────────────────┘
```

## Visual ETL Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Glue Studio Visual ETL Workflow                      │
└─────────────────────────────────────────────────────────────────────────┘

    ┌──────────────┐              ┌──────────────┐
    │   S3 Source  │              │   S3 Source  │
    │  (Customers) │              │   (Orders)   │
    │  via Catalog │              │  via Catalog │
    └──────┬───────┘              └──────┬───────┘
           │                             │
           ▼                             ▼
    ┌──────────────┐              ┌──────────────┐
    │ Data Quality │              │ Data Quality │
    │   Check      │              │   Check      │
    │  (Customers) │              │  (Orders)    │
    └──────┬───────┘              └──────┬───────┘
           │                             │
           │                             ▼
           │                      ┌──────────────┐
           │                      │   Filter     │
           │                      │  (Completed  │
           │                      │   Orders)    │
           │                      └──────┬───────┘
           │                             │
           └─────────────┬───────────────┘
                         ▼
                  ┌──────────────┐
                  │     Join     │
                  │  (customer_  │
                  │     id)      │
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │  Aggregate   │
                  │  (Custom     │
                  │  Transform)  │
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │ Select Fields│
                  │  (Final      │
                  │  Columns)    │
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │   Redshift   │
                  │    Target    │
                  │  (customer_  │
                  │order_summary)│
                  └──────────────┘
```

## Data Flow Details

### Phase 1: Data Ingestion

**Source 1: Customers Data (S3)**
- **Location**: `s3://<bucket>/customers/`
- **Format**: CSV with headers
- **Schema**:
  ```
  customer_id (STRING)
  customer_name (STRING)
  email (STRING)
  country (STRING)
  signup_date (STRING)
  ```
- **Catalog**: Glue Catalog Table with SerDe configuration

**Source 2: Orders Data (S3)**
- **Location**: `s3://<bucket>/orders/`
- **Format**: CSV with headers
- **Schema**:
  ```
  order_id (STRING)
  customer_id (STRING)
  order_date (STRING)
  order_amount (DOUBLE)
  order_status (STRING)
  ```
- **Catalog**: Glue Catalog Table with SerDe configuration

### Phase 2: Data Quality Validation

**Customers Data Quality Rules:**
1. `IsComplete "customer_id"` - No null values
2. `IsUnique "customer_id"` - Primary key constraint
3. `ColumnLength "customer_id" between 1 and 50` - Length validation
4. `IsComplete "email"` - Required field
5. `ColumnValues "email" matches regex` - Email format validation
6. `ColumnValues "country" in [list]` - Enumeration check

**Orders Data Quality Rules:**
1. `IsComplete "order_id"` - No null values
2. `IsUnique "order_id"` - Primary key constraint
3. `IsComplete "customer_id"` - Foreign key reference
4. `IsComplete "order_amount"` - Required field
5. `ColumnValues "order_amount" > 0` - Business rule
6. `ColumnValues "order_status" in [list]` - Status validation

**DQ Output:**
- Passed records → Continue to next node
- Failed records → Logged to CloudWatch
- DQ metrics → Published to CloudWatch Metrics

### Phase 3: Data Transformation

**Filter Transformation:**
- **Condition**: `order_status = 'completed'`
- **Purpose**: Focus analysis on completed transactions
- **Implementation**: Visual filter node

**Join Transformation:**
- **Type**: Inner Join
- **Keys**: `customer_id` = `customer_id`
- **Result**: Combined customer and order information
- **Implementation**: Visual join node

**Aggregation Transformation:**
- **Group By**: customer_id, customer_name, email, country
- **Aggregates**:
  - `SUM(order_amount)` → total_order_amount
  - `COUNT(order_id)` → order_count
  - `AVG(order_amount)` → avg_order_amount
  - `MAX(order_date)` → last_order_date
- **Implementation**: Custom transform node (visual aggregation limited)

**Select Fields:**
- **Purpose**: Choose final output columns
- **Columns**: customer_id, customer_name, email, country, total_order_amount, order_count, avg_order_amount, last_order_date
- **Implementation**: Visual select fields node

### Phase 4: Data Loading

**Target: Amazon Redshift**
- **Connection**: JDBC via Glue Connection
- **Database**: etl_database
- **Schema**: public
- **Table**: customer_order_summary
- **Load Strategy**: Full overwrite (configurable to append)
- **Temp Location**: S3 temp bucket for staging

## Component Details

### AWS Glue Components

#### 1. Glue Catalog Database
- **Purpose**: Central metadata repository
- **Contains**: Table definitions, schemas, locations
- **Benefits**:
  - Unified view of data
  - Schema evolution tracking
  - Integration with Athena, Redshift Spectrum

#### 2. Glue Catalog Tables
- **Customers Table**:
  - External table pointing to S3
  - CSV SerDe configuration
  - Column type definitions
- **Orders Table**:
  - External table pointing to S3
  - CSV SerDe configuration
  - Column type definitions

#### 3. Glue Connection
- **Type**: JDBC
- **Protocol**: jdbc:redshift://
- **Authentication**: Username/password (recommend Secrets Manager in prod)
- **Network**: VPC, subnet, security group configuration

#### 4. Glue Visual ETL Job
- **Type**: Visual ETL with generated PySpark
- **Execution**:
  - Glue version: 4.0
  - Python: 3.9
  - Spark: 3.3
- **Resources**:
  - Worker Type: G.1X (4 vCPU, 16 GB memory, 64 GB disk)
  - Number of Workers: 2
  - Total: 2 DPUs
- **Features Enabled**:
  - Job bookmarking (incremental processing)
  - Metrics publishing
  - Spark UI
  - Job insights
  - Continuous CloudWatch logging

### Network Architecture

#### VPC Configuration
- **CIDR**: 10.0.0.0/16
- **Subnets**: 2 private subnets in different AZs
  - Subnet 1: 10.0.1.0/24 (AZ-1)
  - Subnet 2: 10.0.2.0/24 (AZ-2)
- **Internet Gateway**: For public internet access (if needed)
- **VPC Endpoint**: S3 Gateway endpoint for private S3 access

#### Security Groups

**Glue Security Group:**
- **Inbound**: Self-referencing rule (TCP 0-65535) for Glue inter-node communication
- **Outbound**: All traffic (0.0.0.0/0)
- **Purpose**: Allow Glue job networking

**Redshift Security Group:**
- **Inbound**: Port 5439 from Glue Security Group
- **Outbound**: All traffic
- **Purpose**: Allow Glue to connect to Redshift

### Storage Architecture

#### S3 Bucket Structure

**Source Data Bucket:**
```
visual-etl-glue-source-data-dev-{account-id}/
├── customers/
│   └── customers.csv
└── orders/
    └── orders.csv
```

**Glue Scripts Bucket:**
```
visual-etl-glue-glue-scripts-dev-{account-id}/
└── scripts/
    └── visual_etl_job.py
```

**Glue Temp Bucket:**
```
visual-etl-glue-glue-temp-dev-{account-id}/
├── spark-logs/
│   └── {job-run-id}/
├── temp/
│   └── {temporary-files}
└── redshift-staging/
    └── {staging-data}
```

**Lifecycle Policies:**
- Temp bucket: Auto-delete objects after 7 days

### Redshift Configuration

**Cluster Specifications:**
- **Type**: dc2.large (160 GB SSD, 2 vCPU, 15 GB RAM)
- **Nodes**: 1 (single-node for dev)
- **Database**: etl_database
- **Encryption**: Enabled (AES-256)
- **Backup**: Automated snapshots
- **Network**: Private subnet, no public access

**Target Table Schema:**
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
)
SORTKEY(customer_id);
```

## IAM Security Model

### Glue Service Role Permissions

**AWS Managed Policies:**
- `AWSGlueServiceRole` - Base Glue service permissions

**Custom Policies:**

1. **S3 Access Policy:**
   - GetObject, PutObject, DeleteObject on source/scripts/temp buckets
   - ListBucket on all three buckets

2. **Redshift Access Policy:**
   - DescribeClusters, DescribeClusterSubnetGroups
   - redshift-data API permissions
   - SecretsManager GetSecretValue (for credentials)

### Redshift IAM Role Permissions

**Custom Policy:**
- S3 GetObject, ListBucket on source and temp buckets
- Used for COPY/UNLOAD commands

### Principle of Least Privilege
- Each role has only necessary permissions
- Resource-level restrictions where possible
- Separate roles for Glue and Redshift
- No wildcard (*) permissions in production

## Monitoring and Observability

### CloudWatch Integration

**Glue Job Logs:**
- `/aws-glue/jobs/output` - Standard output
- `/aws-glue/jobs/error` - Error logs
- Log retention: 7 days (configurable)

**Metrics:**
- `glue.driver.aggregate.numFailedTasks`
- `glue.driver.aggregate.numCompletedTasks`
- `glue.ALL.jvm.heap.usage`
- `glue.driver.aggregate.DataQuality.*`

**Data Quality Metrics:**
- Rule success/failure counts
- Row-level pass/fail statistics
- Published to CloudWatch Metrics namespace

### Spark UI
- Enabled via job parameter
- Logs stored in S3 temp bucket
- Access via Glue Console or S3

## Scalability Considerations

### Horizontal Scaling
- Increase `number_of_workers` for more parallelism
- Maximum workers depend on data size and transformations

### Vertical Scaling
- Upgrade worker type:
  - G.025X: 2 vCPU, 4 GB (light workloads)
  - G.1X: 4 vCPU, 16 GB (standard)
  - G.2X: 8 vCPU, 32 GB (heavy transformations)

### Redshift Scaling
- Add nodes for multi-node cluster
- Consider Redshift Serverless for variable workloads
- Use columnar compression and sort keys

### S3 Performance
- S3 automatically scales
- Use partitioning for large datasets
- Optimize file sizes (avoid many small files)

## Disaster Recovery

### Backup Strategy
- **S3**: Versioning enabled, cross-region replication optional
- **Redshift**: Automated snapshots, manual snapshots, cross-region copy
- **Glue Catalog**: Metadata backed up via AWS Backup or exports

### Recovery Procedures
1. Restore Redshift from snapshot
2. Restore S3 data from versioning or replication
3. Re-deploy Glue resources via Terraform
4. Verify data integrity

## Cost Optimization Strategies

1. **Glue Job Optimization**
   - Use job bookmarking for incremental loads
   - Optimize worker count and type
   - Schedule jobs during off-peak hours

2. **Redshift Cost Reduction**
   - Pause cluster when not in use
   - Use reserved instances for production
   - Enable concurrency scaling only when needed
   - Implement result caching

3. **S3 Cost Management**
   - Lifecycle policies for old data
   - Compress source files
   - Use S3 Intelligent-Tiering

4. **Network Costs**
   - Keep data transfer within same region
   - Use VPC endpoints to avoid NAT gateway costs

## Security Best Practices

1. **Data Encryption**
   - S3: Server-side encryption with KMS
   - Redshift: Cluster encryption enabled
   - Glue: Job bookmark encryption

2. **Network Security**
   - Private subnets for compute resources
   - Security groups with minimal access
   - VPC endpoints for AWS services
   - No public internet access to Redshift

3. **Access Control**
   - IAM roles with least privilege
   - MFA for console access
   - CloudTrail logging enabled
   - Regular access reviews

4. **Secrets Management**
   - Store credentials in AWS Secrets Manager
   - Rotate credentials regularly
   - No hardcoded passwords in code

## Future Enhancements

1. **Add More Data Sources**
   - RDS databases
   - DynamoDB tables
   - API integrations

2. **Implement Incremental Loading**
   - Partition-based processing
   - Change Data Capture (CDC)
   - Timestamp-based filtering

3. **Advanced Data Quality**
   - Custom DQ rules
   - Anomaly detection
   - Data profiling

4. **Orchestration**
   - AWS Step Functions for complex workflows
   - AWS EventBridge for event-driven ETL
   - Apache Airflow on MWAA

5. **Data Governance**
   - AWS Lake Formation for fine-grained access
   - Data lineage tracking
   - Sensitive data discovery and masking
