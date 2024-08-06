resource "aws_vpc" "terraform-vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.terraform-vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.terraform-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "terraform-igw" {
  vpc_id = aws_vpc.terraform-vpc.id
}

resource "aws_route_table" "terraform-route" {
  vpc_id = aws_vpc.terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform-igw.id
  }
}

resource "aws_route_table_association" "RT1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.terraform-route.id
}

resource "aws_route_table_association" "RT2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.terraform-route.id
}

resource "aws_security_group" "terra-sg" {
  name   = "web-sg"
  vpc_id = aws_vpc.terraform-vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "terraform-s3" {
  bucket = "terraform-project4011-s3"
}

resource "aws_instance" "terraform-server1" {
  ami                    = "ami-0ad21ae1d0696ad58"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.terra-sg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data              = base64encode(file("userdata.sh"))
}

resource "aws_instance" "terraform-server2" {
  ami                    = "ami-0ad21ae1d0696ad58"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.terra-sg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data              = base64encode(file("userdata2.sh"))
}
#create alb
resource "aws_lb" "terraform-lb" {
  name               = "terraform-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.terra-sg.id]
  subnets            = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  enable_deletion_protection = true

  /*access_logs {
    bucket  = terraform-project4011-s3
    prefix  = "terraform-lb"
    enabled = true
  }*/
}

resource "aws_lb_target_group" "terraform-tg" {
  name     = "terraform-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform-vpc.id
}

/*resource "aws_vpc" "terraform-vpc" {
  cidr_block = "10.0.0.0/16"
}*/

resource "aws_lb_target_group_attachment" "tg-a" {
  target_group_arn = aws_lb_target_group.terraform-tg.arn
  target_id        = aws_instance.terraform-server1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg-b" {
  target_group_arn = aws_lb_target_group.terraform-tg.arn
  target_id        = aws_instance.terraform-server2.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.terraform-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.terraform-tg.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.terraform-lb.dns_name
}
