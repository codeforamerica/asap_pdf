moved {
  from = module.cache
  to   = module.asap_pdf.module.cache
}

moved {
  from = module.deployment
  to   = module.asap_pdf.module.deployment
}

moved {
  from = module.networking
  to   = module.asap_pdf.module.networking
}

moved {
  from = module.database
  to   = module.asap_pdf.module.database
}

moved {
  from = module.ecs
  to   = module.asap_pdf.module.ecs
}

moved {
  from = module.lambda
  to   = module.asap_pdf.module.lambda
}


moved {
  from = module.logging
  to   = module.asap_pdf.module.logging
}

moved {
  from = module.secrets
  to   = module.asap_pdf.module.secrets
}

moved {
  from = module.ses
  to   = module.asap_pdf.module.ses
}

moved {
  from = aws_s3_bucket.documents
  to   = module.asap_pdf.aws_s3_bucket.documents
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.documents
  to   = module.asap_pdf.aws_s3_bucket_server_side_encryption_configuration.documents
}

moved {
  from = aws_s3_bucket_versioning.documents
  to   = module.asap_pdf.aws_s3_bucket_versioning.documents
}
