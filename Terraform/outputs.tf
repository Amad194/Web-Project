output "vpc_id" {
  value = var.vpc_id
}

output "public_subnets" {
  value = aws_subnet.public.*.id
}

output "private_subnets" {
  value = aws_subnet.private.*.id
}

output "internet_gateway_id" {
  value = var.igw_id
}

output "web_instance_id" {
  value = aws_instance.web.id
}

output "rds_instance_endpoint" {
  value = aws_db_instance.default.endpoint
}

output "load_balancer_dns" {
  value = aws_lb.public.dns_name
}