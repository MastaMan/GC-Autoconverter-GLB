/*
	UVAtlas unwrap manual test

	Usage:
	1. Run the main GC-Autoconverter-GLB.ms script first.
	2. Select one geometry object in the current 3ds Max scene.
	3. Run this file and click Run UVAtlas.

	Notes:
	- This test uses UVAtlasToolWrapper from the main script.
	- It writes UVs to the selected target map channel.
	- It does not use queue, Web API, S3, Telegram, or requestMgr.
*/

try (destroyDialog _rGCTestUVAtlas) catch()

rollout _rGCTestUVAtlas "UVAtlas Test" width: 620 (
	local lastResolutionKey = "testUVAtlasResolution"
	local lastChannelKey = "testUVAtlasTargetChannel"

	group "Target" (
		label lblSelection "Selected object: -" width: 580 align: #left
		spinner spnResolution "Resolution:" range: [128, 8192, 1024] scale: 128 type: #integer fieldwidth: 80 align: #left across: 2
		spinner spnTargetChannel "Target channel:" range: [1, 99, 2] type: #integer fieldwidth: 80 align: #left
	)

	group "Result" (
		label lblResult "Ready" width: 580 align: #left
	)

	button btnRun "Run UVAtlas" width: 140 align: #center

	group "Log" (
		dotNetControl edtLog "System.Windows.Forms.TextBox" width: 580 height: 320
		button btnClearLog "Clear log" width: 90 align: #right
	)

	fn getTimeLabel = (
		local dt = (dotNetClass "System.DateTime").Now
		return dt.ToString "yyyy-MM-dd HH:mm:ss"
	)

	fn appendLog msg = (
		if (msg == undefined) do msg = ""
		msg = msg as string
		msg = substituteString msg "\r\n" "\n"
		msg = substituteString msg "\r" "\n"
		msg = substituteString msg "\n" "\r\n"

		local line = "[" + getTimeLabel() + "] " + msg
		if (edtLog.Text == "") then (
			edtLog.Text = line
		) else (
			edtLog.AppendText ("\r\n\r\n" + line)
		)
		edtLog.SelectionStart = edtLog.TextLength
		edtLog.ScrollToCaret()
		format "%\n" line
		return true
	)

	fn makeResultCaption msg = (
		if (msg == undefined or msg == "") do return "Ready"
		local resultText = msg as string
		local lineEnd = findString resultText "\n"
		if (lineEnd != undefined) do resultText = substring resultText 1 (lineEnd - 1)
		if (resultText.count > 90) do resultText = (substring resultText 1 87) + "..."
		return resultText
	)

	fn setResult msg log: true = (
		lblResult.caption = makeResultCaption msg
		if (log) do appendLog msg
		return true
	)

	fn getWrapper = (
		local wrapper = undefined
		try (wrapper = UVAtlasToolWrapper()) catch()
		return wrapper
	)

	fn getSelectedObject = (
		if (selection.count != 1) do return undefined
		local obj = selection[1]
		if (obj == undefined or not isValidNode obj) do return undefined
		if (superClassOf obj != GeometryClass) do return undefined
		return obj
	)

	fn getMaterialLabel obj = (
		if (obj == undefined or obj.material == undefined) do return "-"
		return obj.material.name
	)

	fn getUserPropsLabel obj = (
		local userProps = ""
		try (userProps = getUserPropBuffer obj) catch()
		if (userProps == undefined or userProps == "") do return "-"
		return userProps
	)

	fn getMapStats obj channel = (
		if (obj == undefined or not isValidNode obj) do return "invalid object"
		local mapVerts = 0
		local mapFaces = 0
		try (
			mapVerts = meshop.getNumMapVerts obj channel
			mapFaces = meshop.getNumMapFaces obj channel
		) catch()
		return ("channel " + (channel as string) + ": map verts=" + (mapVerts as string) + ", map faces=" + (mapFaces as string))
	)

	fn refreshSelectionLabel = (
		local obj = getSelectedObject()
		if (obj == undefined) then (
			lblSelection.caption = "Selected object: -"
			return false
		) else (
			lblSelection.caption = "Selected object: " + obj.name
			return true
		)
	)

	fn loadSettings = (
		local savedResolution = 0
		local savedChannel = 0
		try (savedResolution = '*'.get lastResolutionKey type: #int) catch()
		try (savedChannel = '*'.get lastChannelKey type: #int) catch()
		if (savedResolution >= 128) do spnResolution.value = savedResolution
		if (savedChannel >= 1) do spnTargetChannel.value = savedChannel
		return true
	)

	fn saveSettings = (
		try ('*'.add lastResolutionKey spnResolution.value) catch()
		try ('*'.add lastChannelKey spnTargetChannel.value) catch()
		return true
	)

	fn validateWrapper wrapper = (
		if (wrapper == undefined) do (
			setResult "UVAtlasToolWrapper not found. Run the main script first."
			messageBox "UVAtlasToolWrapper not found. Run GC-Autoconverter-GLB.ms first." title: "UVAtlas Test"
			return false
		)

		if (not wrapper.isAvailable()) do (
			setResult ("uvatlastool.exe not found: " + wrapper.exe)
			messageBox ("uvatlastool.exe not found:\n" + wrapper.exe) title: "UVAtlas Test"
			return false
		)

		return true
	)

	on btnRun pressed do (
		local wrapper = getWrapper()
		if (not validateWrapper wrapper) do return false

		local obj = getSelectedObject()
		if (obj == undefined) do (
			setResult "Select exactly one geometry object first."
			messageBox "Select exactly one geometry object first." title: "UVAtlas Test"
			return false
		)

		saveSettings()
		refreshSelectionLabel()

		local targetChannel = spnTargetChannel.value
		local materialBefore = getMaterialLabel obj
		local userPropsBefore = getUserPropsLabel obj
		local objectNameBefore = obj.name
		local statsBefore = getMapStats obj targetChannel

		appendLog ("Running UVAtlas\nObject: " + obj.name + "\nResolution: " + (spnResolution.value as string) + "\nTarget channel: " + (targetChannel as string) + "\nBefore: " + statsBefore + "\nMaterial before: " + materialBefore)

		local startedAt = timeStamp()
		local isUnwrapped = wrapper.unwrap obj resolution: spnResolution.value targetChannel: targetChannel
		local elapsedMs = timeStamp() - startedAt
		local wrapperError = ""
		try (wrapperError = wrapper.getLastError()) catch()
		if (wrapperError == undefined) do wrapperError = ""

		local materialAfter = getMaterialLabel obj
		local userPropsAfter = getUserPropsLabel obj
		local objectNameAfter = obj.name
		local statsAfter = getMapStats obj targetChannel
		local preservationReport = "Object name preserved: " + ((objectNameBefore == objectNameAfter) as string) + "\nMaterial preserved: " + ((materialBefore == materialAfter) as string) + "\nUser props preserved: " + ((userPropsBefore == userPropsAfter) as string)

		if (isUnwrapped == true) then (
			setResult ("SUCCESS\nObject: " + obj.name + "\nElapsed: " + (elapsedMs as string) + " ms\nAfter: " + statsAfter + "\n" + preservationReport)
			messageBox ("UVAtlas unwrap finished.\n\n" + statsAfter) title: "UVAtlas Test"
		) else (
			setResult ("FAILED\nObject: " + obj.name + "\nElapsed: " + (elapsedMs as string) + " ms\nError: " + wrapperError + "\nBefore: " + statsBefore + "\nAfter: " + statsAfter + "\n" + preservationReport)
			messageBox "UVAtlas unwrap failed. See the log for details." title: "UVAtlas Test"
		)

		refreshSelectionLabel()
		return true
	)

	on btnClearLog pressed do (
		edtLog.Text = ""
		lblResult.caption = "Ready"
		return true
	)

	on spnResolution changed value do (
		saveSettings()
		return true
	)

	on spnTargetChannel changed value do (
		saveSettings()
		return true
	)

	on _rGCTestUVAtlas open do (
		edtLog.Multiline = true
		edtLog.ScrollBars = (dotNetClass "System.Windows.Forms.ScrollBars").Vertical
		edtLog.WordWrap = false
		edtLog.ReadOnly = true
		loadSettings()
		refreshSelectionLabel()
		appendLog "Ready. Select one geometry object and click Run UVAtlas."
		return true
	)
)

createDialog _rGCTestUVAtlas
