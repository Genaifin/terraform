# ============================================================================
# TARGET-GROUP.TF - IP MODE (POD-DIRECT ROUTING)
# ============================================================================

# 1. KUBERNETES PROVIDER
data "aws_eks_cluster" "cluster" {
  name = "FVKR-DEV"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", "FVKR-DEV"]
    command     = "aws"
  }
}

# 2. LOCALS 
locals {
  target_group_services = {
    "document-page-classification" = { k8s_service = "doc-page-classification-service", k8s_port = 8003, health_path = "/health", namespace = "dev" }
    "document-classification"      = { k8s_service = "doc-classification-service", k8s_port = 8006, health_path = "/", namespace = "dev" }
    "document-field-extraction"    = { k8s_service = "doc-field-extraction-service", k8s_port = 8004, health_path = "/api/field-extraction/health", namespace = "dev" }
    "text-extraction"              = { k8s_service = "text-extraction-service", k8s_port = 8015, health_path = "/api/document-text-extraction/health", namespace = "dev" }
    "validus"                      = { k8s_service = "validus-service", k8s_port = 8020, health_path = "/health", namespace = "dev" }
    "rabbit-mq"                    = { k8s_service = "rabbitmq-service", k8s_port = 15672, health_path = "/api/health/checks/virtual-hosts", namespace = "rabbitmq-system" }
    "rabbit-mq-m"                  = { k8s_service = "rabbitmq-service-m", k8s_port = 5672, health_path = "/", namespace = "rabbitmq-system" }
    "fvrk-dev-tg"                  = { k8s_service = "frame-validus-service", k8s_port = 80, health_path = "/", namespace = "dev" }
    "frame"                        = { k8s_service = "frame-service", k8s_port = 8040, health_path = "/health", namespace = "dev" }   
    "common-service"               = { k8s_service = "common-service-service", k8s_port = 8000, health_path = "/api/common/health", namespace = "dev" }
    "keycloak"                     = { k8s_service = "keycloak-service", k8s_port = 8080, health_path = "/health/live", namespace = "dev" }
    "konga-service"                = { k8s_service = "konga-service", k8s_port = 1337, health_path = "/status", namespace = "dev" }
    "kong-gateway"                 = { k8s_service = "kong-service", k8s_port = 8000, health_path = "/api/common/health", namespace = "dev" }
    "jenkins-tg"                   = { k8s_service = "jenkins-service", k8s_port = 8080, health_path = "/login", namespace = "dev" }
    "argocd"                       = { k8s_service = "argocd-server-nodeport", k8s_port = 80, health_path = "/healthz", namespace = "argocd" } 
    "airflow"                      = { k8s_service = "airflow-webserver-nodeport", k8s_port = 8080, health_path = "/", namespace = "airflow" }
    "etl-dev"                      = { k8s_service = "etl-deployment-dev", k8s_port = 5000, health_path = "/", namespace = "dev" }
    "grafana-k8s"                  = { k8s_service = "kube-prometheus-stack-grafana", k8s_port = 80, health_path = "/api/health", namespace = "monitoring" }
    "schedulerapi-dev"             = { k8s_service = "schedulerapi-service-dev", k8s_port = 5000, health_path = "/", namespace = "dev" }
  }
}

# 3. AWS TARGET GROUPS (Using IP mode)
resource "aws_lb_target_group" "main" {
  for_each = local.target_group_services


  name_prefix = "ip-tg-" 
  
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
  }

 
  lifecycle {
    create_before_destroy = true
  }
}

# 4. KUBERNETES BINDINGS (Using IP mode)
resource "kubernetes_manifest" "tg_bindings" {
  for_each = local.target_group_services

  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "${each.key}-ip-binding"
      namespace = each.value.namespace
    }
    spec = {
      serviceRef = {
        name = each.value.k8s_service
        port = each.value.k8s_port
      }
      targetGroupARN = aws_lb_target_group.main[each.key].arn
      targetType     = "ip" # <--- CHANGED TO IP MODE
    }
  }
}

# 5. LISTENER RULES (Unchanged)
resource "aws_lb_listener_rule" "rule_1" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["document-classification"].arn
  }
  condition {
    path_pattern { values = ["/api/document-embedding-classification/*"] }
  }
}

resource "aws_lb_listener_rule" "rule_2" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 2
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["validus"].arn
  }
  condition {
    path_pattern { values = ["/api/validus/*"] }
  }
}

resource "aws_lb_listener_rule" "rule_3" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 3
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["jenkins-tg"].arn
  }
  condition {
    host_header { values = ["jenkins.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "rule_4" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 4
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["argocd"].arn
  }
  condition {
    host_header { values = ["argocd.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "rule_5" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 5
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["document-page-classification"].arn
  }
  condition {
    path_pattern { values = ["/api/page-classification/*"] }
  }
}

resource "aws_lb_listener_rule" "rule_6" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 6
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["document-field-extraction"].arn
  }
  condition {
    path_pattern { values = ["/api/field-extraction/*"] }
  }
}

resource "aws_lb_listener_rule" "rule_7" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 7
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["konga-service"].arn
  }
  condition {
    host_header { values = ["konga.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "rule_8" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 8
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["keycloak"].arn
  }
  condition {
    host_header { values = ["keycloak.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "rule_9" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 9
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["rabbit-mq"].arn
  }
  condition {
    host_header { values = ["rabbitmq.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "rule_10" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["text-extraction"].arn
  }
  condition {
    path_pattern { values = ["/api/document-text-extraction/*", "/api/framev3/document-text-extraction/*"] }
  }
}

resource "aws_lb_listener_rule" "rule_11" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 11
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["kong-gateway"].arn
  }
  condition {
    host_header { values = ["sit-gateway.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "rule_12" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 12
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["frame"].arn
  }
  condition {
    path_pattern { values = ["/api/frame/*"] }
  }
}

resource "aws_lb_listener_rule" "rule_13" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 13
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["common-service"].arn
  }
  condition {
    path_pattern { values = ["/api/common/*"] }
  }
}

resource "aws_lb_listener_rule" "rule_15" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 15
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["airflow"].arn
  }
  condition {
    host_header { values = ["airflow.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "rule_16" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 16
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["etl-dev"].arn
  }
  condition {
    host_header { values = ["etl-dev.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "rule_17" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 17
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["grafana-k8s"].arn
  }
  condition {
    host_header { values = ["monitoring.aithondev.com"] }
  }
}

resource "aws_lb_listener_rule" "rule_18" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 18
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["schedulerapi-dev"].arn
  }
  condition {
    path_pattern { values = ["/api/scheduler/*"] }
  }
}

resource "aws_lb_listener_rule" "rule_19" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 19
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["etl-dev"].arn
  }
  condition {
    path_pattern { values = ["/api/etl/*"] }
  }
}