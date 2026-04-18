# ============================================================================
# TARGET-GROUP-UAT.TF - Integrated EKS UAT Logic (Shared Cluster)
# ============================================================================

# 1. LOCALS (Namespace: uat)
locals {
  uat_target_group_services = {
    "doc-page-classification-uat" = { node_port = 30035, k8s_service = "doc-page-classification-service-uat", k8s_port = 8003, health_path = "/health" }
    "doc-classification-uat"      = { node_port = 30037, k8s_service = "doc-classification-service-uat", k8s_port = 8006, health_path = "/" }
    "doc-field-extraction-uat"    = { node_port = 30036, k8s_service = "doc-field-extraction-service-uat", k8s_port = 8004, health_path = "/api/field-extraction/health" }
    "text-extraction-uat"         = { node_port = 30032, k8s_service = "text-extraction-service-uat", k8s_port = 8015, health_path = "/api/framev3/document-text-extraction/health" }
    "validus-uat"                 = { node_port = 30031, k8s_service = "validus-service-uat", k8s_port = 8020, health_path = "/health" }
    "fvrk-uat-tg"                 = { node_port = 30034, k8s_service = "frame-validus-service-uat", k8s_port = 80, health_path = "/" }
    "frame-uat"                   = { node_port = 30041, k8s_service = "frame-service-uat", k8s_port = 8040, health_path = "/health" }   
    "common-service-uat"          = { node_port = 30038, k8s_service = "common-service-service-uat", k8s_port = 8000, health_path = "/api/common/health" }
    "airflow-uat"                 = { node_port = 30061, k8s_service = "airflow-webserver-nodeport-uat", k8s_port = 8080, health_path = "/health" }
    "kong-gateway-uat"            = { node_port = 30107, k8s_service = "kong-service-uat", k8s_port = 8000, health_path = "/api/common/health" }
    "rabbitmq-uat"                = { node_port = 30039, k8s_service = "rabbitmq-service-uat", k8s_port = 15672, health_path = "/api/health/checks/virtual-hosts" }
    
    # --- NEWLY ADDED UAT SERVICES ---
    "keycloak-uat"                = { node_port = 30131, k8s_service = "keycloak-service-uat", k8s_port = 8080, health_path = "/health/live" }
    "kong-uat-admin"              = { node_port = 30133, k8s_service = "kong-uat-admin-service", k8s_port = 8001, health_path = "/status" }
    "konga-uat"                   = { node_port = 30134, k8s_service = "konga-service-uat", k8s_port = 1337, health_path = "/status" }

    # --- ETL UAT SERVICE ---
    "etl-uat"                     = { node_port = 30042, k8s_service = "etl-deployment-uat", k8s_port = 5000, health_path = "/" }
  }
}

# 2. AWS TARGET GROUPS (UAT)
resource "aws_lb_target_group" "main_uat" {
  for_each = local.uat_target_group_services

  name        = "k8s-${each.key}"
  port        = each.value.node_port
  protocol    = "HTTP"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
  target_type = "instance"

  health_check {
    path                = each.value.health_path
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-499"
  }

  tags = {
    Environment = "uat"
    ManagedBy   = "Terraform"
  }
}

# 3. KUBERNETES BINDINGS (Namespace: uat)
resource "kubernetes_manifest" "tg_bindings_uat" {
  for_each = local.uat_target_group_services

  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "${each.key}-binding"
      namespace = "uat"
    }
    spec = {
      serviceRef = {
        name = each.value.k8s_service
        port = each.value.k8s_port
      }
      targetGroupARN = aws_lb_target_group.main_uat[each.key].arn
      targetType     = "instance"
    }
  }
}

# 4. LISTENER RULES (HTTPS UAT)

resource "aws_lb_listener_rule" "uat_rule_1" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["doc-classification-uat"].arn
  }
  condition {
    path_pattern {
      values = ["/api/document-embedding-classification/*"]
    }
  }
}

resource "aws_lb_listener_rule" "uat_rule_2" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 2
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["validus-uat"].arn
  }
  condition {
    path_pattern {
      values = ["/api/validus/*"]
    }
  }
}

resource "aws_lb_listener_rule" "uat_rule_3" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 3
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["doc-page-classification-uat"].arn
  }
  condition {
    path_pattern {
      values = ["/api/page-classification/*"]
    }
  }
}

resource "aws_lb_listener_rule" "uat_rule_4" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 4
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["doc-field-extraction-uat"].arn
  }
  condition {
    path_pattern {
      values = ["/api/field-extraction/*"]
    }
  }
}

resource "aws_lb_listener_rule" "uat_rule_5" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 5
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["text-extraction-uat"].arn
  }
  condition {
    path_pattern {
      values = ["/api/framev3/document-text-extraction/*"]
    }
  }
}

resource "aws_lb_listener_rule" "uat_rule_6" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 6
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["frame-uat"].arn
  }
  condition {
    path_pattern {
      values = ["/api/frame/*"]
    }
  }
}

resource "aws_lb_listener_rule" "uat_rule_7" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 7
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["common-service-uat"].arn
  }
  condition {
    path_pattern {
      values = ["/api/common/*"]
    }
  }
}

resource "aws_lb_listener_rule" "uat_rule_8" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 8
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["kong-gateway-uat"].arn
  }
  condition {
    host_header {
      values = ["uat-gateway.aithondev.com"]
    }
  }
}

resource "aws_lb_listener_rule" "uat_rule_9" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 9
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["rabbitmq-uat"].arn
  }
  condition {
    host_header {
      values = ["rabbitmq-uat.aithondev.com"]
    }
  }
}

resource "aws_lb_listener_rule" "uat_rule_10" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["airflow-uat"].arn
  }
  condition {
    host_header {
      values = ["airflow-uat.aithondev.com"]
    }
  }
}

# Rule 11: Keycloak UAT
resource "aws_lb_listener_rule" "uat_rule_11" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 11
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["keycloak-uat"].arn
  }
  condition {
    host_header {
      values = ["keycloak-uat.aithondev.com"]
    }
  }
}

# Rule 12: Kong Admin UAT
resource "aws_lb_listener_rule" "uat_rule_12" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 12
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["konga-uat"].arn
  }
  condition {
    host_header {
      values = ["konga-uat.aithondev.com"]
    }
  }
}

# Rule 13: ETL UAT (NEW)
resource "aws_lb_listener_rule" "uat_rule_13" {
  listener_arn = aws_lb_listener.https_uat.arn
  priority     = 13
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_uat["etl-uat"].arn
  }
  condition {
    host_header {
      values = ["etl-uat.aithondev.com"]
    }
  }
}
