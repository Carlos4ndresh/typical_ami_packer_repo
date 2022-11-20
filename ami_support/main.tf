resource "aws_ssm_parameter" "latest_ami_id" {
  name        = "/demo/ec2/ami/latest"
  description = "Latest AMI Generated and approved (stable)"
  type        = "String"
  # This will change once the pipeline stage is approved
  value = "ami-xxxxxx"
}
