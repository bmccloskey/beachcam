# beachcam

**beachcam** is a collection of R scripts to retrieve hourly sets of photos from the USGS eFTP, perform checksum calculations, archive to NACCH/CCH drives, post to the Coastal web page, and produce clean-up files for the originating computer.

## Description of **beachcam** folders

- **madbeach:** Collect hourly photo sets from the Madeira Beach computer camera, perfoms a checksum confirmation, and stores to NACCH archive; nightly run sync script to catch any images missed throughout the day.
- **sandkey:** Collect hourly photo sets from the Sand Key Beach computer cameras C1 and C2 and stores to Coastal_Change_Hazards archive; nightly run sync script to catch any images missed throughout the day.

## Job timing

- **madbeach_transfer_to_nacch.R:**  09:40 - 19:40 hourly.
- **sandkeyC1_transfer_to_cch.R:** 09:50 - 20:50 hourly.
- **sandkeyC2_transfer_to_cch.R:** 09:20 - 20:20 hourly.
- **madbeach_nightly_ftp_nacch_sync.R:** 04:00 daily.
- **sandkey_nightly_ftp_cch_sync.R:** 04:15 daily.