## GitHub Connection Stuff
data "aws_codestarconnections_connection" "github_connection" {
  arn = "arn:aws:codestar-connections:us-east-1:982656938909:connection/633ca6f5-e69f-439a-b3fb-6556533ff285"
}

## IAM Stuff

data "aws_iam_policy_document" "codepipeline_ami_assume_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "template_file" "codepipeline_policy_template" {
  template = file("./files/codepipeline_policy.json.tpl")
  vars = {
    bucket                 = aws_s3_bucket.ami_pipeline_artifact_store.arn
    codebuild_project      = aws_codebuild_project.build_ami_packer.arn
    codebuild_test_project = aws_codebuild_project.validate_packer_build.arn
    codestar_conn          = data.aws_codestarconnections_connection.github_connection.arn
  }
}

resource "aws_iam_policy" "codepipeline_role_policy" {
  name        = "CodePipeline_ami_pipeline_policy"
  path        = "/"
  description = "Policy for the ami pipeline"
  policy      = data.template_file.codepipeline_policy_template.rendered
}

resource "aws_iam_role_policy_attachment" "codepipeline_role_attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_role_policy.arn
}


resource "aws_iam_role" "codepipeline_role" {
  name               = "ami-packer-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_ami_assume_policy.json
}

data "aws_iam_policy_document" "codebuild_ami_assume_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "template_file" "codebuild_policy_template" {
  template = file("./files/codebuild_policy.json.tpl")
  vars = {
    bucket                 = aws_s3_bucket.ami_pipeline_artifact_store.arn
    codebuild_project      = aws_codebuild_project.build_ami_packer.arn
    codebuild_test_project = aws_codebuild_project.validate_packer_build.arn
    codestar_conn          = data.aws_codestarconnections_connection.github_connection.arn
  }
}

resource "aws_iam_role" "codebuild_assume_role" {
  name               = "ami-packer-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_ami_assume_policy.json
}

resource "aws_iam_policy" "codebuild_role_policy" {
  name        = "CodeBuild_ami_pipeline_policy"
  path        = "/"
  description = "Policy for the codebuild ami project"
  policy      = data.template_file.codebuild_policy_template.rendered
}

resource "aws_iam_role_policy_attachment" "allow_codebuild_do_stuff" {
  role       = aws_iam_role.codebuild_assume_role.name
  policy_arn = aws_iam_policy.codebuild_role_policy.arn
}

# Actual Useful stuff
resource "aws_s3_bucket" "ami_pipeline_artifact_store" {
  bucket        = "ami-packer-pipeline-artifact-store"
  acl           = "private"
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "block_all_artifact_bucket" {
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
  bucket                  = aws_s3_bucket.ami_pipeline_artifact_store.id
}


resource "aws_codepipeline" "ami_pipeline" {
  name     = "ami-packer-demo-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    location = aws_s3_bucket.ami_pipeline_artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = data.aws_codestarconnections_connection.github_connection.arn
        BranchName       = "main"
        FullRepositoryId = "Carlos4ndresh/typical_ami_packer_repo"
      }

    }
  }

  stage {
    name = "Test_Build"
    action {
      category        = "Test"
      name            = "ValidatePackerBuild"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration = {
        "ProjectName" = aws_codebuild_project.validate_packer_build.name
      }
    }
  }

  stage {
    name = "Build_AMI"
    action {
      name            = "Build_AMI"
      owner           = "AWS"
      provider        = "CodeBuild"
      category        = "Build"
      input_artifacts = ["source_output"]
      version         = "1"
      configuration = {
        "ProjectName" = aws_codebuild_project.build_ami_packer.name
      }
    }
  }

}

resource "aws_codebuild_project" "validate_packer_build" {
  name          = "packer-validate-build"
  description   = "The CodeBuild project to validate build packer AMIs"
  service_role  = aws_iam_role.codebuild_assume_role.arn
  build_timeout = "60"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "test/buildspec_test.yml"
  }

}

resource "aws_codebuild_project" "build_ami_packer" {
  name          = "ami-packer-build"
  description   = "The CodeBuild project to build packer AMIs"
  service_role  = aws_iam_role.codebuild_assume_role.arn
  build_timeout = "60"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

}
