# ============================================================================
# LOADBALANCER.TF - Infrastructure Only (SG, ALB, Listeners)
# ============================================================================

# 1. SECURITY GROUP
resource "aws_security_group" "alb_sg" {
  name        = "Fvrk-dev-alb-sg"
  description = "Allow HTTP and HTTPS from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Fvrk-dev-alb-sg"
  }
}

# 2. LOAD BALANCER
resource "aws_lb" "main" {
  name               = "Fvrk-dev-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = slice(aws_subnet.public[*].id, 0, 3) 
  idle_timeout       = 300 

  tags = {
    Name = "Fvrk-dev-alb"
  }
}

# 3. HTTP LISTENER (Redirect 80 -> 443)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# 4. HTTPS LISTENER (Port 443)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  
  # YOUR CERTIFICATE
  certificate_arn   = "arn:aws:acm:ap-south-1:010438478476:certificate/027daaa8-4c47-41d3-ad8c-b7828d332752"

  # Default Action: Forward to Frontend (Target Group defined in other file)
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["fvrk-dev-tg"].arn
  }
}



###############

#UAT ALB

####################

# ============================================================================
# LOADBALANCER.TF - UAT Infrastructure
# ============================================================================

# 1. SECURITY GROUP (UAT)
resource "aws_security_group" "alb_sg_uat" {
  name        = "Fvrk-uat-alb-sg"
  description = "Allow HTTP and HTTPS from anywhere - UAT"
  vpc_id      = aws_vpc.main.id # Ensure this points to your UAT VPC

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Fvrk-uat-alb-sg"
    Env  = "uat"
  }
}

# 2. LOAD BALANCER (UAT)
resource "aws_lb" "main_uat" {
  name               = "Fvrk-uat-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg_uat.id]
  subnets            = slice(aws_subnet.public[*].id, 0, 3) 
  idle_timeout       = 300 

  tags = {
    Name = "fvrk-uat-alb"
    Env  = "uat"
  }
}

# 3. HTTP LISTENER (Redirect 80 -> 443)
resource "aws_lb_listener" "http_uat" {
  load_balancer_arn = aws_lb.main_uat.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# 4. HTTPS LISTENER (Port 443)
resource "aws_lb_listener" "https_uat" {
  load_balancer_arn = aws_lb.main_uat.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  
  # Same certificate used for UAT
  certificate_arn   = "arn:aws:acm:ap-south-1:010438478476:certificate/027daaa8-4c47-41d3-ad8c-b7828d332752"

  # Default Action: Updated to point to UAT Target Group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["fvrk-uat-tg"].arn
  }
}






################ NLB ###############

# ============================================================================
# NLB.TF - "Front Door" Load Balancer
# ============================================================================

# 1. THE NETWORK LOAD BALANCER
resource "aws_lb" "nlb_rabbit" {
  name               = "Fvrk-dev-nlb-front-door"
  internal           = false
  load_balancer_type = "network"
  subnets            = slice(aws_subnet.public[*].id, 0, 3) 
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "Fvrk-dev-nlb-front-door"
  }
}

# ----------------------------------------------------------------------------
# PATH A: RABBITMQ MESSAGING (Port 5672 -> EKS NodePort 32525)
# ----------------------------------------------------------------------------

# 2. TCP TARGET GROUP
resource "aws_lb_target_group" "rabbit_messaging" {
  name        = "k8s-rabbit-mq-messaging"
  port        = 32525       # Your specific NodePort
  protocol    = "TCP"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }
}

# 3. LISTENER FOR MESSAGING (5672)
resource "aws_lb_listener" "rabbit_messaging_listener" {
  load_balancer_arn = aws_lb.nlb_rabbit.arn
  port              = "5672"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rabbit_messaging.arn
  }
}

# ----------------------------------------------------------------------------
# PATH B: WEB TRAFFIC BRIDGE (Port 443 -> ALB)
# ----------------------------------------------------------------------------

# 4. ALB TARGET GROUP (Special Type: ALB)
resource "aws_lb_target_group" "alb_bridge" {
  name        = "nlb-to-alb-bridge"
  target_type = "alb"
  port        = 443
  protocol    = "TCP"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
  
  health_check {
    protocol = "HTTPS"
    path     = "/health" # Ensure your ALB has a default response or use a known healthy path
    matcher  = "200-499"
  }
}

# 5. ATTACH EXISTING ALB TO NLB
resource "aws_lb_target_group_attachment" "alb_attachment" {
  target_group_arn = aws_lb_target_group.alb_bridge.arn
  target_id        = aws_lb.main.id  # References the ALB from your LOADBALANCER.TF
  port             = 443
}

# 6. LISTENER FOR WEB (443)
resource "aws_lb_listener" "nlb_https_listener" {
  load_balancer_arn = aws_lb.nlb_rabbit.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_bridge.arn
  }
}