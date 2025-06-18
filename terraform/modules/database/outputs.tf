output "db_instance_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "The hostname of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "The port of the RDS instance"
  value       = aws_db_instance.main.port
}

output "db_instance_username" {
  description = "The master username for the RDS instance"
  value       = aws_db_instance.main.username
}

output "db_instance_name" {
  description = "The name of the database"
  value       = aws_db_instance.main.db_name
}
