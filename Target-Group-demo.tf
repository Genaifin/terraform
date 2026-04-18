# ============================================================================
# TARGET-GROUP-DEMO.TF - IP MODE (POD-DIRECT ROUTING) — DEMO namespace
# (Kubernetes provider + EKS data: see Target-Group.tf)
# ============================================================================

# LOCALS — names and ports from `kubectl get svc -n demo` (and shared ns where noted)
locals {
  demo_target_group_services = {
    "document-page-classification" = { k8s_service = "doc-page-classification-service-demo", k8s_port = 8003, health_path = "/health", namespace = "demo" }
    "document-classification"      = { k8s_service = "doc-classification-service-demo", k8s_port = 8006, health_path = "/", namespace = "demo" }
    "document-field-extraction"    = { k8s_service = "doc-field-extraction-service-demo", k8s_port = 8004, health_path = "/api/field-extraction/health", namespace = "demo" }
    "text-extraction"              = { k8s_service = "text-extraction-service-demo", k8s_port = 8015, health_path = "/api/document-text-extraction/health", namespace = "demo" }
    "validus"                      = { k8s_service = "validus-service-demo", k8s_port = 8020, health_path = "/health", namespace = "demo" }
    "rabbit-mq"                    = { k8s_service = "rabbitmq-service-demo", k8s_port = 15672, health_path = "/api/health/checks/virtual-hosts", namespace = "demo" }
    "rabbit-mq-m"                  = { k8s_service = "rabbitmq-service-demo", k8s_port = 5672, health_path = "/", namespace = "demo" }
    "fvrk-demo-tg"                 = { k8s_service = "frame-validus-service-demo", k8s_port = 80, health_path = "/", namespace = "demo" }
    "frame"                        = { k8s_service = "frame-service-demo", k8s_port = 8040, health_path = "/health", namespace = "demo" }
    "common-service"               = { k8s_service = "common-service-service-demo", k8s_port = 8000, health_path = "/api/common/health", namespace = "demo" }
    "keycloak"                     = { k8s_service = "keycloak-service-demo", k8s_port = 8080, health_path = "/health/live", namespace = "demo" }
    "konga-service"                = { k8s_service = "konga-service-demo", k8s_port = 1337, health_path = "/status", namespace = "demo" }
    "kong-gateway"                 = { k8s_service = "kong-service-demo", k8s_port = 8000, health_path = "/api/common/health", namespace = "demo" }
    "etl-demo"                     = { k8s_service = "etl-deployment-demo", k8s_port = 5000, health_path = "/", namespace = "demo" }
    "grafana-k8s"                  = { k8s_service = "kube-prometheus-stack-grafana", k8s_port = 80, health_path = "/api/health", namespace = "monitoring" }
    "airflow"                      = { k8s_service = "airflow-webserver-nodeport-demo", k8s_port = 8080, health_path = "/", namespace = "airflow-demo" }
  }
}

resource "aws_lb_target_group" "main_demo" {
  for_each = local.demo_target_group_services

  # AWS ALB target group name max 32 chars; name_prefix is limited to 6 chars (see dev ip-tg-).
  name = substr(replace("ip-tg-demo-${each.key}", "_", "-"), 0, 32)

  port        = each.value.k8s_port
  protocol    = "HTTP"
  vpc_id      = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
  target_type = "ip"

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
    ManagedBy = "Terraform"
    App       = each.key
    Env       = "demo"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "kubernetes_manifest" "tg_bindings_demo" {
  for_each = local.demo_target_group_services

  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "${each.key}-demo-ip-binding"
      namespace = each.value.namespace
    }
    spec = {
      serviceRef = {
        name = each.value.k8s_service
        port = each.value.k8s_port
      }
      targetGroupARN = aws_lb_target_group.main_demo[each.key].arn
      targetType     = "ip"
    }
  }
}

# LISTENER RULES (HTTPS DEMO) — jenkins and argocd rules omitted vs Target-Group.tf

resource "aws_lb_listener_rule" "demo_rule_1" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["document-classification"].arn
  }
  condition {
    path_pattern { values = ["/api/document-embedding-classification/*"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_2" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 2
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["validus"].arn
  }
  condition {
    path_pattern { values = ["/api/validus/*"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_3" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 3
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["document-page-classification"].arn
  }
  condition {
    path_pattern { values = ["/api/page-classification/*"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_4" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 4
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["document-field-extraction"].arn
  }
  condition {
    path_pattern { values = ["/api/field-extraction/*"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_5" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 5
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["konga-service"].arn
  }
  condition {
    host_header { values = ["konga-demo.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_6" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 6
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["keycloak"].arn
  }
  condition {
    host_header { values = ["keycloak-demo.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_7" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 7
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["rabbit-mq"].arn
  }
  condition {
    host_header { values = ["rabbitmq-demo.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_8" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 8
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["text-extraction"].arn
  }
  condition {
    path_pattern { values = ["/api/document-text-extraction/*", "/api/framev3/document-text-extraction/*"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_9" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 9
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["kong-gateway"].arn
  }
  condition {
    host_header { values = ["demo-gateway.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_10" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["frame"].arn
  }
  condition {
    path_pattern { values = ["/api/frame/*"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_11" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 11
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["common-service"].arn
  }
  condition {
    path_pattern { values = ["/api/common/*"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_12" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 12
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["airflow"].arn
  }
  condition {
    host_header { values = ["demo-airflow.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_13" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 13
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["etl-demo"].arn
  }
  condition {
    host_header { values = ["etl-demo.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_14" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 14
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["grafana-k8s"].arn
  }
  condition {
    host_header { values = ["monitoring-demo.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "demo_rule_15" {
  listener_arn = aws_lb_listener.https_demo.arn
  priority     = 15
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_demo["etl-demo"].arn
  }
  condition {
    path_pattern { values = ["/api/etl/*"] }
  }
}
