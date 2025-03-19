terraform {
  cloud {
    hostname = "tfe20.aws.munnep.com"
    organization = "test"

    workspaces {
      name = "test"
    }
  }
}

resource "terraform_data" "test" {}