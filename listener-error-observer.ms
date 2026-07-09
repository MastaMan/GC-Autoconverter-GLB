try (DestroyDialog listenerObserver) catch ()

rollout listenerObserver "Listener Observer" (
	label lblStatus "Real-time error monitoring" align: #center offset: [0, 12]
	timer tmrObserver "" active: true interval: 1000

	local checkInterval = 10
	local countdownBeforeCheck = 10

	fn updateStatus = (
		lblStatus.caption = "Next listener check in " + (countdownBeforeCheck as string) + " sec..."
	)
	
	fn findErros = (
		local l = listener as string
		if (l.count < 20) do return false
		
		local searchFor = #(
			"Error occurred",
			"C++ callstack",
			"Syntax error: at",
			"MAXScript callstack",
			"EXCEPTION_ACCESS_VIOLATION The thread tried to read"
		)
		
		for i in searchFor do (
			if (findString l i != undefined) do return true
		)
		
		return false
	)
	
	fn restart3DsMax = (
		local f = (getDir #maxroot) + "3dsmax.exe"
		local currentPath = getFilenamePath (getThisScriptFilename())
		local dontRun = if (::MAX_AUTOSTART == true) then "dontrun" else "run"
		
		local args = f + ";" + dontRun
		args = substituteString args "/" @"\"
		
		local cmd = "restart.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		HiddenDOSCommand cmd exitCode: &exitcode donotwait: true
		
		sysInfo.currentDir = curDir  
	)
		
	on listenerObserver open do (
		SetDialogPos listenerObserver [320, 25]
		clearListener()
		countdownBeforeCheck = checkInterval
		updateStatus()
	)	

	on tmrObserver tick do (
		countdownBeforeCheck -= 1
		updateStatus()
		
		if (countdownBeforeCheck > 0) do return false
		
		lblStatus.caption = "Checking listener..."
		local isError = findErros()
		
		if (isError) do restart3DsMax()
		
		countdownBeforeCheck = checkInterval
		updateStatus()
	)
)

CreateDialog listenerObserver 180 50
