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
  filter {
    name   = "tag:Name"
    values = [var.network.lan.name]
  }
}

data "aws_subnet" "lan" {
  vpc_id     = data.aws_vpc.lan.id
  cidr_block = var.network.lan.ipv4.subnet
}

data "aws_security_group" "nodes" {
  count = var.purpose == "worker" ? 1 : 0

  vpc_id = data.aws_vpc.lan.id

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

resource "aws_security_group" "nodes" {
  count = var.purpose == "master" ? 1 : 0

  name        = "${local.cluster}-nodes"
  description = "rock8s node traffic within VPC"
  vpc_id      = data.aws_vpc.lan.id

  ingress {
    description = "All traffic from VPC LAN"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.network.lan.ipv4.subnet]
  }

  dynamic "ingress" {
    for_each = local.has_gateway ? [] : [1]
    content {
      description = "SSH from public (WAN-only mode)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
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

  subnet_id = data.aws_subnet.lan.id
  vpc_security_group_ids = [
    var.purpose == "master" ? aws_security_group.nodes[0].id : data.aws_security_group.nodes[0].id
  ]

  associate_public_ip_address = true
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
