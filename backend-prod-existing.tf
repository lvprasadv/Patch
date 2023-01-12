terraform {
  backend "gcs" {
    bucket  = "ocgsh-csv-lbk-admin"
    prefix  = "terraformstatefiles/patching"
  }
}
