# Redshift subnet group
resource "aws_redshift_subnet_group" "main" {
  name       = "${var.project_name}-redshift-subnet-group-${var.environment}"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${var.project_name}-redshift-subnet-group-${var.environment}"
  }
}

# Redshift cluster
resource "aws_redshift_cluster" "etl_cluster" {
  cluster_identifier        = "${var.project_name}-cluster-${var.environment}"
  database_name             = "etl_database"
  master_username           = var.redshift_master_username
  master_password           = var.redshift_master_password
  node_type                 = var.redshift_node_type
  cluster_type              = var.redshift_number_of_nodes > 1 ? "multi-node" : "single-node"
  number_of_nodes           = var.redshift_number_of_nodes
  
  vpc_security_group_ids    = [aws_security_group.redshift.id]
  cluster_subnet_group_name = aws_redshift_subnet_group.main.name
  
  iam_roles                 = [aws_iam_role.redshift_role.arn]
  
  publicly_accessible       = false
  encrypted                 = true
  skip_final_snapshot       = true

  tags = {
    Name = "${var.project_name}-redshift-cluster-${var.environment}"
  }
}

# Create target table in Redshift (using null_resource with aws cli)
# Note: In production, you would typically create tables via migration scripts
resource "null_resource" "create_redshift_tables" {
  depends_on = [aws_redshift_cluster.etl_cluster]

  # This is a placeholder - in real scenarios, you would use:
  # 1. AWS Redshift Data API
  # 2. Terraform provider for Redshift (community)
  # 3. External provisioner with psql
  # For this demo, tables would be created manually or via Glue job

  provisioner "local-exec" {
    command = "echo 'Redshift tables should be created using Redshift Data API or SQL client'"
  }
}
