moved {
  from = aws_eip.nat
  to   = module.vpc.module.vpc.aws_eip.nat[0]
}

moved {
  from = aws_internet_gateway.main
  to   = module.vpc.module.vpc.aws_internet_gateway.this[0]
}

moved {
  from = aws_nat_gateway.main
  to   = module.vpc.module.vpc.aws_nat_gateway.this[0]
}

moved {
  from = aws_route_table.private
  to   = module.vpc.module.vpc.aws_route_table.private[0]
}

moved {
  from = aws_route_table.public
  to   = module.vpc.module.vpc.aws_route_table.public[0]
}

moved {
  from = aws_route_table_association.private
  to   = module.vpc.module.vpc.aws_route_table_association.private
}

moved {
  from = aws_route_table_association.public
  to   = module.vpc.module.vpc.aws_route_table_association.public
}

moved {
  from = aws_vpc.main
  to   = module.vpc.module.vpc.aws_vpc.this[0]
}

moved {
  from = aws_subnet.private
  to   = module.vpc.module.vpc.aws_subnet.private
}

moved {
  from = aws_subnet.public
  to   = module.vpc.module.vpc.aws_subnet.public
}