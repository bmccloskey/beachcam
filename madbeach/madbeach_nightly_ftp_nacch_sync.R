library(RCurl)

remote_dir<-"ftp://ftpint.usgs.gov/from_pub/er/madbeach/"

ftp_output<-getURL(remote_dir)
ftp_contents<-strsplit(ftp_output,"\r*\n")[[1]]
searchstring<-".*([0-9]{10}\\.[A-Za-z]{3}\\.[A-Za-z]{3}\\.[0-9]{2}_[0-9]{2}_00_00\\.GMT\\.20[1-2][7-9]\\.madbeach\\.c(1|x)\\.(bright|dark|snap|timex|var|cBathy|runup150|runup250|runup90)\\.(jpg|mat)$)"
indices<-grep(searchstring,ftp_contents)
ftp_files<-sub(searchstring,"\\1",ftp_contents[indices])

if(!dir.exists("/Volumes/NACCH")) {
  system("open 'smb://gs.doi.net/stpetersburgfl-g/NACCH'")
  Sys.sleep(45) # Wait to mount NAACH
}

report<-cleanup<-""

base_dir<-"/Volumes/NACCH/Archive/Data/2016/2016-363-DD_20161028/madbeach/"
if(dir.exists(base_dir))
  for(i in 1:length(ftp_files)) {
    tokens<-unlist(strsplit(ftp_files[i],"\\."))
    hour<-paste0(substr(tokens[4],4,5),"00")
    month<-tokens[3]
    day<-substr(tokens[4],1,2)
    doy<-format(as.Date(paste(tokens[6],month,day),format="%Y %b %d"),"%j")
    date<-format(as.Date(paste(tokens[6],month,day),format="%Y %b %d"),"%Y%m%d")
    nacch_dir<-paste0(base_dir,tokens[6],"/",tokens[8],"/",doy,"_",month,".",day,"/")
    if(!dir.exists(nacch_dir)) dir.create(nacch_dir)
    if(!file.exists(paste0(nacch_dir,ftp_files[i]))) {
      report<-paste(report,"File",ftp_files[i],"not found on NACCH server.\n")
      local_dir<-paste0("/Users/bmcclosk/Desktop/R/madbeach/images/",date,"_",hour,"/")
      dir.create(local_dir)
      local_file<-paste0(local_dir,ftp_files[i])
  
      # retrieve files from FTP -- try three times
      err<-try(download.file(paste0(remote_dir,ftp_files[i]),local_file))
      if (inherits(err,"try-error") | !file.exists(local_file) | !file.info(local_file)$size)
        err<-try(download.file(paste0(remote_dir,ftp_files[i]),local_file))
      if (inherits(err,"try-error") | !file.exists(local_file) | !file.info(local_file)$size)
        err<-try(download.file(paste0(remote_dir,ftp_files[i]),local_file))
      if (inherits(err,"try-error") | !file.exists(local_file) | !file.info(local_file)$size) {
        report<-paste(report,"eFTP retrieval failed for image",ftp_files[i],"\n")
      } else {
        # transfer to NACCH
        err<-try(file.copy(local_file,paste0(nacch_dir,ftp_files[i])))
        if (inherits(err,"try-error")) {
          report<-paste(report,"NACCH file transfer failed for",ftp_files[i],"\n")
        } else {
          report<-paste(report,"NACCH file transfer succeeded for",ftp_files[i],"\n")
          # everything successful; OK to add file to list to be deleted from camera machine
          cleanup<-paste0(cleanup,"del \"C:\\Users\\video\\madbeach\\toBeSent\\",doy,"_",month,".",day,"\\",hour,"\\",ftp_files[i],"\"\n")
        }
      }
    }
  } else report<-"Error: Cannot connect to NACCH drive"

if(cleanup!="") {
  cleanup_dir<-"/Users/bmcclosk/Desktop/R/madbeach/images/"
  write(cleanup,file=paste0(cleanup_dir,"cleanup4am.txt"))
  err<-try(system(paste0("curl -T ",cleanup_dir,"cleanup4am.txt ftp://ftpint.usgs.gov/pub/er/fl/st.petersburg/madbeach/cleanup4am.bat")))
  if (err)
    err<-try(system(paste0("curl -T ",cleanup_dir,"cleanup4am.txt ftp://ftpint.usgs.gov/pub/er/fl/st.petersburg/madbeach/cleanup4am.bat")))
  if (err)
    err<-try(system(paste0("curl -T ",cleanup_dir,"cleanup4am.txt ftp://ftpint.usgs.gov/pub/er/fl/st.petersburg/madbeach/cleanup4am.bat")))
  if (err) report<-paste0(report,"cleanup4am.bat file NOT transferred to FTP server")
}

# send email notice if any missing files transferred or any problems
if (report!="")
  system(paste0("echo 'Subject: madbeach FTP/NACCH image sync transfer

",report,"' | /usr/sbin/sendmail bmccloskey@usgs.gov,jenniferbrown@usgs.gov"))