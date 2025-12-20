"""
AWS Glue Studio Visual ETL Job Script
Generated from Visual ETL workflow in AWS Glue Studio

This script represents a visual ETL pipeline with the following nodes:
1. Source: Read customers data from S3 (via Glue Catalog)
2. Source: Read orders data from S3 (via Glue Catalog)
3. Data Quality: Validate customers data
4. Data Quality: Validate orders data
5. Join: Inner join customers and orders on customer_id
6. Aggregate: Calculate total order amount and count per customer
7. Filter: Keep only customers with completed orders
8. Select Fields: Choose final output columns
9. Target: Write results to Redshift

Note: This is the code representation of the visual workflow.
In Glue Studio UI, this would be created using drag-and-drop visual nodes.
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import functions as F
from awsglue import DynamicFrame

# Visual ETL imports for data quality
from awsgluedq.transforms import EvaluateDataQuality

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'source_database',
    'customers_table',
    'orders_table',
    'redshift_connection',
    'target_database',
    'target_schema',
    'target_table'
])

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# ============================================================================
# NODE 1: Source - Read Customers from S3 via Glue Catalog
# Visual Node Type: "Data Catalog table" (S3 source)
# ============================================================================
customers_source = glueContext.create_dynamic_frame.from_catalog(
    database=args['source_database'],
    table_name=args['customers_table'],
    transformation_ctx="customers_source"
)

# ============================================================================
# NODE 2: Source - Read Orders from S3 via Glue Catalog
# Visual Node Type: "Data Catalog table" (S3 source)
# ============================================================================
orders_source = glueContext.create_dynamic_frame.from_catalog(
    database=args['source_database'],
    table_name=args['orders_table'],
    transformation_ctx="orders_source"
)

# ============================================================================
# NODE 3: Data Quality Check - Customers
# Visual Node Type: "Evaluate Data Quality"
# Note: In Glue Studio, this is configured visually with rule checkboxes
# ============================================================================
customers_dq_ruleset = """
    Rules = [
        IsComplete "customer_id",
        IsUnique "customer_id",
        ColumnLength "customer_id" between 1 and 50,
        IsComplete "email",
        ColumnValues "email" matches "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
        ColumnValues "country" in ["USA", "UK", "Canada", "Australia", "Germany", "France"]
    ]
"""

customers_dq_result = EvaluateDataQuality.apply(
    frame=customers_source,
    ruleset=customers_dq_ruleset,
    publishing_options={
        "dataQualityEvaluationContext": "customers_dq_check",
        "enableDataQualityCloudWatchMetrics": True,
        "enableDataQualityResultsPublishing": True
    },
    transformation_ctx="customers_dq_result"
)

# Get the validated data (rows that passed DQ checks)
customers_validated = SelectFromCollection.apply(
    dfc=customers_dq_result,
    key="rowLevelOutcomes",
    transformation_ctx="customers_validated"
)

# ============================================================================
# NODE 4: Data Quality Check - Orders
# Visual Node Type: "Evaluate Data Quality"
# ============================================================================
orders_dq_ruleset = """
    Rules = [
        IsComplete "order_id",
        IsUnique "order_id",
        IsComplete "customer_id",
        IsComplete "order_amount",
        ColumnValues "order_amount" > 0,
        ColumnValues "order_status" in ["pending", "completed", "cancelled", "shipped"]
    ]
"""

orders_dq_result = EvaluateDataQuality.apply(
    frame=orders_source,
    ruleset=orders_dq_ruleset,
    publishing_options={
        "dataQualityEvaluationContext": "orders_dq_check",
        "enableDataQualityCloudWatchMetrics": True,
        "enableDataQualityResultsPublishing": True
    },
    transformation_ctx="orders_dq_result"
)

orders_validated = SelectFromCollection.apply(
    dfc=orders_dq_result,
    key="rowLevelOutcomes",
    transformation_ctx="orders_validated"
)

# ============================================================================
# NODE 5: Filter Orders - Keep only completed orders
# Visual Node Type: "Filter"
# In Glue Studio: Simple condition dropdown (order_status = completed)
# ============================================================================
orders_filtered = Filter.apply(
    frame=orders_validated,
    f=lambda row: row["order_status"] == "completed",
    transformation_ctx="orders_filtered"
)

# ============================================================================
# NODE 6: Join - Customers and Orders
# Visual Node Type: "Join"
# In Glue Studio: Visual join node with key selection dropdowns
# ============================================================================
customers_orders_join = Join.apply(
    frame1=customers_validated,
    frame2=orders_filtered,
    keys1=["customer_id"],
    keys2=["customer_id"],
    transformation_ctx="customers_orders_join"
)

# ============================================================================
# NODE 7: Aggregate - Calculate metrics per customer
# Visual Node Type: "Aggregate"
# In Glue Studio: Drag-and-drop aggregation with function selection
# Note: Visual aggregation in Glue Studio is limited. For complex aggregations,
# custom code is required (see documentation for limitations)
# ============================================================================

# Convert to DataFrame for aggregation (visual limitation workaround)
df = customers_orders_join.toDF()

# Perform aggregation
aggregated_df = df.groupBy(
    "customer_id",
    "customer_name",
    "email",
    "country"
).agg(
    F.sum("order_amount").alias("total_order_amount"),
    F.count("order_id").alias("order_count"),
    F.avg("order_amount").alias("avg_order_amount"),
    F.max("order_date").alias("last_order_date")
)

# Convert back to DynamicFrame
customer_summary = DynamicFrame.fromDF(
    aggregated_df,
    glueContext,
    "customer_summary"
)

# ============================================================================
# NODE 8: Select Fields - Choose final output columns
# Visual Node Type: "Select Fields"
# In Glue Studio: Checkbox selection of fields to keep/drop
# ============================================================================
final_output = SelectFields.apply(
    frame=customer_summary,
    paths=[
        "customer_id",
        "customer_name",
        "email",
        "country",
        "total_order_amount",
        "order_count",
        "avg_order_amount",
        "last_order_date"
    ],
    transformation_ctx="final_output"
)

# ============================================================================
# NODE 9: Target - Write to Redshift
# Visual Node Type: "Amazon Redshift"
# In Glue Studio: Visual node with connection selection and table name input
# ============================================================================
redshift_output = glueContext.write_dynamic_frame.from_jdbc_conf(
    frame=final_output,
    catalog_connection=args['redshift_connection'],
    connection_options={
        "dbtable": f"{args['target_schema']}.{args['target_table']}",
        "database": args['target_database']
    },
    redshift_tmp_dir=args["TempDir"],
    transformation_ctx="redshift_output"
)

# Commit the job
job.commit()
