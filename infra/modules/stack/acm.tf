resource "aws_acm_certificate" "this" {
  count = var.create_acm_certificate ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-cert" })

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.domain_name != "" && var.hosted_zone_id != ""
      error_message = "domain_name and hosted_zone_id are required when create_acm_certificate is true."
    }
  }
}

resource "aws_route53_record" "validation" {
  count = var.create_acm_certificate ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_type
  records = [tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_value]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  count = var.create_acm_certificate ? 1 : 0

  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [aws_route53_record.validation[0].fqdn]
}

resource "aws_route53_record" "app" {
  count = var.domain_name != "" && var.hosted_zone_id != "" ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}
