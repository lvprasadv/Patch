########### data block to fetch projects under specific folder id ###########
/*
data "google_projects" "folder-projects" {
  filter = "parent.id:614695899438 lifecycleState:ACTIVE"
}

data "google_project" "project" {
    count = length(data.google_projects.folder-projects.projects)
    project_id = data.google_projects.folder-projects.projects[count.index].project_id
}
#this will be used for all active based on folder id, but this approach we are going for SM, POD teams spearately
*/
  

######## resource to enable the required on api on the folder id provided ############

resource "google_project_service" "osconfig_api" {
  
  count = length(var.proj_id)
  project  = var.proj_id[count.index]
  
   service   = "osconfig.googleapis.com"
   disable_dependent_services = true
}

resource "google_project_service" "cloudresourcemanager_api" {
  
  count = length(var.proj_id)
  project  = var.proj_id[count.index]
   service   = "cloudresourcemanager.googleapis.com"
   disable_dependent_services = true
}


######### enable metadata config ############
resource "google_compute_project_metadata_item" "osconfig_enable_meta" {
   
   #count = length(data.google_project.project[*].project_id)
   #project = data.google_project.project[count.index].project_id
  count = length(var.proj_id)
  project  = var.proj_id[count.index]
  
  key        = "enable-osconfig"
  value      = "TRUE"
  depends_on = [google_project_service.iam_api]
}

resource "google_compute_project_metadata_item" "osconfig_log_level_meta" {

  count = length(var.proj_id)
  project  = var.proj_id[count.index]

  key        = "osconfig-log-level"
  value      = "debug"
  depends_on = [google_project_service.iam_api]
}
