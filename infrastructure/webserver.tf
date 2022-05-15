provider "aws" {
  region = var.region
}

data "aws_route53_zone" "website" {
  name         = "itsmeganificent.com"
  private_zone = false
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

resource "aws_security_group" "webserver-sg" {
  name = var.secgroupname
  description = var.secgroupname
  vpc_id = var.vpc

  // To Allow SSH Transport
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  // To Allow Port 80 Transport
  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_key_pair" "webserver" {
  key_name   = var.keyname
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOd0i8D+9JxVxcugOoAxFXFm2otOFh8gsBZW7lXwBy3Z christhebatchelor@gmail.com"
}

resource "aws_spot_instance_request" "webserver" {
  ami = data.aws_ami.amazon_linux_2.id
  instance_type = var.itype
  subnet_id = var.subnet
  associate_public_ip_address = false
  key_name = var.keyname
  wait_for_fulfillment = true

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    docker pull fiercekitti/portfolio_website
    docker run -it -d -p 80:80 fiercekitti/portfolio_website
    !/bin/bash sudo su echo '*/1 * * * * "docker pull fiercekitti/portfolio_website" "docker run -it -d -p 80:80 fiercekitti/portfolio_website"' > /tmp/mycrontab.txt sudo -u ubuntu bash -c 'crontab /tmp/mycrontab.txt'
  EOF

  vpc_security_group_ids = [
    aws_security_group.webserver-sg.id
  ]
  root_block_device {
    delete_on_termination = true
    volume_size = 15
  }
  tags = {
    Name ="Webserver"
  }

  depends_on = [ aws_security_group.webserver-sg ]
}

resource "aws_eip" "webserver" {
  instance = aws_spot_instance_request.webserver.spot_instance_id
  vpc      = true

  depends_on = [ aws_spot_instance_request.webserver ]
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.website.zone_id
  name    = "www.${data.aws_route53_zone.website.name}"
  type    = "A"
  ttl     = "300"
  records = [ aws_eip.webserver.public_ip ]

  depends_on = [ aws_eip.webserver ]
}

resource "aws_route53_record" "no_www" {
  zone_id = data.aws_route53_zone.website.zone_id
  name    = "${data.aws_route53_zone.website.name}"
  type    = "A"
  ttl     = "300"
  records = [ aws_eip.webserver.public_ip ]

  depends_on = [ aws_eip.webserver ]
}

output "ec2instance" {
  value = aws_eip.webserver.public_ip
}