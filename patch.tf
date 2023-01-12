########### data block to fetch projects under specific folder id ###########
## when both api and patch files are using data blocks are duplicate
/* 
data "google_projects" "folder-projects" {
  filter = "parent.id:994943896596 lifecycleState:ACTIVE"
}
data "google_project" "project" {
    count = length(data.google_projects.folder-projects.projects)
    project_id = data.google_projects.folder-projects.projects[count.index].project_id
}
#this will be used for all active based on folder id, but this approach we are going for SM, POD teams spearately
*/
  
########## os patch scheduled deployments ################

resource "google_os_config_patch_deployment" "linux_patch_deployments" {
  patch_deployment_id = "oc-linux-daily-patch"
  
 count = length(data.google_project.project[*].project_id)   #these are used for folder id based data block as above
 project = data.google_project.project[count.index].project_id

 # count = "${length(var.proj_id)}"
 # project  = "${element(var.proj_id, count.index)}"
  
  instance_filter {
    zones = ["us-east1-b", "us-central1-b", "us-central1-f", "us-central1-c", "us-central1-a", "us-east1-c", "us-east1-d", "us-east4-c", "us-east4-a", "us-west1-b", "us-west1-a"]

    group_labels {
      labels = {
        os_type = "linux"
      }
    }
  }


  duration = "12600s"

  recurring_schedule {
    time_of_day {
      hours   = 0
      minutes = 15
    }

    time_zone {
      id = "America/New_York"
    }
  }

  patch_config {

    yum {
      security = true
      minimal = true
      excludes = ["bash"]     
    }
    
    apt {
      type = "DIST"
      excludes = ["python"]
    }

    zypper {
      categories = ["security", "recommended"]
      severities = ["critical", "important"]
    }

    pre_step {
      linux_exec_step_config {
        interpreter = "SHELL"
        gcs_object {
          bucket            = var.bucket_name
          object            = "patching/linux-presnapshot.sh"
          generation_number = var.gen_number_linux_presnapshot
        }
      }
    }
  }

  rollout {
    mode = "ZONE_BY_ZONE"
    disruption_budget {
      percentage = 20
    }
  }
}

resource "google_os_config_patch_deployment" "windows_patch_deployments" {
  patch_deployment_id = "oc-windows-daily-patch"
  
  count = length(data.google_project.project[*].project_id)   #these are used for folder id based data block as above
  project = data.google_project.project[count.index].project_id
  
  #count = "${length(var.proj_id)}"
  #project  = "${element(var.proj_id, count.index)}"

  instance_filter {
    zones = ["us-east1-b", "us-central1-b", "us-central1-f", "us-central1-c", "us-central1-a", "us-east1-c", "us-east1-d", "us-east4-c", "us-east4-a", "us-west1-b", "us-west1-a"]

    group_labels {
      labels = {
        os_type = "windows"
      }
    }
  }

  duration = "12600s"

  recurring_schedule {
    time_of_day {
      hours   = 0
      minutes = 30
    }

    time_zone {
      id = "America/New_York"
    }
  }

  patch_config {

    windows_update {
      classifications = ["CRITICAL", "SECURITY", "DEFINITION", "UPDATE"]
    }
    
    pre_step {
      windows_exec_step_config {
        interpreter = "POWERSHELL"
        gcs_object {
          bucket            = var.bucket_name
          object            = "patching/windows-presnapshot.ps1"
          generation_number = var.gen_number_windows_presnapshot
        }
      }
    }
  }

  rollout {
    mode = "ZONE_BY_ZONE"
    disruption_budget {
      percentage = 20
    }
  }
}


#windows post patch fix ocgsh-csv-lbk-admin/radius-post-patch.ps1 details
