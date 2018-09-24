# -------------
# Bryan McCloskey
# bmccloskey@usgs.gov
# St. Petersburg Coastal and Marine Science Center
# US Geological Survey
#
# 07/10/2018
#--------------

print("These libraries must be installed: tools, RCurl")
# Required libraries. If not present, run:
# install.packages("tools")
# install.packages("RCurl")
library (tools)
library (RCurl)

# process batch from [offset] hours previous; time as "HH00" GMT
offset <- 60 * 60 * 1
process_time <- Sys.time() - offset
hour  <- format(process_time, "%H00", "GMT")
date  <- format(process_time, "%Y%m%d", "GMT")
doy   <- format(process_time, "%j", "GMT")
month <- format(process_time, "%b", "GMT")
day   <- format(process_time, "%d", "GMT")
year  <- format(process_time, "%Y", "GMT")

remote_dir <- "ftp://ftpint.usgs.gov/from_pub/er/sandkey/"
remote_dir2 <- "ftp://ftpext.usgs.gov/from_pub/er/sandkey/"
local_dir <- paste0("./sandkey/images/", date, "_", hour, "/")
dir.create(local_dir)

report <- cleanup <- ""

manifest_file <- paste0("status_", date, "_", hour, ".txt")
local_manifest <- paste0(local_dir, manifest_file)
remote_manifest <- paste0(remote_dir, manifest_file)

# download hourly manifest -- try three times
attempt <- 1
while ((!file.exists(local_manifest) | !file.info(local_manifest)$size) & attempt <= 3) {
  attempt <- attempt + 1
  try (download.file(remote_manifest, local_manifest))
}
if (!file.exists(local_manifest) | !file.info(local_manifest)$size) {
  report <- paste("Hourly image transfer failed for", date, hour, "-- no manifest file retrieved.")
} else {
  if(!dir.exists("/Volumes/Coastal_Change_Hazards")) {
    system("open 'smb://gs.doi.net/stpetersburgfl-g/Coastal_Change_Hazards'")
    Sys.sleep(45) # Wait to mount Coastal_Change_Hazards
  }
  nacch_dir <- paste0("/Volumes/Coastal_Change_Hazards/Archive/Data/2018/2018-302-DD_20180413_20191231/sandkey/", year, "/c2/", doy, "_", month, ".", day, "/")
  nacch_dir2 <- paste0("/Volumes/Coastal_Change_Hazards/Archive/Data/2018/2018-302-DD_20180413_20191231/sandkey/", year, "/cx/", doy, "_", month, ".", day, "/")
  dir.create(nacch_dir)
  dir.create(nacch_dir2)
  file_list <- scan(local_manifest, "character", sep = "\n")
  start <- which(file_list == "Files in  to be transferred: ") + 1
  end <- which(file_list == "File checksums: ") - 2
  file_list <- file_list[start:end]

  for (i in 1:length(file_list)) {
    file <- strsplit(file_list[i], " ")[[1]][5]
    local_file <- paste0(local_dir, file)
    remote_file <- paste0(remote_dir, file)
    
    # retrieve files from FTP -- try three times
    attempt <- 1
    while ((!file.exists(local_file) | !file.info(local_file)$size) & attempt <= 3) {
      attempt <- attempt + 1
      try (download.file(remote_file, local_file))
    }
    if (!file.exists(local_file) | !file.info(local_file)$size) {
      report <- paste(report, "eFTP retrieval failed for image", file, "\n")
    } else {
      
      # verify checksum
      #local_checksum <- toupper(md5sum(local_file))
      #remote_checksum <- strsplit(file_list[i], "  ")[[1]][1]
      #if (local_checksum != remote_checksum) {
      #  report <- paste(report, "Checksum mismatch for", file, "\n")
      #} else {
        
        # transfer to Coastal_Change_Hazards
        if (strsplit(file_list[i], "\\.")[[1]][8] == "c2") dir <- nacch_dir else dir <- nacch_dir2
        err <- try(file.copy(local_file, paste0(dir, file)))
        if (inherits(err, "try-error")) {
          report <- paste(report, "Coastal_Change_Hazards file transfer failed for", file, "\n")
        } else {
          
          # everything successful; OK to add file to list to be deleted from camera machine
          cleanup <- paste0(cleanup, "del \"C:\\Users\\camerauser\\sandkey\\toBeSent\\c2\\", doy, "_", month, ".", day, "\\", hour, "\\", file, "\"\n")
          # transfer jpg for webserver
          if (file_ext(file) == "jpg") {
            attempt <- err <- 1
            while (err & attempt <= 3) {
              attempt <- attempt + 1
              err <- try (system(paste0("curl -T ", local_dir, file, " ", remote_dir, date, "_", hour, "_", substring(file, 41))))
            }
          }
        }
      #}
    }
  }
  if (cleanup != "") {
    write(cleanup, paste0(local_dir, "cleanup.txt"))
    attempt <- err <- 1
    while (err & attempt <= 3) {
      attempt <- attempt + 1
      err <- try (system(paste0("curl -T ", local_dir, "cleanup.txt ftp://ftpint.usgs.gov/pub/er/fl/st.petersburg/sandkey/", date, "_", hour, "_cleanup.bat")))
    }
    if (err) report <- paste0(report, "cleanup.bat file NOT transferred to FTP server")
  }
}

#system("umount /Volumes/Coastal_Change_Hazards") #Doesn't work when run from cron

# send email notice if any problems
if (report != "")
  system(paste0("echo 'Subject: sandkeyC2 image transfer

", report, "' | /usr/sbin/sendmail bmccloskey@usgs.gov, jenniferbrown@usgs.gov, jbirchler@usgs.gov"))
