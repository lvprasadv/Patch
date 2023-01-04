########## os patch scheduled deployments ################

resource "google_os_config_patch_deployment" "linux_patch_deployments" {
  patch_deployment_id = "oc-linux-monthly-patch"
  
  count = length(data.google_project.project[*].project_id)
  project = data.google_project.project[count.index].project_id

  instance_filter {
    zones = ["us-east1-b", "us-central1-b", "us-central1-f", "us-central1-c", "us-central1-a", "us-east1-c", "us-east1-d", "us-east4-c", "us-east4-a", "us-west1-b", "us-west1-a"]

    group_labels {
      labels = {
        os = "linux"
      }
    }
  }

    # For all VM instances Target all VM instances in the project. If true, no other criteria is permitted
#   instance_filter {
#    all = true
#  }
  
  duration = "12600s"

  recurring_schedule {
    monthly {
      week_day_of_month {
        week_ordinal = 1
        day_of_week  = "SATURDAY"
      }
    }

    time_of_day {
      hours   = 10
      minutes = 30
    }

    time_zone {
      id = "America/New_York"
    }
  }

  patch_config {

    yum {
      security = true
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
  patch_deployment_id = "oc-windows-monthly-patch"
  
  count = length(data.google_project.project[*].project_id)
  project = data.google_project.project[count.index].project_id

  instance_filter {
    zones = ["us-east1-b", "us-central1-b", "us-central1-f", "us-central1-c", "us-central1-a", "us-east1-c", "us-east1-d", "us-east4-c", "us-east4-a", "us-west1-b", "us-west1-a"]

    group_labels {
      labels = {
        os = "windows"
      }
    }
  }

  duration = "12600s"

  recurring_schedule {
    monthly {
      week_day_of_month {
        week_ordinal = 1
        day_of_week  = "SATURDAY"
      }
    }

    time_of_day {
      hours   = 10
      minutes = 30
    }

    time_zone {
      id = "America/New_York"
    }
  }

  patch_config {

    yum {
      security = true
    }

    zypper {
      categories = ["security", "recommended"]
      severities = ["critical", "important"]
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
