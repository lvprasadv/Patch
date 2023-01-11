terraform {
  backend "gcs" {
    bucket  = "ocgsh-csv-lbk-admin"
    prefix  = "terraform-patch/state"
  }
}
