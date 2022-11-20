# Example Packer AMI Pipeline using AWS CodeTools

A Demo on how to integrate Hashicorp's [Packer](https://www.packer.io/) AMI building with CodePipeline/CodeBuild in AWS.

## Repo Structure

This repo is divided between Terraform resources, Packer scripts alonside CodeBuild YAML files:

- ami_support: Creates an SSM Parameter to Store the updated AMI ID once it gets "approved" on the pipeline
- ami_pipeline: The Full CodePipeline/CodeBuild creation. Also creates CodeStar connection required for GitHub
- test: A Folder that contains the Test Packer Script, and buildspec file for CodeBuild.
- storessm: This folder contains the buildspec.yml file that will grab AMI ID from the build and store it in SSM Param Store after approval.

## Pipeline structure

The pipeline has the 3 following stages:

- Source; a regular source stage that clones the Git Repo
- Test_Build: Testing the AMI Build process. Effectively doing the same as the Build stage, you could introduce here some testing to your EC2.
- Build_AMI: The build AMI stage it's divided on 3 actions:
  - Build AMI: Builds the final AMI.
  - Manual Approval: A simple manual approval step to release the AMI.
  - Release AMI: Stores the AMI ID in an SSM parameter.

## Outcome

As an outcome you'll get an AMI in the specified region and account; and that AMI ID stored in an SSM parameter to be programatically queried when needed.

## Next steps

You should validate the AMI it's valid before realising it, so you could modify the testing phase and add automated testing on it, that alongside the Manual Approval could release the AMI.
