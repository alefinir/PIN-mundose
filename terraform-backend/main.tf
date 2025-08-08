##Create and bootstrap webserver #lanzar test2
#resource "aws_instance" "webserver" {
#  ami                         = "ami-00c39f71452c08778"
#  instance_type               = "t2.micro"
#  #key_name                    = app-ssh-key 
#  associate_public_ip_address = true
#  vpc_security_group_ids      = [aws_security_group.sg.id]
#  subnet_id                   = aws_subnet.subnet.id
#  user_data                   = "${file("create_apache.sh")}"

#  tags = {
#    Name = "webserver"
#  }
#}


# main.tf

# ---------------------------------------------------------------------------------------------------------------------
# PROVIDER CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

# Define the AWS provider and the target region.
provider "aws" {
  region = "us-east-1" # You can change this to your desired region.
}


####################
resource "aws_security_group" "ssh_access" {
  name        = "ssh-access-sg"
  description = "Permite acceso SSH desde una IP específica"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["190.134.158.217/32"] # ¡Importante! Aquí se restringe el acceso a la IP deseada
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Despliega la instancia EC2
resource "aws_instance" "mundose_vm" {
  ami                         = "ami-00c39f71452c08778"
  instance_type = "t2.micro"
  key_name                    = "alefinir"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.ssh_access.id]
  tags = {
    Name = "mundose-vm"
  }
}

# ---
### Salidas de la Instancia
# ---

output "public_ip" {
  description = "La dirección IP pública de la instancia EC2"
  value       = aws_instance.mundose_vm.public_ip
}

####################

# ---------------------------------------------------------------------------------------------------------------------
# VPC AND NETWORKING
# ---------------------------------------------------------------------------------------------------------------------

# Create VPC using AWS VPC module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    "Environment" = "dev"
  }
}
# EKS requires a VPC with multiple subnets. This block creates a new VPC.
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "eks-vpc"
  }
}

# Create a public subnet for the EKS nodes.
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "eks-public-subnet-a"
  }
}

# Create a second public subnet for high availability.
resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "eks-public-subnet-b"
  }
}

# An internet gateway is required for the public subnets to have internet access.
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}

# Create a route table to direct traffic to the internet gateway.
resource "aws_route_table" "eks_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "eks-route-table"
  }
}

# Associate the route table with the public subnets.
resource "aws_route_table_association" "eks_rt_assoc_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.eks_rt.id
}

resource "aws_route_table_association" "eks_rt_assoc_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.eks_rt.id
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM ROLES
# ---------------------------------------------------------------------------------------------------------------------

# EKS Cluster IAM Role
# This role is assumed by the EKS control plane to create and manage AWS resources on your behalf.
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the required AWS managed policy for EKS to the role.
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Node Group IAM Role
# This role is assumed by the EC2 instances in the managed node group.
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the required AWS managed policies for the EKS worker nodes.
resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# ---------------------------------------------------------------------------------------------------------------------
# EKS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

# The EKS cluster itself.
resource "aws_eks_cluster" "eks_cluster" {
  name     = "mundose-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.28" # Specify your desired Kubernetes version.

  vpc_config {
    subnet_ids = [
      aws_subnet.public_subnet_a.id,
      aws_subnet.public_subnet_b.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = "mundose-cluster"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EKS MANAGED NODE GROUP
# ---------------------------------------------------------------------------------------------------------------------

# Create a managed node group to run your workloads.
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "mundose-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  instance_types  = ["t3.medium"] # Choose an instance type that suits your needs.

  scaling_config {
    desired_size = 2 # Start with 2 nodes.
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_registry_policy
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

# Output the cluster name and endpoint to easily connect to it.
output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}
