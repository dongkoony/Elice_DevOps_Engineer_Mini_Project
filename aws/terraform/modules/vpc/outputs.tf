output "vpc_id" {
  description = "생성된 VPC의 ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC의 CIDR 블록"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "인터넷 게이트웨이의 ID"
  value       = aws_internet_gateway.main.id
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "데이터베이스 서브넷 ID 목록"
  value       = aws_subnet.database[*].id
}

output "database_subnet_group_name" {
  description = "데이터베이스 서브넷 그룹 이름"
  value       = aws_db_subnet_group.main.name
}

output "nat_gateway_ids" {
  description = "NAT 게이트웨이 ID 목록"
  value       = aws_nat_gateway.main[*].id
}

output "public_route_table_id" {
  description = "퍼블릭 라우팅 테이블 ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "프라이빗 라우팅 테이블 ID 목록"
  value       = aws_route_table.private[*].id
}

output "database_route_table_id" {
  description = "데이터베이스 라우팅 테이블 ID"
  value       = aws_route_table.database.id
} 