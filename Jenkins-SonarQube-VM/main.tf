
# --------------------------------------------------
# EC2 Instance: Jenkins + SonarQube
# --------------------------------------------------

resource "aws_instance" "web" {
  ami           = "ami-0c7632fb77f35db43"
  instance_type = "t2.large"
  key_name      = "ExoPlanetHunt-keypair"

  vpc_security_group_ids = [
    aws_security_group.Jenkins-VM-SG.id
  ]

  user_data = templatefile("${path.module}/install.sh", {})

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }

  tags = {
    Name = "Jenkins-SonarQube"
  }
}

# --------------------------------------------------
# Security Group
# --------------------------------------------------

resource "aws_security_group" "Jenkins-VM-SG" {
  name        = "Jenkins-VM-SG"
  description = "Security group for Jenkins and SonarQube"

  # SSH: access only from your public IP
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["112.196.126.3/32"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins
  ingress {
    description = "Jenkins from my IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["112.196.126.3/32"]
  }

  # SonarQube
  ingress {
    description = "SonarQube from my IP"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["112.196.126.3/32"]
  }

  # Application
  ingress {
    description = "Application from my IP"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["112.196.126.3/32"]
  }

  # Allow outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Jenkins-VM-SG"
  }
}
