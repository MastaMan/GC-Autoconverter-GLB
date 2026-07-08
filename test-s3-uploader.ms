/*
	S3 uploader manual test

	Usage:
	1. Run the main GC-Autoconverter-GLB.ms script first.
	2. Make sure AWS S3 settings are loaded in the main script.
	3. Run this file and choose any local file to upload.
*/

try (destroyDialog _rGCTestS3Uploader) catch()

rollout _rGCTestS3Uploader "S3 Upload Test" width: 560 (
	local lastFileKey = "testS3UploaderLastFile"
	local fallbackIni = (getFilenamePath (getSourceFileName())) + "test-s3-uploader.ini"

	group "File" (
		edittext edtFile "" width: 440 align: #left across: 2
		button btnPick "..." width: 32 align: #right
	)
	group "Result" (
		label lblResult "Ready" width: 520 align: #left
	)
	button btnUpload "Upload selected file" width: 180 align: #center
	group "Upload Log" (
		edittext edtLog "" width: 520 height: 260 readonly: true
		button btnClearLog "Clear log" width: 90 align: #right
	)

	fn getUploader = (
		try (return awsUploaderMgr) catch (return undefined)
	)

	fn getSavedFile = (
		local f = ""
		try (f = '*'.get lastFileKey) catch ()
		if (f == undefined or f == "") do (
			try (f = getIniSetting fallbackIni "S3 Upload Test" lastFileKey) catch ()
		)
		if (f == undefined) do f = ""
		return f
	)

	fn saveFile f = (
		if (f == undefined or f == "") do return false
		try ('*'.add lastFileKey f) catch ()
		try (setIniSetting fallbackIni "S3 Upload Test" lastFileKey f) catch ()
		return true
	)

	fn getTimeLabel = (
		local dt = (dotNetClass "System.DateTime").Now
		return dt.ToString "yyyy-MM-dd HH:mm:ss"
	)

	fn appendLog msg = (
		local line = "[" + getTimeLabel() + "] " + msg
		if (edtLog.text == "") then (
			edtLog.text = line
		) else (
			edtLog.text += "\r\n\r\n" + line
		)
		format "%\n" line
	)

	fn setResult msg log: true = (
		lblResult.caption = msg
		if (log) do appendLog msg
	)

	fn validateUploader uploader = (
		if (uploader == undefined) do (
			setResult "awsUploaderMgr not found. Run the main script first."
			messageBox "awsUploaderMgr not found. Run the main script first." title: "S3 Upload Test"
			return false
		)

		if (uploader.checkCredentialsError()) do (
			setResult "AWS S3 credentials are missing or invalid."
			messageBox "AWS S3 credentials are missing or invalid. Check the main script settings." title: "S3 Upload Test"
			return false
		)

		return true
	)

	on btnPick pressed do (
		local f = getOpenFileName caption: "Select file to upload to S3" types: "All files (*.*)|*.*|"
		if (f != undefined) do (
			edtFile.text = f
			saveFile f
			setResult ("Selected file: " + f)
		)
	)

	on btnUpload pressed do (
		local uploader = getUploader()
		if (not validateUploader uploader) do return false

		local f = edtFile.text
		if (f == undefined or f == "" or not doesFileExist f) do (
			setResult "Select an existing file first."
			messageBox "Select an existing file first." title: "S3 Upload Test"
			return false
		)

		saveFile f
		setResult ("Uploading: " + (filenameFromPath f))
		local result = uploader.upload f
		local exitCode = if (result != undefined and result.count >= 3) then (result[3] as string) else "unknown"

		if (result != undefined and result.count >= 2 and result[1] == "true") then (
			setResult ("SUCCESS\nFile: " + f + "\nExit code: " + exitCode + "\nMessage:\n" + result[2])
			messageBox result[2] title: "S3 Upload Test"
		) else (
			local msg = if (result != undefined and result.count >= 2) then result[2] else "Upload failed."
			if (exitCode == "10" and not strContains msg "Curl output") do (
				msg += "\n\nNo Curl output was returned by awsUploaderMgr. Re-run GC-Autoconverter-GLB.ms to reload the updated uploader wrapper, then run this test again."
			)
			setResult ("FAILED\nFile: " + f + "\nExit code: " + exitCode + "\nMessage:\n" + msg)
			messageBox msg title: "S3 Upload Test"
		)
	)

	on btnClearLog pressed do (
		edtLog.text = ""
		lblResult.caption = "Ready"
	)

	on _rGCTestS3Uploader open do (
		local f = getSavedFile()
		if (f != "") do (
			edtFile.text = f
			setResult ("Restored last file: " + f)
		)
	)
)

createDialog _rGCTestS3Uploader
