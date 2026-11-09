resource "random_password" "db" {
  length  = 32
  special = false
}

resource "random_password" "app_secret" {
  length  = 64
  special = true
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name_prefix}/db"
  description             = "Application database credentials for ${local.name_prefix}"
  recovery_window_in_days = var.environment == "production" ? 30 : 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username       = var.db_username
    password       = random_password.db.result
    host           = aws_db_instance.this.address
    port           = aws_db_instance.this.port
    dbname         = var.db_name
    engine         = "postgres"
    app_secret_key = random_password.app_secret.result
  })
}
