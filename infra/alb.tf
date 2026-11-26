resource "aws_lb" "main" {
  name               = local.name
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  idle_timeout       = 300 # WebSockets (Action Cable pings every 3 s, so this is generous)
}

resource "aws_lb_target_group" "web" {
  name                 = "${local.name}-web"
  port                 = 3000
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    path                = "/up"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "help_center" {
  name                 = "${local.name}-help"
  port                 = 3001
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    path     = "/healthz"
    matcher  = "200"
    interval = 15
  }
}

resource "aws_lb_target_group" "backend" {
  name                 = "${local.name}-backend"
  port                 = 4567
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30

  health_check {
    path     = "/healthz"
    matcher  = "200"
    interval = 15
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.help_center.arn
  }
}

resource "aws_lb_listener_rule" "web_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
  condition {
    path_pattern {
      values = ["/api/*", "/widget/*", "/widget.js", "/public/*", "/up"]
    }
  }
}

resource "aws_lb_listener_rule" "web_cable" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 11
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
  condition {
    path_pattern {
      values = ["/cable", "/cable/*", "/phone-sim/*"]
    }
  }
}

resource "aws_lb_listener_rule" "backend" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
  condition {
    path_pattern {
      values = ["/sites/*", "/tools/*", "/webhooks/*"]
    }
  }
}
