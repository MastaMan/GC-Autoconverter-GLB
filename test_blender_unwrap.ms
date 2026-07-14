/*
	Blender unwrap manual test

	Usage:
	1. Run the main GC-Autoconverter-GLB.ms script first.
	2. Select one geometry object in the current 3ds Max scene.
	3. Run this file and click Run Blender Unwrap.

	Notes:
	- This test uses BlenderUnwrapWrapper from the main script.
	- It writes UVs to the selected target map channel.
	- It does not use queue, Web API, S3, Telegram, or requestMgr.
*/

try (destroyDialog _rGCTestBlenderUnwrap) catch()

rollout _rGCTestBlenderUnwrap "Blender Unwrap Test" width: 620 (
	local lastResolutionKey = "testBlenderUnwrapResolution"
	local lastChannelKey = "testBlenderUnwrapTargetChannel"
	local lastMethodKey = "testBlenderUnwrapMethod"
	local lastAngleKey = "testBlenderUnwrapAngleLimit"
	local lastMarginKey = "testBlenderUnwrapIslandMargin"
	local lastPackKey = "testBlenderUnwrapPackIslands"

	group "Target" (
		label lblSelection "Selected object: -" width: 580 align: #left
		spinner spnResolution "Resolution:" range: [128, 8192, 1024] scale: 128 type: #integer fieldwidth: 80 align: #left across: 2
		spinner spnTargetChannel "Target channel:" range: [1, 99, 2] type: #integer fieldwidth: 80 align: #left
		dropdownlist ddlMethod "Method:" items: #("smart_project", "lightmap_pack") width: 180
		spinner spnAngleLimit "Angle limit:" range: [1.0, 89.0, 66.6] scale: 0.1 type: #float fieldwidth: 80 align: #left across: 2
		spinner spnIslandMargin "Island margin:" range: [0.0, 1.0, 0.02] scale: 0.01 type: #float fieldwidth: 80 align: #left
		checkbox cbxPackIslands "Pack islands after unwrap" checked: true align: #left
	)

	group "Result" (
		label lblResult "Ready" width: 580 align: #left
	)

	button btnRun "Run Blender Unwrap" width: 160 align: #center

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
		try (wrapper = BlenderUnwrapWrapper()) catch()
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
		local savedMethod = ""
		local savedAngle = 0.0
		local savedMargin = -1.0
		local savedPack = ""
		try (savedResolution = '*'.get lastResolutionKey type: #int) catch()
		try (savedChannel = '*'.get lastChannelKey type: #int) catch()
		try (savedMethod = '*'.get lastMethodKey) catch()
		try (savedAngle = '*'.get lastAngleKey type: #float) catch()
		try (savedMargin = '*'.get lastMarginKey type: #float) catch()
		try (savedPack = '*'.get lastPackKey) catch()
		if (savedResolution >= 128) do spnResolution.value = savedResolution
		if (savedChannel >= 1) do spnTargetChannel.value = savedChannel
		ddlMethod.selection = if (savedMethod == "lightmap_pack") then 2 else 1
		if (savedAngle > 0.0) do spnAngleLimit.value = savedAngle
		if (savedMargin >= 0.0) do spnIslandMargin.value = savedMargin
		cbxPackIslands.checked = savedPack != "false"
		return true
	)

	fn saveSettings = (
		try ('*'.add lastResolutionKey spnResolution.value) catch()
		try ('*'.add lastChannelKey spnTargetChannel.value) catch()
		try ('*'.add lastMethodKey ddlMethod.selected) catch()
		try ('*'.add lastAngleKey spnAngleLimit.value) catch()
		try ('*'.add lastMarginKey spnIslandMargin.value) catch()
		try ('*'.add lastPackKey (cbxPackIslands.checked as string)) catch()
		return true
	)

	fn validateWrapper wrapper = (
		if (wrapper == undefined) do (
			setResult "BlenderUnwrapWrapper not found. Run the main script first."
			messageBox "BlenderUnwrapWrapper not found. Run GC-Autoconverter-GLB.ms first." title: "Blender Unwrap Test"
			return false
		)

		if (not wrapper.isAvailable()) do (
			local blenderExe = wrapper.getBlenderExe()
			local errorMessage = "Blender unwrap is not available.\n\nBlender: " + (blenderExe as string) + "\nScript: " + wrapper.pythonScriptUnwrap
			setResult errorMessage
			messageBox errorMessage title: "Blender Unwrap Test"
			return false
		)

		return true
	)

	fn copyMapChannel obj sourceChannel targetChannel = (
		if (obj == undefined or not isValidNode obj) do return false

		local targetMesh = undefined
		try (
			convertToMesh obj
			targetMesh = obj.mesh
			local mapVertsCount = meshop.getNumMapVerts targetMesh sourceChannel
			local mapFacesCount = meshop.getNumMapFaces targetMesh sourceChannel
			if (mapVertsCount < 1 or mapFacesCount < 1) do return false

			local requiredMapCount = targetChannel + 1
			local currentMapCount = meshop.getNumMaps targetMesh
			if (currentMapCount < requiredMapCount) do meshop.setNumMaps targetMesh requiredMapCount keep: true
			meshop.setMapSupport targetMesh targetChannel true
			meshop.setNumMapVerts targetMesh targetChannel mapVertsCount
			meshop.setNumMapFaces targetMesh targetChannel mapFacesCount

			for mapVertIndex in 1 to mapVertsCount do (
				local mapVert = meshop.getMapVert targetMesh sourceChannel mapVertIndex
				meshop.setMapVert targetMesh targetChannel mapVertIndex mapVert
			)

			for mapFaceIndex in 1 to mapFacesCount do (
				local mapFace = meshop.getMapFace targetMesh sourceChannel mapFaceIndex
				meshop.setMapFace targetMesh targetChannel mapFaceIndex mapFace
			)

			obj.mesh = targetMesh
			update obj
			return true
		) catch (
			return false
		)
	)

	fn openUnwrapEditor obj targetChannel = (
		if (obj == undefined or not isValidNode obj) do return false

		local previewObj = undefined
		local unwrapModifier = undefined
		try (
			previewObj = snapshot obj
			previewObj.name = "__blender_unwrap_channel_" + (targetChannel as string) + "_preview_" + (timeStamp() as string)
			convertToMesh previewObj
			local isCopied = copyMapChannel previewObj targetChannel 1
			if (isCopied != true) do (
				try (delete previewObj) catch()
				return false
			)

			select previewObj
			max modify mode
			unwrapModifier = Unwrap_UVW()
			addModifier previewObj unwrapModifier
			unwrapModifier.setMapChannel 1
			unwrapModifier.setApplyToWholeObject true
			modPanel.setCurrentObject unwrapModifier
			subobjectLevel = 3
			try (unwrapModifier.edit()) catch()
			try (unwrapModifier.unwrap2.open()) catch()
			try (unwrapModifier.unwrap2.edit()) catch()
			try (unwrapModifier.unwrap5.open()) catch()
			try (unwrapModifier.unwrap5.edit()) catch()
			return true
		) catch (
			try (if (previewObj != undefined and isValidNode previewObj) do delete previewObj) catch()
			return false
		)
	)

	on btnRun pressed do (
		local wrapper = getWrapper()
		if (not validateWrapper wrapper) do return false

		local obj = getSelectedObject()
		if (obj == undefined) do (
			setResult "Select exactly one geometry object first."
			messageBox "Select exactly one geometry object first." title: "Blender Unwrap Test"
			return false
		)

		saveSettings()
		refreshSelectionLabel()

		local targetChannel = spnTargetChannel.value
		local materialBefore = getMaterialLabel obj
		local userPropsBefore = getUserPropsLabel obj
		local objectNameBefore = obj.name
		local statsBefore = getMapStats obj targetChannel
		local unwrapMethod = ddlMethod.selected

		appendLog ("Running Blender unwrap\nObject: " + obj.name + "\nResolution: " + (spnResolution.value as string) + "\nTarget channel: " + (targetChannel as string) + "\nMethod: " + unwrapMethod + "\nAngle limit: " + (spnAngleLimit.value as string) + "\nIsland margin: " + (spnIslandMargin.value as string) + "\nPack islands: " + (cbxPackIslands.checked as string) + "\nBefore: " + statsBefore + "\nMaterial before: " + materialBefore)

		local startedAt = timeStamp()
		local isUnwrapped = wrapper.unwrap obj resolution: spnResolution.value targetChannel: targetChannel unwrapMethod: unwrapMethod angleLimit: spnAngleLimit.value islandMargin: spnIslandMargin.value packIslands: cbxPackIslands.checked
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
			local isEditorOpened = openUnwrapEditor obj targetChannel
			setResult ("SUCCESS\nObject: " + obj.name + "\nElapsed: " + (elapsedMs as string) + " ms\nAfter: " + statsAfter + "\n" + preservationReport)
			if (isEditorOpened == true) then (
				messageBox ("Blender unwrap finished.\n\n" + statsAfter + "\n\nA preview clone was created. UV channel " + (targetChannel as string) + " was copied to channel 1 on the clone, then opened in Unwrap UVW.") title: "Blender Unwrap Test"
			) else (
				messageBox ("Blender unwrap finished.\n\n" + statsAfter + "\n\nCould not open Unwrap UVW editor automatically.") title: "Blender Unwrap Test"
			)
		) else (
			setResult ("FAILED\nObject: " + obj.name + "\nElapsed: " + (elapsedMs as string) + " ms\nError: " + wrapperError + "\nBefore: " + statsBefore + "\nAfter: " + statsAfter + "\n" + preservationReport)
			messageBox "Blender unwrap failed. See the log for details." title: "Blender Unwrap Test"
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

	on ddlMethod selected itemIndex do (
		saveSettings()
		return true
	)

	on spnAngleLimit changed value do (
		saveSettings()
		return true
	)

	on spnIslandMargin changed value do (
		saveSettings()
		return true
	)

	on cbxPackIslands changed value do (
		saveSettings()
		return true
	)

	on _rGCTestBlenderUnwrap open do (
		edtLog.Multiline = true
		edtLog.ScrollBars = (dotNetClass "System.Windows.Forms.ScrollBars").Vertical
		edtLog.WordWrap = true
		edtLog.ReadOnly = true
		loadSettings()
		refreshSelectionLabel()
		appendLog "Ready. Select one geometry object and click Run Blender Unwrap."
		return true
	)
)

createDialog _rGCTestBlenderUnwrap
