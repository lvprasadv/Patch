variable "proj_id" {
  description = "Pass specific proj id for enabling api"
  type        = list(string)
  default     = ["", "", ""]
}
 variable "bucket_name" {
   description = "Bucket where exe are placed"
   type        = string
}

 variable "gen_number_linux_presnapshot" {
   description = "Generation number of linux presnapshot available in GCS"
   type        = string
}

 variable "gen_number_windows_presnapshot" {
   description = "Generation number of windows presnapshot available in GCS"
   type        = string
}


