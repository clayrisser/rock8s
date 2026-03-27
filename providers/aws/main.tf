data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "debian" {
  for_each = local.ami_lookup_keys

  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["${split(":", each.key)[0]}-${split(":", each.key)[1] == "arm64" ? "arm64" : "amd64"}-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_vpc" "lan" {
  count = var.purpose == "worker" ? 1 : 0

  filter {
    name   = "tag:cluster"
    values = [var.cluster_name]
  }
  filter {
    name   = "tag:rock8s"
    values = ["lan-vpc"]
  }
}

data "aws_subnet" "lan" {
  count = var.purpose == "worker" ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.lan[0].id]
  }
  filter {
    name   = "tag:cluster"
    values = [var.cluster_name]
  }
  filter {
    name   = "tag:rock8s"
    values = ["lan-subnet"]
  }
}

data "aws_security_group" "nodes" {
  count = var.purpose == "worker" ? 1 : 0

  vpc_id = data.aws_vpc.lan[0].id

  filter {
    name   = "tag:cluster"
    values = [var.cluster_name]
  }
  filter {
    name   = "tag:rock8s"
    values = ["nodes-sg"]
  }
}

resource "tls_private_key" "node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "node" {
  key_name   = "${local.cluster}-${var.purpose}"
  public_key = tls_private_key.node.public_key_openssh

  tags = {
    Name    = "${local.cluster}-${var.purpose}"
    cluster = var.cluster_name
    purpose = var.purpose
  }
}

resource "aws_vpc" "lan" {
  count = var.purpose == "master" ? 1 : 0

  cidr_block           = var.network.lan.ipv4.subnet
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = local.network.lan.name
    cluster = var.cluster_name
    purpose = var.purpose
    rock8s  = "lan-vpc"
  }
}

resource "aws_subnet" "lan" {
  count = var.purpose == "master" ? 1 : 0

  vpc_id                  = aws_vpc.lan[0].id
  cidr_block              = var.network.lan.ipv4.subnet
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = !local.has_gateway

  tags = {
    Name    = "${local.network.lan.name}-subnet"
    cluster = var.cluster_name
    purpose = var.purpose
    rock8s  = "lan-subnet"
  }

  depends_on = [aws_vpc.lan]
}

resource "aws_internet_gateway" "igw" {
  count = var.purpose == "master" && !local.has_gateway ? 1 : 0

  vpc_id = aws_vpc.lan[0].id

  tags = {
    Name    = "${local.cluster}-igw"
    cluster = var.cluster_name
    purpose = var.purpose
    rock8s  = "lan-igw"
  }
}

resource "aws_route_table" "default" {
  count = var.purpose == "master" ? 1 : 0

  vpc_id = aws_vpc.lan[0].id

  tags = {
    Name    = "${local.cluster}-lan-rt"
    cluster = var.cluster_name
    purpose = var.purpose
    rock8s  = "lan-rt"
  }
}

resource "aws_route" "public_ipv4" {
  count = var.purpose == "master" && !local.has_gateway ? 1 : 0

  route_table_id         = aws_route_table.default[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[0].id

  depends_on = [
    aws_route_table.default,
    aws_internet_gateway.igw,
  ]
}

resource "aws_route_table_association" "lan" {
  count = var.purpose == "master" ? 1 : 0

  subnet_id      = aws_subnet.lan[0].id
  route_table_id = aws_route_table.default[0].id
}

resource "aws_security_group" "nodes" {
  count = var.purpose == "master" ? 1 : 0

  name        = "${local.cluster}-nodes"
  description = "rock8s node traffic within VPC"
  vpc_id      = aws_vpc.lan[0].id

  ingress {
    description = "All traffic from VPC LAN"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.network.lan.ipv4.subnet]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${local.cluster}-nodes"
    cluster = var.cluster_name
    purpose = var.purpose
    rock8s  = "nodes-sg"
  }
}

resource "aws_instance" "nodes" {
  count = length(local.node_configs)

  ami           = data.aws_ami.debian["${replace(coalesce(local.node_configs[count.index].image, var.image), ".", "-")}:${local.node_configs[count.index].arch}"].id
  instance_type = local.node_configs[count.index].server_type
  key_name      = aws_key_pair.node.key_name
  user_data     = local.cloud_init

  subnet_id = var.purpose == "master" ? aws_subnet.lan[0].id : data.aws_subnet.lan[0].id
  vpc_security_group_ids = [
    var.purpose == "master" ? aws_security_group.nodes[0].id : data.aws_security_group.nodes[0].id
  ]

  associate_public_ip_address = !local.has_gateway
  private_ip                  = local.node_configs[count.index].ipv4

  disable_api_termination = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name    = local.node_configs[count.index].name
    cluster = var.cluster_name
    purpose = var.purpose
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data,
      associate_public_ip_address,
    ]
  }
}
