/*  
[INFO] 
NAME=GC Autoconverter GLB
VERSION=1.0.0
AUTHOR=Vasyl Lukianenko 
DEV=https://3dground.net
HELP=
CLIENT=Great Catalog
[ABOUT]
Auto Converter to GLB/SKP/BLEND script=


[1.0.0]
*Initial release =

[FILES]
Install.mcr=
jpegoptim.exe=
convert.exe=
gltfpack.exe=
denoise.bat=
gltfpack.bat=
vdenoise.xml=
normalmap.exe=
xnormal.bat=
xnormal.xml=
lowes-viewer.zip=deleted
model-viewer.zip=
chrome-screenshot.bat=
chrome-preview.bat=
chrome.bat=deleted
archivate.bat=
blender-screenshot.bat=
blender-zoom-extends.py=
blender-import-glb.py=
blender-bg-import.bat=
blender-gen-ini.py=
blender-bg-run.bat=
download.bat=
get-max-render.bat=
sync-to-aws.bat=
blender-render.bat
blender-render.py=
clamp-colors.bat=
contrast.bat=
web-request.bat=
sketchup-convert.bat=
template.skp=


[SCRIPT]
*/

heapSize += (1000000 * 40) -- 40Mb

struct JsonWrapper (
	/*
		Example:
		
		data = #(
			#("polygons", "10000"),
			#("vertex", "10000"),
			#("name", "Test"),
			#("render", "Corona"),
			#("renderVer", "12"),
			#("arrayValues", #(
				"val1",
				"val2"
			)),
			#("arrayOfJsons", #(
				#(
					#("var1", "value"),
					#("var2", "value2")
				),
				#(
					#("var3", "value3"),
					#("var4", "valuet")
				)
			)),
			#("xform", "yes")
		)
	*/
	
	fn getScriptVersion = (
		local s = getThisScriptFilename()
		return getINISetting s "INFO" "VERSION"
	),
	
	fn getScriptName = (
		local s = getThisScriptFilename()
		return getINISetting s "INFO" "NAME"
	),
	
	fn addData data k v = (
		k = k as string
		v = case classOf v of (
			undefined: ""
			UndefinedClass: ""
			Array: v
			default: v as string
		)
		
		for i in 1 to data.count where data[i][1] == k do (
			data[i][2] = v
			return false
		)
		
		append data #(k, v)
	),
	
	fn writeFileUTF8 o b = (
		local s = dotNetObject "System.IO.StreamWriter" (o) true ((dotNetClass "System.Text.Encoding").GetEncoding("UTF-8"))
		
		for l in b where l.count > 0 do s.WriteLine(dotNetObject "System.String" l)			
		s.Close()		
	),
	
	fn buildJson data = (
		local t = "\t"
		local n = "\n"
		local q = "\""
		
		local j = "{" + n
		for i in 1 to data.count do (
			local p = data[i]
			local comma = if (i != data.count) then ("," + n) else n
			j += t + q + p[1] + q + ": "
			
			local qq = q
			if (p[2] == "true" or p[2] == "false") do qq = ""
			
			case classOf p[2] of (
				String:  j += qq + p[2] + qq + comma
				Array: (					
					j += "[" + n
					for ii in 1 to p[2].count do (
						local z = p[2][ii]
						local comma2 = if (ii != p[2].count) then ("," + n) else n
						
						if (classOf z == Array) then (							
							j += t + t + "{" + n							
								for iii in 1 to z.count do (
									local pp = z[iii]
									local comma3 = if (iii != z.count) then ("," + n) else n
									
									j += t + t + t + q + pp[1] + q + ": \"" + pp[2] + q + comma3
								)
							j += t + t + "}" + comma2
						) else (
							j += t + t + q + z + q + comma2
						)
					)
					j += t + "]" + comma
				)
			)			
		)
		
		j += "}"
		
		return j
	),
	
	fn writeJson fname data = (	
		deleteFile fname
		
		-- Force add some data in the end
		addData data "date" ((dateTime()).getCurrent())
		addData data "scriptVersion" (getScriptVersion())
		addData data "scriptName" (getScriptName())
		
		local j = buildJson data
		
		local b = FilterString j "\n"
		
		
		writeFileUTF8 (fname) b		
	)
)

struct JsonReaderWrapper (
	data = dotNetObject "System.Collections.Hashtable",
	nullValue = "__JSON_READER_NULL_VALUE__",

	fn isWhiteSpaceChar ch = (
		local result = false

		if ((ch == " ") or (ch == "\t") or (ch == "\r") or (ch == "\n")) do (
			result = true
		)

		return result
	),

	fn trimString s = (
		local result = ""
		local startIndex = 1
		local endIndex = 0
		local ch = ""

		if (s == undefined) do (
			return result
		)

		result = s as string
		endIndex = result.count

		while ((startIndex <= endIndex) and (isWhiteSpaceChar (substring result startIndex 1))) do (
			startIndex += 1
		)

		while ((endIndex >= startIndex) and (isWhiteSpaceChar (substring result endIndex 1))) do (
			endIndex -= 1
		)

		if (endIndex >= startIndex) then (
			result = substring result startIndex (endIndex - startIndex + 1)
		)
		else (
			result = ""
		)

		return result
	),

	fn removeOuterQuotes s = (
		local result = trimString s
		local firstChar = ""
		local lastChar = ""

		if (result.count >= 2) do (
			firstChar = substring result 1 1
			lastChar = substring result result.count 1

			if ((firstChar == "\"") and (lastChar == "\"")) do (
				result = substring result 2 (result.count - 2)
			)
		)

		return result
	),

	fn unescapeJsonString s = (
		local result = s

		result = substituteString result "\\\"" "\""
		result = substituteString result "\\\\" "\\"
		result = substituteString result "\\/" "/"
		result = substituteString result "\\n" "\n"
		result = substituteString result "\\r" "\r"
		result = substituteString result "\\t" "\t"

		return result
	),

	fn splitTopLevel json = (
		local result = #()
		local buffer = ""
		local inString = false
		local escaped = false
		local ch = ""

		for i = 1 to json.count do (
			ch = substring json i 1

			if (escaped) then (
				buffer += ch
				escaped = false
			)
			else if ((ch == "\\") and inString) then (
				buffer += ch
				escaped = true
			)
			else if (ch == "\"") then (
				buffer += ch
				inString = not inString
			)
			else if ((ch == ",") and (not inString)) then (
				append result buffer
				buffer = ""
			)
			else (
				buffer += ch
			)
		)

		if (buffer != "") do (
			append result buffer
		)

		return result
	),

	fn splitKeyValue pairText = (
		local inString = false
		local escaped = false
		local ch = ""
		local keyText = ""
		local valueText = ""

		for i = 1 to pairText.count do (
			ch = substring pairText i 1

			if (escaped) then (
				escaped = false
			)
			else if ((ch == "\\") and inString) then (
				escaped = true
			)
			else if (ch == "\"") then (
				inString = not inString
			)
			else if ((ch == ":") and (not inString)) then (
				keyText = substring pairText 1 (i - 1)
				valueText = substring pairText (i + 1) (pairText.count - i)

				return #(keyText, valueText)
			)
		)

		return undefined
	),

	fn parseValue valueText = (
		local result = undefined
		local asInt = undefined
		local asFloat = undefined
		local firstChar = ""

		valueText = trimString valueText

		if (valueText == "null") then (
			result = nullValue
		)
		else if (valueText == "true") then (
			result = true
		)
		else if (valueText == "false") then (
			result = false
		)
		else (
			if (valueText.count >= 1) do (
				firstChar = substring valueText 1 1
			)

			if ((valueText.count >= 2) and (firstChar == "\"")) then (
				result = unescapeJsonString (removeOuterQuotes valueText)
			)
			else (
				try (
					asInt = valueText as integer
				)
				catch (
					asInt = undefined
				)

				try (
					asFloat = valueText as float
				)
				catch (
					asFloat = undefined
				)

				if ((asInt != undefined) and ((asInt as string) == valueText)) then (
					result = asInt
				)
				else if (asFloat != undefined) then (
					result = asFloat
				)
				else (
					result = valueText
				)
			)
		)

		return result
	),

	fn read json = (
		local pairs = #()
		local kv = undefined
		local key = ""
		local value = undefined
		local firstChar = ""

		data.Clear()

		json = trimString json

		if (json.count >= 1) do (
			firstChar = substring json 1 1

			if (firstChar == "{") do (
				json = substring json 2 (json.count - 1)
			)
		)

		if (json.count >= 1) do (
			if (substring json json.count 1 == "}") do (
				json = substring json 1 (json.count - 1)
			)
		)

		pairs = splitTopLevel json

		for pairText in pairs do (
			kv = splitKeyValue pairText

			if (kv != undefined) do (
				key = removeOuterQuotes kv[1]
				value = parseValue kv[2]

				if (data.ContainsKey key) then (
					data.Item[key] = value
				)
				else (
					data.Add key value
				)
			)
		)

		return true
	),

	fn has key = (
		local result = false

		result = data.ContainsKey key

		return result
	),

	fn get key defaultValue:undefined = (
		local result = defaultValue
		local value = undefined

		if (data.ContainsKey key) do (
			value = data.Item[key]

			if (value == nullValue) then (
				result = undefined
			)
			else (
				result = value
			)
		)

		return result
	),

	fn getString key defaultValue:"" = (
		local result = defaultValue
		local value = undefined

		value = get key defaultValue:undefined

		if (value != undefined) do (
			result = value as string
		)

		return result
	),

	fn getInt key defaultValue:0 = (
		local result = defaultValue
		local value = undefined

		value = get key defaultValue:undefined

		if (value != undefined) do (
			try (
				result = value as integer
			)
			catch (
				result = defaultValue
			)
		)

		return result
	),

	fn getFloat key defaultValue:0.0 = (
		local result = defaultValue
		local value = undefined

		value = get key defaultValue:undefined

		if (value != undefined) do (
			try (
				result = value as float
			)
			catch (
				result = defaultValue
			)
		)

		return result
	),

	fn getBool key defaultValue:false = (
		local result = defaultValue
		local value = undefined

		value = get key defaultValue:undefined

		if (value != undefined) do (
			if (classOf value == BooleanClass) then (
				result = value
			)
			else (
				result = defaultValue
			)
		)

		return result
	),

	fn isNull key = (
		local result = true
		local value = undefined

		if (data.ContainsKey key) do (
			value = data.Item[key]
			result = value == nullValue
		)

		return result
	),

	fn keys = (
		local result = #()

		for key in data.Keys do (
			append result key
		)

		return result
	)
)

struct requestWrapper (
	j = JsonWrapper(),
	jr = JsonReaderWrapper(),
	apiUrl = "https://new.greatcatalog.net/autoconvert/api/v1/",
	apiGetQueue = apiUrl  + "queue.php",
	apiSetStatus = apiUrl  + "status.php",
	apiKey = "1MMPIyo8sRUACDV9ywqsV1n9gNk4gemGCrmW-L2zZgA",
	fn downloadString lnk headers: #(#("x-api-key", apiKey)) = (
		local w = dotNetObject "System.Net.WebClient"
		try(
			local spm = dotNetClass "System.Net.ServicePointManager"
			spm.SecurityProtocol = spm.SecurityProtocol.TLS12				
			local h = dotnetclass "System.Net.HttpRequestHeader"				
			for i in headers do w.Headers.add i[1] i[2]
			local ss = w.downloadString (lnk + "?time=" + timestamp() as string)
			w.Dispose()
			return ss
		) catch(
			return undefined
		)
		
		return undefined
	),
	fn post url data headers: #(#("x-api-key", apiKey)) = (		
		local jj = j.buildJson data
		
		local result = false
		local client = undefined
		try (
			client = dotNetObject "System.Net.WebClient"
			client.Encoding = (dotNetClass "System.Text.Encoding").GetEncoding("UTF-8")
			client.Headers.Add "Content-Type" "application/json"
			client.Headers.Add "Accept" "application/json"
			if (headers != undefined) do (
				for h in headers do (
					client.Headers.Add h[1] (h[2] as string)
				)
			)
			lastResponse = client.UploadString url "POST" jj
			
			jr.read lastResponse
			result = jr.getBool "success"
		)
		catch ex (
			lastError = ex.Message
			result = false
		)
		try (
			if (client != undefined) do (
				client.Dispose()
			)
		)
		catch()
		return result
	),
	fn getQueue = (
		return this.downloadString apiGetQueue
	),
	fn setStatus id status txt: "" = (
		local s = case status of (
			#in_progress: status as string
			#downloaded: status as string
			#uploaded: status as string
			#error: status as string
			#success: status as string
			#in_queue: status as string
			default: #none
		)
		
		if (s == #none) do return false
		
		local data = #(
			#("autoconvertion_id", id),
			#("status_id", s),
			#("txt", txt)
		)
		
		return this.post apiSetStatus data
	)
)

fn clearFolder d = (
	local selfPath = getFileNamePath (getThisScriptFileName())		
	if ((d == undefined) or (d == "")) do (
		return false
	)
	if (doesDirectoryExist d == false) do (
		return false
	)
	local cmd = "del /q \"" + d + "\\*\" & for /d %i in (\"" + d + "\\*\") do rmdir /s /q \"%i\""
	try (
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = selfPath	
		
		hiddenDosCommand cmd
		
		sysInfo.currentDir = curDir
		return true
	) catch ()
	return false
)


fn forceDeleteFile f = (
	try(setFileAttribute f #readOnly false) catch()
	deleteFile f
)

fn forceMoveFile f ff = (
	try(setFileAttribute f #readOnly false) catch()
	try(setFileAttribute ff #readOnly false) catch()
	deleteFile ff
	local r1 = copyFile f ff
	local r2 = deleteFile f
	return (r1 and r2)
)

fn runPruneSceneAutomatically n = (
	/*
		Warning!
		You must have the correct options enabled in advance otherwise it may cause problems with the model!
	*/
	local logMessage = ""
	
	try (
		macros.run "[3DGROUND]" "PruneScene"		
		windows.processPostedMessages()
		
		try (::VPS911BF6532A627B24906719D104021A09.pos = [0, 200]) catch ()
		windows.processPostedMessages()
		
		-- Missing Bitmaps
		::VPSB544600A7B8DB0F0324DE985579971F0.VPSA425EA1DD8BCD6E85F3152FEE0C7619C.checked = false
		-- Anim Keys
		::VPSB544600A7B8DB0F0324DE985579971F0.VPSD2B9375430896BF95E747D4F90E52D25.checked = false
		-- Missing Plugins
		::VPSB544600A7B8DB0F0324DE985579971F0.VPS25D6583C837D5824C228083D0B2C4781.checked = true
		
		-- Run
		::VPSB544600A7B8DB0F0324DE985579971F0.VPS3C801F6ECA1743208D30D22CBFC4730E.pressed()
		sleep 1
		-- Close
		try (closeRolloutFloater VPS911BF6532A627B24906719D104021A09) catch ()
		try (closeRolloutFloater VPS911BF6532A627B24906719D104021A09) catch ()
		sleep 1
		windows.processPostedMessages()
		
		logMessage = "201. Cleared successfully with Prune Scene: " + (filenameFromPath  n)
		
		return #("true", logMessage)
	) catch (
		logMessage = "103. Error while running PruneScene. Action skipped..."		
		print logMessage
	)
	
	return #("false", logMessage)
)

struct dateTime (
    n = (dotNetClass "System.DateTime").Now,
    y = n.year as string,
    d = n.day as string,
    m = n.month as string,
    hh = n.hour as string,
    mm = n.minute as string,
    ss = n.second as string,
	fn addZero p = (
		if (p.count == 1) do p = "0" + p
		return p
	),
	fn getDate = (
		return d + "." + m + "." + y
	),
	fn getTime = (
		return hh + ":" + mm + ":" + ss
	),
	fn getCurrent = (		
		return getDate() + " " + getTime()
	),
	fn getAsFileName = (
		return d + m + y + hh + mm + ss
	),
	on create do (
		d = addZero d
		m = addZero m
		hh = addZero hh
		mm = addZero mm
		ss = addZero ss
	)
)

fn replaceBadSymbolsRegex s pattern: "[^A-Za-z\-_@!#$=%&(){}[\]0-9+~`'., ]" replaceTo: "?" = (
	return (dotNetClass "System.Text.RegularExpressions.Regex").Replace s pattern replaceTo
)

fn fileRegex f pattern: "^[A-Za-z\-_@!#$=%&(){}[\]0-9+~`'., ]+$" = (
	return (dotNetClass "System.Text.RegularExpressions.Regex").IsMatch f pattern
)

fn formatString s v: #() tag: "$"= (
	for i in 1 to v.count  do (
		s = substituteString s (tag + i as string) (v[i] as string)
	)
	
	return s
)

fn strContains s f = (
	if (s == undefined) do return false
	if (s == "") do return false
	return findString s f != undefined
)

fn implodeString a tag: ", " = (
	local o = ""
	for i in 1 to a.count do (
		o += a[i] + (if i != a.count then tag else "")
	)
	return o
)

fn printList l tag: ", " = (
	local o = ""	
	for i in 1 to l.count do (
		o += (l[i][1] as string) + ": " + (l[i][2] as string) + (if i != l.count then tag else "")
	)
	return o
)

fn quickLogging msg v: #() error: false = (	
	local dt = dateTime()
	local t = "[" + dt.getDate() + " / " + dt.getTime() + "]: "
	
	msg = formatString msg v: v
	
	print (t + msg)

	local p = ""
	--if (error) do p = "[Error!]: "
	return p + msg
)

struct settingsWrapper (
    pth = getFilenamePath (getThisScriptFilename()),
    settingsFile = pth + @"settings.ini",
    fn s k v ss: "SETTINGS" = (
        setINISetting settingsFile ss k (v as string)
    ),
    fn g k type: #string  ss: "SETTINGS" = (
        local s = getINISetting settingsFile ss k
        case type of (
            #int: return s as integer
            #float: return s as float
            #bool: if s == "true" or s.count < 1 then true else false
            #bool_not: if s == "true" then true else false
            
            default: return s
        )
    ),
    fn a ss: "SETTINGS" type: #string = (
        local s = getINISetting settingsFile ss
        local o = #()
        
        for k in s do (
            local v = g k ss: ss type: type
            append o #(k, v)
        )
        
        return o
    ),
    fn d k ss: "SETTINGS" = (
        delIniSetting settingsFile ss k
    )
)

'@' = settingsWrapper()

fn boost = (
	if (((maxVersion())[1] / 1000) >= 13) do windows.processPostedMessages() 
)

fn getFileMb f = (
	if (not doesFileExist f) do return 0.0
	s = (getFileSize f) / 1048576.0
	return ((s * 100) as integer) / 100.0
)

fn trimString s tag: " " = (
	s = s as string
	return (trimLeft (trimRight s tag) tag)
)


fn isCanOpenMaxFile f = (
	local fv = try ((getMaxFileVersionData f)[1]) catch (undefined)
	local mv = (maxVersion())[1]
	
	if (fv == undefined) do return false
	
	return fv <= mv
)

fn isNotLowerMinVer f min: 2011 = (
	local fv = try ((getMaxFileVersionData f)[1]) catch (undefined)		
	if (fv == undefined) do return false
	
	local v = 2000 + ((fv / 1000) - 2)

	return v >= min
)

fn fixCorona12Crash = (
	-- Remove ToneMapping
	local r = renderers.current
	if (MatchPattern (r as string) pattern: "*Corona*") do (
		try (setProperty r "colorMap.pipeline" undefined) catch ()
	)
)

fn getMissingPluginsWithoutOpening f = (
	local missingDlls = #()
	getMAXFileObjectNames f \
	missingDLLsAction: #(#logmsg, #abort)  \
	missingDLLsList:&missingDlls \	
	quiet: true

	local o = #()
	
	if (missingDlls == undefined) do return #()
	for i in missingDlls do (
		-- Skip Corona 13 error about ToneMapping
		if (findString i "WhiteBalanceImprovedOperatorPlugin" != undefined) do continue
		
		local m = quickLogging "400. Missing Plugin: $1" v: #(i)
		appendIfUnique o m
	)
	
	return o
)

fn getVersionWithoutOpening f = (
	local v = try ((getMaxFileVersionData f)[1]) catch ((maxVersion())[1])
	v = 2000 + ((v / 1000) - 2)
	return v as string
)

fn setRenderByMaterials currentRender = (
	local l = #()
	 
	for o in objects where o.material != undefined do (
		local m = o.material
		
		if(classOf m == Multimaterial) then (
			for z in m.materialList where z != undefined do (
				appendIfUnique l z
			)
		) else (				
			appendIfUnique l m
		)
	)
	
	local a = #(
		#(#Scanline, 0),
		#(#Corona, 0),
		#(#Vray, 0),
		#(#Fstorm, 0),
		#(#Other, 0)
	)
	
	for i in l do (
		local c = (classOf i) as string
		
		if (MatchPattern c pattern: "Corona*") do a[2][2] += 1
		if (MatchPattern c pattern: "Vray*") do a[3][2] += 1
		if (MatchPattern c pattern: "Standardmaterial*") do a[1][2] += 1
		if (MatchPattern c pattern: "PhysicalMaterial*") do a[1][2] += 1
		if (MatchPattern c pattern: "Fstorm*") do a[4][2] += 1
	)
	
	fn sortFn v1 v2 = (
		local d = v1[2] - v2[2]
		
		if (d < 0.0) do return 1
		if (d > 0.0) do return -1
		return 0
	)
	
	qsort a sortFn
	
	local r = a[1][1]
	
	case r of (		
		#Corona: renderers.current = CoronaRenderer()
		#Vray: renderers.current = VRay()
		#Fstorm: renderers.current = FStormRender()
		#Scanline: renderers.current = DefaultScanlineRenderer()
		default: renderers.current = currentRender
	)
	
	l = #()
	r = undefined
	
	return a
)




struct BlenderGLBWrapper (
	currentPath = getFileNamePath (getThisScriptFileName()),
	pythonScriptGenIni = currentPath + "blender-gen-ini.py",	
	pythonScriptconvertGLB2Blend = currentPath + "blender-import-glb.py",	
	pythonScriptZoomExtends = currentPath + "blender-zoom-extends.py",
	pythonScriptRender = currentPath + "blender-render.py",
	
	hdr = currentPath + @"model-viewer\hdri\studio.hdr",
	blenderLocation = @"C:\Program Files\Blender Foundation\",
	file = "",	
	ini = "",
	zip = "",
	preview = "",
	outFile = "",
	tmpOut = "",
	json = "",
	jsonFile = "",
	j = JsonWrapper(),
	
	fn archivate n o = (
		if (not doesDirectoryExist o) do return false
		
		local args = n + ";" + o
		args = substituteString args "/" @"\"
		
		local cmd = "archivate.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir
	),	
	fn getFileMb f = (
		if (not doesFileExist f) do return 0.0
		s = (getFileSize f) / 1048576.0
		return ((s * 100) as integer) / 100.0
	),
	fn getBlenderExe = (
		local d = (getDirectories (blenderLocation + "*"))[1]			
		if (d == undefined) do return undefined
		local b = d + "blender.exe"
		if (not doesFileExist b) do return undefined
		return b
	),
	fn isBlenderExist = (
		local b = getBlenderExe()
		if (b == undefined) do return false
		return true
	),
	fn runBatch script = (
		local f = outFile
		local b = getBlenderExe()
		
		local args = b + ";" + f + ";" + script
		args = substituteString args "/" @"\"
		
		local cmd = "blender-bg-run.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir
	),
	fn runImport script bat: "blender-bg-import.bat" = (
		local f = file
		local o = outFile
		local b = getBlenderExe()
		
		local args = b + ";" + script + ";" + f + ";" + o
		args = substituteString args "/" @"\"
		
		local cmd = bat + " \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir		
	),	
	fn contrastImage f = (
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = this.currentPath
		
		local args = f + ";" + f
		local cmd = "contrast.bat \"" + args + "\""
		
		hiddenDosCommand cmd exitcode:&exitcode			
		sysInfo.currentDir = curDir
	),	
	fn makeRender = (
		local b = getBlenderExe()
		
		local args = b + ";" + this.pythonScriptRender + ";" + this.file + ";" + this.preview + ";" + this.hdr
		
		local cmd = "blender-render.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir
		
		this.contrastImage this.preview
	),
	fn getRealName = (
		if (maxFileName != "") do (
			local n = getFilenameFile maxFileName
			
			n = substituteString n "GC-Repack-" ""
			n = substituteString n "Repack-" ""
			n = substituteString n "repack-" ""
			n = substituteString n "GC-" ""
			n = substituteString n "-Corona" ""
			n = substituteString n "-VRay" ""
			n = substituteString n "-V-Ray" ""
			for i in #{2010..2050} do n = substituteString n (i as string) ""
			n = substituteString n "---" ""
			n = substituteString n "---" ""
			n = substituteString n "--" ""
			n = substituteString n "--" ""
			n = trimLeft (trimRight n "- ") "- "			
			n = "GC-Repack-" + n
			
			return n
		)
		
		return undefined
	),
	fn makeArchive = (
		local n = getRealName()
		local p = getFilenamePath outFile
		local ext = getFilenameType  outFile
		
		if (n != undefined) then (		
			renameFile outFile (p + n + ext)
		) else (
			n = getFilenameFile outFile
		)
		
		archivate zip tmpOut
		j.addData json "name" (n + ext)				
		j.addData json "scene" (maxFileName)
		j.addData json "sizeMb" (getFileMb zip)				
	),	
	fn deleteBlenderIni = (
		deleteFile ini
	),
	fn getBlenderData sec: "INDEX" key: undefined = (		
		if (key != undefined) do (
			return getINISetting ini sec key
		)
		
		return getINISetting ini sec
	),
	fn getDim = (		
		local w = getBlenderData sec: "DIMENSION" key: "width"
		local h = getBlenderData sec: "DIMENSION" key: "height"
		local l = getBlenderData sec: "DIMENSION" key: "length"
		
		return w + " x " + l + " x " + h
	),
	fn getUnits = (
		local u = getBlenderData key: "system_units"	
		u = toLower u
		u[1] = toUpper u[1]
		
		case u of (
			"Metric": return "Meters"
			"Imperial": return "Inches"
		)
		
		return u
	),
	fn isPackedImages = (
		return (getBlenderData key: "is_packed_images") == "True"
	),	
	fn getTextures = (
		return getBlenderData sec: "TEXTURES"
	),
	fn getPolys = (
		return getBlenderData key: "polys"
	),
	fn getVerts = (
		return getBlenderData key: "vert"
	),
	fn getRender = (
		local r = getBlenderData key: "render"
		
		if (matchpattern r pattern:"BLENDER_RENDER") do return "Blender Render"
		if (matchpattern r pattern:"CYCLES") do return "Cycles"
		if (matchpattern r pattern:"EEVEE") do return "Eevee"
		if (matchpattern r pattern:"BLENDER_EEVEE*") do return "Eevee"
		if (matchpattern r pattern:"WORKBENCH") do return "Workbench Render"
		if (matchpattern r pattern:"LUXCORE") do return "LuxCoreRender"
		if (matchpattern r pattern:"RPR") do return "Radeon ProRender"
		if (matchpattern r pattern:"RADEON_PRORENDER") do return "Radeon ProRender"
		if (matchpattern r pattern:"*OCTANE*") do return "OctaneRender"
		if (matchpattern r pattern:"APPLESEED") do return "Appleseed Render"
		if (matchpattern r pattern:"*CORONA*") do return "Corona"
		if (matchpattern r pattern:"*VRAY*") do return "VRay"
		if (matchpattern r pattern:"*renderman*") do return "RenderMan"
		if (matchpattern r pattern:"*render_man*") do return "RenderMan"
		
		return r
	),
	fn getVer = (
		return getBlenderData key: "blender_ver"		
	),	
	fn makeScreenshot = (
		local f = outFile
		local b = getBlenderExe()
		local s = pythonScriptZoomExtends
		
		local args = b + ";" + f + ";" + s + ";" + preview
		args = substituteString args "/" @"\"
		
		local cmd = "blender-screenshot.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir
		
		return preview		
	),
	fn init glb: "" name: "" = (
		json = #()
		
		local p = getFilenamePath glb
		local pp = p + name + @"\"		
		makeDir pp all: true
		
		file = glb		
		preview = p + name + ".png"
		zip = p + name + ".zip"
		outFile = pp + name + ".blend"
		ini = outFile + ".ini"
		jsonFile = p + name + ".json"
		tmpOut = pp		
	),
	fn generateBlenderIni = (
		runBatch pythonScriptGenIni
		
		local v = getVer()
		local r = getRender()
		
		j.addData json "program" "blender"
		j.addData json "version" v
		j.addData json "render" r
		j.addData json "size" (getDim())
		j.addData json "polys" (getPolys())
		j.addData json "verts" (getVerts())
		j.addData json "units" (getUnits())
		j.addData json "authorsVersions" #(v)
		j.addData json "versionsAndRenders" #(#(#(v, r)))
		
		deleteBlenderIni()
	),
	fn convertGLB2Blend = (
		runImport pythonScriptconvertGLB2Blend
		generateBlenderIni()
	),
	fn makeJson = (
		j.writeJson jsonFile json
	)
)

struct BlenderGLBWrapper (
	currentPath = getFileNamePath (getThisScriptFileName()),
	pythonScriptGenIni = currentPath + "blender-gen-ini.py",	
	pythonScriptconvertGLB2Blend = currentPath + "blender-import-glb.py",	
	pythonScriptZoomExtends = currentPath + "blender-zoom-extends.py",
	pythonScriptRender = currentPath + "blender-render.py",
	
	hdr = currentPath + @"model-viewer\hdri\studio.hdr",
	blenderLocation = @"C:\Program Files\Blender Foundation\",
	file = "",	
	ini = "",
	zip = "",
	preview = "",
	outFile = "",
	tmpOut = "",
	json = "",
	jsonFile = "",
	j = JsonWrapper(),
	
	fn archivate n o = (
		if (not doesDirectoryExist o) do return false
		
		local args = n + ";" + o
		args = substituteString args "/" @"\"
		
		local cmd = "archivate.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir
	),	
	fn getFileMb f = (
		if (not doesFileExist f) do return 0.0
		s = (getFileSize f) / 1048576.0
		return ((s * 100) as integer) / 100.0
	),
	fn getBlenderExe = (
		local d = (getDirectories (blenderLocation + "*"))[1]			
		if (d == undefined) do return undefined
		local b = d + "blender.exe"
		if (not doesFileExist b) do return undefined
		return b
	),
	fn isBlenderExist = (
		local b = getBlenderExe()
		if (b == undefined) do return false
		return true
	),
	fn runBatch script = (
		local f = outFile
		local b = getBlenderExe()
		
		local args = b + ";" + f + ";" + script
		args = substituteString args "/" @"\"
		
		local cmd = "blender-bg-run.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir
	),
	fn runImport script bat: "blender-bg-import.bat" = (
		local f = file
		local o = outFile
		local b = getBlenderExe()
		
		local args = b + ";" + script + ";" + f + ";" + o
		args = substituteString args "/" @"\"
		
		local cmd = bat + " \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir		
	),	
	fn contrastImage f = (
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = this.currentPath
		
		local args = f + ";" + f
		local cmd = "contrast.bat \"" + args + "\""
		
		hiddenDosCommand cmd exitcode:&exitcode			
		sysInfo.currentDir = curDir
	),	
	fn makeRender = (
		local b = getBlenderExe()
		
		local args = b + ";" + this.pythonScriptRender + ";" + this.file + ";" + this.preview + ";" + this.hdr
		
		local cmd = "blender-render.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir
		
		this.contrastImage this.preview
	),
	fn getRealName = (
		if (maxFileName != "") do (
			local n = getFilenameFile maxFileName
			
			n = substituteString n "GC-Repack-" ""
			n = substituteString n "Repack-" ""
			n = substituteString n "repack-" ""
			n = substituteString n "GC-" ""
			n = substituteString n "-Corona" ""
			n = substituteString n "-VRay" ""
			n = substituteString n "-V-Ray" ""
			for i in #{2010..2050} do n = substituteString n (i as string) ""
			n = substituteString n "---" ""
			n = substituteString n "---" ""
			n = substituteString n "--" ""
			n = substituteString n "--" ""
			n = trimLeft (trimRight n "- ") "- "			
			n = "GC-Repack-" + n
			
			return n
		)
		
		return undefined
	),
	fn makeArchive = (
		local n = getRealName()
		local p = getFilenamePath outFile
		local ext = getFilenameType  outFile
		
		if (n != undefined) then (		
			renameFile outFile (p + n + ext)
		) else (
			n = getFilenameFile outFile
		)
		
		archivate zip tmpOut
		j.addData json "name" (n + ext)				
		j.addData json "scene" (maxFileName)
		j.addData json "sizeMb" (getFileMb zip)				
	),	
	fn deleteBlenderIni = (
		deleteFile ini
	),
	fn getBlenderData sec: "INDEX" key: undefined = (		
		if (key != undefined) do (
			return getINISetting ini sec key
		)
		
		return getINISetting ini sec
	),
	fn getDim = (		
		local w = getBlenderData sec: "DIMENSION" key: "width"
		local h = getBlenderData sec: "DIMENSION" key: "height"
		local l = getBlenderData sec: "DIMENSION" key: "length"
		
		return w + " x " + l + " x " + h
	),
	fn getUnits = (
		local u = getBlenderData key: "system_units"	
		u = toLower u
		u[1] = toUpper u[1]
		
		case u of (
			"Metric": return "Meters"
			"Imperial": return "Inches"
		)
		
		return u
	),
	fn isPackedImages = (
		return (getBlenderData key: "is_packed_images") == "True"
	),	
	fn getTextures = (
		return getBlenderData sec: "TEXTURES"
	),
	fn getPolys = (
		return getBlenderData key: "polys"
	),
	fn getVerts = (
		return getBlenderData key: "vert"
	),
	fn getRender = (
		local r = getBlenderData key: "render"
		
		if (matchpattern r pattern:"BLENDER_RENDER") do return "Blender Render"
		if (matchpattern r pattern:"CYCLES") do return "Cycles"
		if (matchpattern r pattern:"EEVEE") do return "Eevee"
		if (matchpattern r pattern:"BLENDER_EEVEE*") do return "Eevee"
		if (matchpattern r pattern:"WORKBENCH") do return "Workbench Render"
		if (matchpattern r pattern:"LUXCORE") do return "LuxCoreRender"
		if (matchpattern r pattern:"RPR") do return "Radeon ProRender"
		if (matchpattern r pattern:"RADEON_PRORENDER") do return "Radeon ProRender"
		if (matchpattern r pattern:"*OCTANE*") do return "OctaneRender"
		if (matchpattern r pattern:"APPLESEED") do return "Appleseed Render"
		if (matchpattern r pattern:"*CORONA*") do return "Corona"
		if (matchpattern r pattern:"*VRAY*") do return "VRay"
		if (matchpattern r pattern:"*renderman*") do return "RenderMan"
		if (matchpattern r pattern:"*render_man*") do return "RenderMan"
		
		return r
	),
	fn getVer = (
		return getBlenderData key: "blender_ver"		
	),	
	fn makeScreenshot = (
		local f = outFile
		local b = getBlenderExe()
		local s = pythonScriptZoomExtends
		
		local args = b + ";" + f + ";" + s + ";" + preview
		args = substituteString args "/" @"\"
		
		local cmd = "blender-screenshot.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir
		
		return preview		
	),
	fn init glb: "" name: "" = (
		json = #()
		
		local p = getFilenamePath glb
		local pp = p + name + @"\"		
		makeDir pp all: true
		
		file = glb		
		preview = p + name + ".png"
		zip = p + name + ".zip"
		outFile = pp + name + ".blend"
		ini = outFile + ".ini"
		jsonFile = p + name + ".json"
		tmpOut = pp		
	),
	fn generateBlenderIni = (
		runBatch pythonScriptGenIni
		
		local v = getVer()
		local r = getRender()
		
		j.addData json "program" "blender"
		j.addData json "version" v
		j.addData json "render" r
		j.addData json "size" (getDim())
		j.addData json "polys" (getPolys())
		j.addData json "verts" (getVerts())
		j.addData json "units" (getUnits())
		j.addData json "authorsVersions" #(v)
		j.addData json "versionsAndRenders" #(#(#(v, r)))
		
		deleteBlenderIni()
	),
	fn convertGLB2Blend = (
		runImport pythonScriptconvertGLB2Blend
		generateBlenderIni()
	),
	fn makeJson = (
		j.writeJson jsonFile json
	)
)

struct SketchupConverterWrapper (
	currentPath = getFileNamePath (getThisScriptFileName()),
	sketchupLocaton = @"C:\Program Files\SketchUp\",
	
	glb = "",	
	outFile = "",
	tmpOut = "",
	preview = "",
	input = "",
	zip = "",
	json = #(),
	jsonFile = "",
	j = JsonWrapper(),
	
	fn archivate n o = (
		if (not doesDirectoryExist o) do return false
		
		local args = n + ";" + o
		args = substituteString args "/" @"\"
		
		local cmd = "archivate.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir
	),
	fn getMaxFile o = (
		local ptrns = #(
			"GC-*-Corona.max",
			"GC-*-VRay.max",
			"GC-*.max",
			"*Corona*.max",
			"*VRay*.max",
			"*V-Ray*.max",
			"*V_Ray*.max",
			"*crn*.max",
			"*vr*.max",
			"*.max"
		)
		
		local files = getFiles (o + "*.max")
		
		for p in ptrns do (
			for f in files do (
				local ne = filenameFromPath f
				if (MatchPattern ne pattern: p) do return f
			)
		)
		
		return undefined
	),
	fn getSketchupExe = (
		local d = (getDirectories (sketchupLocaton + "*"))[1]			
		if (d == undefined) do return undefined
		local b = d + "SketchUp.exe"
		if (not doesFileExist b) do return undefined
		return b
	),
	fn isSketchupExist = (
		local b = getSketchupExe()
		if (b == undefined) do return false
		return true
	),	
	fn getFileMb f = (
		if (not doesFileExist f) do return 0.0
		s = (getFileSize f) / 1048576.0
		return ((s * 100) as integer) / 100.0
	),
	fn getCurrentMaxVersion = (
		local v = maxVersion()
		v = (v[1] / 1000) - 2
		
		return (2000 + v) as string
	),
	fn polyCount s = (
        local iPoly = 0
		local iVert = 0
        
        local a = for i in s collect (getPolygonCount i)
        for i in a do (
			iPoly += i[1]
			iVert += i[2]
		)
		
        sPoly = iPoly as string
        sVert = iVert as string
		
		return #(sPoly, sVert)
	),	
	fn getDim s = (
        local d = s.max - s.min
        
        d = for i in 1 to 3 collect ((d[i] * 100) as integer / 100.0 ) as string
        
        return d[1] + " x " + d[2] + " x " + d[3]
    ),	
	fn getUnits = (
        local u = trimLeft (units.SystemType as string) "#"
        u[1] = toUpper u[1]
        return u
    ),	
	fn getVer = (
		local s = getSketchupExe()
		local c = filterString s @"\"
		if (c[c.count] != "SketchUp.exe") do return "0"
		local rr = c[c.count - 1]
		local v = (FilterString rr " ")[2]
		if (v == undefined) do return "0"
		
		return v
	),
	fn getRender = (		
		local f = @"c:\Program Files\Chaos\V-Ray\V-Ray for SketchUp\extension\extension.json"
		if (not doesFileExist f) do return "Unknown"
		return "VRay"
	),
	fn runBatch bat: "sketchup-convert.bat" = (
		local o = substituteString this.outFile @"\" "/"
		local g = substituteString this.glb @"\" "/"
		local s = getSketchupExe()
		
		local args = s + ";" + g + ";" + o
		
		local cmd = bat + " \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir		
	),
	fn makeScreensot = (
		local s = substituteString this.glb ".glb" ".png"
		deleteFile this.preview
		copyFile s this.preview
	),
	fn clearCache = (
		local ff = getFiles (this.tmpOut + "*.skb")
		for f in ff do deleteFile f
	),
	fn convertMax2Skp = (
		local polys = polyCount objects
		local v = getVer()
		local r = getRender()
		
		deleteFile this.outFile
		
		this.j.addData json "scene" (maxFileName)		
		this.j.addData this.json "program" "sketchup"
		j.addData json "version" v
		j.addData json "render" "Default"
		this.j.addData this.json "ao" false
		this.j.addData this.json "aoType" "none"
		this.j.addData this.json "polys" polys[1]
		this.j.addData this.json "verts" polys[2]		
		this.j.addData this.json "size" (getDim objects)		
		this.j.addData this.json "units" (getUnits())
		this.j.addData this.json "objectsCount" (objects.count)
		this.j.addData this.json "authorsVersions" #(v)
		this.j.addData this.json "versionsAndRenders" #(#(#(v, "Default")))
		this.j.addData this.json "materialsCount" (sceneMaterials.count)
		
		local template = @"C:\temp\template.skp"
		deleteFile template
		copyFile (currentPath + "template.skp") template
		
		this.runBatch()
		
		this.makeScreensot()
		
		this.clearCache()
	),
	/*fn makeArchive = (			
		archivate this.zip this.tmpOut
		this.j.addData json "name" (filenameFromPath this.zip)						
		this.j.addData json "sizeMb" (getFileMb this.zip)
	),*/
	fn makeJson = (
		this.j.writeJson this.jsonFile this.json
	),
	
	fn init input: "" glb: "" name: "" = (
		this.json = #()
		
		local p = getFilenamePath glb
		local pp = p + name + @"\"		
		
		this.input = input
		this.glb = glb
		
		this.preview = p + name + ".png"
		this.zip = p + name + ".zip"
		this.outFile = p + name + ".skp"
		this.jsonFile = p + name + ".json"
		this.tmpOut = p
	)
)


try(closeRolloutFloater _fGCAutoGLBConverter) catch()
global _fGCAutoGLBConverter = newRolloutFloater "" 300 299


fn getLogginFile = (
	local dt = dateTime()
	local dmy = dt.d + "." + dt.m + "." + dt.y
	local n = "GLB_Converter_" + dmy + ".ini"
	local f = @"C:\temp\" + n	
)

fn logging m = (
	local dt = dateTime()
	local dmy = dt.d + "." + dt.m + "." + dt.y
	local hms = dt.hh + ":" + dt.mm + ":" + dt.ss
	local t = "( " + dmy + " / " + hms + " ) ( " + timestamp() as string + " )|"
	
	local f = getLogginFile()
	
	local m = substituteString m "\n" " "
	local msg = " > " + m
	print msg
	setIniSetting f "LOG" t msg
)

struct DownloadWrapper (
	currentPath = getFileNamePath (getThisScriptFileName()),
	fn download u f = (
		logging "Start downloading file..."
		
		local args = u + ";" + f
		
		local cmd = "download.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir
		
		logging "Downloading file done!"
	),
	fn fileSize f = (
		return try ((getFileSize f) as float) catch (0.0)
	),
	fn isValidFile f = (
		if (not doesFileExist f) do return false
		local size = fileSize f
		if (size == 0.0) do return false
		if (size > 2000) do return true
		local ss = (dotnetClass "System.IO.File").ReadAllLines f
		return findString ss[1] ("xml version=") == undefined
	)
)

rollout _rGCAutoGLBConverter_Main "Main" (
	local requestMgr = requestWrapper()
	local jsonReaderMgr = JsonReaderWrapper()
	local startupScript = (getDir #userStartupScripts) + @"\AUTO_CONVERTER_GLB_STARTUP.ms"
	local maxProcessFilesInSession = 20 --20 files in a row
	local onstartDelay = 1 --sec !!! 20
	local restartProgramInterval = 60
	local restartReadReadQueue = 1 -- min !!!!! 5
	
	local countdownBeforeStart = onstartDelay
	local countdownMaxRestart = 60 -- sec
	local countdownQueueRestart = restartReadReadQueue
	
	group "Working Path" (
		edittext edtInputPath "" readonly: true across: 2 align: #left fieldwidth: 215 height: 22		
		button btnSearchInputPath "..." width: 35 height: 24  align: #right offset: [0, -1]		
	)
	
	checkbox cbxConvertToBlend "Convert to BLEND"
	checkbox cbxConvertToSketchup "Convert to SKP"
	
	progressBar pbProgress "" height: 9 color: (color 52 168 83) value: 0 offset: [0, 5]
	label lblStatus "" align: #left offset: [0, 5]
	checkbutton btnStartStartupProcess "Autostart and Process" width: 260 height: 32 enabled: false highlightColor: (color 52 168 83)
	
	timer tmrOnStartDelay active: false interval: (onstartDelay * 1000)
	timer tmrQueueRestart active: false interval: (restartReadReadQueue * 60 * 1000)
	
	timer tmrCounterBeforeStart active: false interval: 1000
	timer tmrCounteRestart active: false interval: 1000
	timer tmrCounterMaxRestart active: false interval: 1000
	timer tmrCounterQueueRestart active: false interval: 1000
	
	fn writeFile f s = (			
		local f = createFile f mode: "wt"
		
		format(s as string) to:f
		
		flush f
		close f
	)
	
	fn loadSettings = (
		local p1 = '@'.g "tnt_path"
		if (p1 != "" and doesDirectoryExist p1) do edtInputPath.text = p1
		
		btnStartStartupProcess.enabled = edtInputPath.text != ""			
		
		local n = '@'.g "convert_to_blend"
		cbxConvertToBlend.checked = n != "false"
		
		local a = '@'.g "convert_to_sketchup"
		cbxConvertToSketchup.checked = a != "false"
	)
	
	fn updateButtonStatus = (		
		if (doesFileExist startupScript) do (
			btnStartStartupProcess.checked  = true
			return true
		)
		
		btnStartStartupProcess.checked  = false
		return false
	)
	
	on btnSearchInputPath pressed do (
		local d = '@'.g "tnt_path"
		local p = getSavePath initialDir: d
		
		if (p == undefined) do return false
		p += @"\"
		
		edtInputPath.text = p
		'@'.s "tnt_path" p
		
		loadSettings()
	)
	
	fn warnAboutNecessaryOptions = (
		local opts = #(
			cbxConvertToBlend,
			cbxConvertToSketchup
		)
		
		local anyDisabled = false		
		for i in opts where not i.checked do anyDisabled = true
		
		if (not anyDisabled) do return false
		
		local m = "For Production mode, it is strongly recommended to enable the following options:\n\n"
		for i in 1 to opts.count where not opts[i].checked do m += (i as string) + ". " + opts[i].caption + "\n"
		messageBox m title: "Warning!"
		
		return true
	)
	
	fn statusMessageScanningWillStart create: false dispose: false = (
		if (countdownBeforeStart <= 0 or dispose) do (
			tmrCounterBeforeStart.active = false
			return false
		)
		
		countdownBeforeStart -= 1
		if (create) do (
			tmrCounterBeforeStart.active = false
			tmrCounterBeforeStart.active = true
			countdownBeforeStart = onstartDelay
		)
		
		lblStatus.caption = "Processing will start in " + (countdownBeforeStart as string) + " seconds..."	
	)
	
	fn statusMessageRestartMaxIn create: false dispose: false = (
		if (countdownMaxRestart <= 0 or dispose) do (
			tmrCounterMaxRestart.active = false
			return false
		)
		
		countdownMaxRestart -= 1
		if (create) do (
			countdownMaxRestart = restartProgramInterval * 1000
			tmrCounterMaxRestart.active = false
			tmrCounterMaxRestart.active = true
		)
		
		local m = (countdownMaxRestart / 60) as string
		local s = (mod countdownMaxRestart 60) as string
		if (s.count < 2) do s = "0" + s
		
		local timeMin = m + ":" + s
		local f = if (m == "0") then "sec" else "min"
		
		lblStatus.caption = formatString "Restarting 3D Max in $1 $2..." v: #(timeMin, f)
	)
	
	local lastStatusMsg = ""
	fn statusMessageRestartQueueIn create: false dispose: false msg: "" = (
		if (countdownQueueRestart <= 0 or dispose) do (
			tmrCounterQueueRestart.active = false
			return false
		)
		
		if (msg == "") do msg = lastStatusMsg
		
		countdownQueueRestart -= 1
		if (create) do (
			lastStatusMsg = msg
			countdownQueueRestart = restartReadReadQueue * 60
			
			tmrCounterQueueRestart.active = false
			tmrCounterQueueRestart.active = true
		)
		
		local m = (countdownQueueRestart / 60) as string
		local s = (mod countdownQueueRestart 60) as string
		if (s.count < 2) do s = "0" + s
		
		local timeMin = m + ":" + s
		local f = if (m == "0") then "sec" else "min"
		
		lblStatus.caption = formatString (msg + " $1 $2...") v: #(timeMin, f)
	)
	
	fn restartProcessFiles msg: "" = (
		statusMessageRestartQueueIn dispose: true
		statusMessageRestartMaxIn dispose: true
		statusMessageScanningWillStart dispose: true
		
		statusMessageRestartQueueIn create: true msg: msg
		tmrQueueRestart.active = false
		tmrQueueRestart.active = true
	)
	
	/* PROCESS FILES */
	fn processFiles = (
		local r = false
		statusMessageRestartQueueIn dispose: true
		statusMessageRestartMaxIn dispose: true
		statusMessageScanningWillStart dispose: true
		
		local d = edtInputPath.text
		local jr = JsonReaderWrapper()
		local q = requestMgr.getQueue()
		jr.read q
		
		lblStatus.caption = "Get queue..."
		print "Get queue..."
		
		-- Is correct JSON (Restart)
		local isSuccess = jr.getBool "success"
		if (not isSuccess) do (	
			restartProcessFiles msg: "Can't receive request from api. Restart in"
			return false
		)
		
		-- Is Queue not empty (Restart)
		if (jr.getString "message" != "queue_item_received") do (
			restartProcessFiles msg: "Queue is empty. Restart in"		
			return false
		)
		
		statusMessageRestartQueueIn dispose: true
		statusMessageRestartMaxIn dispose: true
		statusMessageScanningWillStart dispose: true
		
		lblStatus.caption = "Parse JSON..."
		print "Parse JSON..."
		
		-- Parse JSON
		local a_id = jr.getString "autoconvertion_id"
		local model_id = jr.getString "model_id"
		local version_id = jr.getString "version_id"		
		local slug = jr.getString "slug"
		local download_ur = jr.getString "download_url"
		local status_id = jr.getString "status_id"
		local source_original_name = jr.getString "source_original_name"
		local count_total = jr.getInt "count_total"
		
		lblStatus.caption = "Update status to In Progress..."
		print "Update status to In Progress..."
		
		-- Set Status: in_progress
		r = requestMgr.setStatus a_id #in_progress txt: (slug + " file in progress!")
		
		
		local downloadMgr = DownloadWrapper()
		local guid = genGUID()
		local fname = guid + ".zip"
		local file = d + fname
		-- Clear all files in folder
		lblStatus.caption = "Clear folder..."
		print "Clear folder..."
		clearFolder d
		
		-- Download file
		lblStatus.caption = "Downloading file..."
		print "Downloading file..."
		
		downloadMgr.download download_ur file
		
		lblStatus.caption = "File downloaded..."
		print "File downloaded..."
		
		-- Is file not valid immediately request next file
		if (not downloadMgr.isValidFile file) do (
			r = requestMgr.setStatus a_id #error txt: ("File not downloaded: " + slug + "!")
			processFiles()
			return false
		)
		
		r = requestMgr.setStatus a_id #downloaded txt: ("File downloaded: " + slug + "!")
		
		print "process file"
		print autoconvertion_id
		print version_id
	)
	
	
	on btnStartStartupProcess changed v do (
		local errors = #()
		local isBlenderExist = (BlenderGLBWrapper()).isBlenderExist()
		local isSketchupExist = (SketchupConverterWrapper()).isSketchupExist()
		
		local d = edtInputPath.text
		
		if (d == "") do (
			btnStartStartupProcess.checked = false
			append errors #("Please Working Path!", true)
		)
		
		if (cbxConvertToBlend.checked and not isBlenderExist) do append errors #("Not found Blender program!", false)
		if (cbxConvertToSketchup.checked and not isSketchupExist) do append errors #("Not found Sketchup program!", false)
		
		if (errors.count > 0) do (
			local isCritical = false
			local m = "Please fix the following errors:\n\n"
			
			for i in 1 to errors.count do (
				m += (i as string) + ". " + errors[i][1] + "\n"
				if (errors[i][2]) do isCritical = true
			)
			
			messageBox m title: "Error!"			
			
			if (isCritical) do return false
		)
		
		warnAboutNecessaryOptions()
		
		if (v) then (
			local s = "try (fileIn @\"" + (getThisScriptFilename()) + "\") catch (print \"Error! Can't GC-Autoconverter-GLB.ms!\")"
			writeFile startupScript s
			
			statusMessageScanningWillStart create: true
			
			tmrOnStartDelay.active = true
			
			print "Autoconverting enabled!"
		) else (
			forceDeleteFile startupScript	
			tmrOnStartDelay.active = false
			statusMessageRestartMaxIn dispose: true
			statusMessageScanningWillStart dispose: true
				
			lblStatus.caption =	"Autoconverting disabled!"
			print "Autoconverting disabled!"
		)
		
		updateButtonStatus()
	)
	
	on _rGCAutoGLBConverter_Main open do (
		_fGCAutoGLBConverter.pos = [0, 0]
		
		loadSettings()
		updateButtonStatus()
		
		if (btnStartStartupProcess.checked) do (
			local d = edtInputPath.text
			
			if (d == "") do (
				btnStartStartupProcess.checked = false
				forceDeleteFile startupScript
				return messageBox "Please set Working Path!" title: "Error!"
			)
			
			statusMessageScanningWillStart create: true
			tmrOnStartDelay.active = true
		)
	)
	
	on tmrCounterBeforeStart tick do (
		statusMessageScanningWillStart()
	)
	
	on tmrCounterMaxRestart tick do (
		statusMessageRestartMaxIn()
	)
	
	on tmrOnStartDelay tick do (
		tmrOnStartDelay.active = false
		processFiles retry: true
	)
	
	on tmrCounterQueueRestart tick do (
		statusMessageRestartQueueIn()
	)
	
	on tmrQueueRestart tick do (
		tmrQueueRestart.active = false
		processFiles()
	)
)

rollout _rGCAutoGLBConverter_About "About" (
	group "Description" (
		dotNetControl edtDescription "System.Windows.Forms.Textbox" align:#center height: 60
	)
	
	label lblDummy1 ""
    
	label lblName "" 
	label lblVer ""
	label lblClient ""
	
	label lblDummy2 ""
	
	label lblAuthor ""
	hyperlink lblCopy ""  align: #center
	
	label lblDummy3 ""
	
	timer tmrRestart "" active: false interval: 300
	
	fn downloadFile url dl = (
		deleteFile dl
		w = dotNetObject "System.Net.WebClient"			
		try(
			spm = dotNetClass "System.Net.ServicePointManager"
			spm.SecurityProtocol = spm.SecurityProtocol.TLS12				
			w.DownloadFile (url + "?time=" + timestamp() as string) dl				
		) catch(
			return false
		)
		
		return true
	)
	
	fn bgUpdate = (
		local url = "https://raw.githubusercontent.com/MastaMan/GC-Autoconverter-GLB/main/"
		local main = url + "GC-Autoconverter-GLB.ms"
		
		local this = getThisScriptFileName()
		local p = getFileNamePath (getThisScriptFileName())
		local dl = this + ".tmp"
		local r = downloadFile main dl
		if(not r or not doesFileExist dl) do return print "Can't download updates!"
		local vn = getIniSetting dl "INFO" "VERSION"
		local vo = getIniSetting this "INFO" "VERSION"
		local additionalFiles = getIniSetting dl "FILES"
		
		if(vn > vo) do (
			deleteFile this
			renameFile dl this
			
			for n in additionalFiles do (
				local s = getIniSetting dl "FILES" n
				if (s == "") do downloadFile (url + n) (p + n)
				if (s == "deleted") do deleteFile (p + n)
			)
			
			tmrRestart.active = true
		)
		
		deleteFile dl
	)
	
	fn updateWorker = (
		m = dotnetobject "CSharpUtilities.SynchronizingBackgroundWorker"
		m.WorkerSupportsCancellation = true 
		m.CancelAsync() 
		dotNet.addEventHandler m "DoWork" bgUpdate
		m.RunWorkerAsync()	
	)
	
    fn getScriptInfo s releaseInfo: "" =  (
        if(releaseInfo != "") do (
            local r = getINISetting s releaseInfo
            return r
        )
		
        local v = getINISetting s "INFO" "VERSION"
        local a = getINISetting s "INFO" "AUTHOR"
        local n = getINISetting s "INFO" "NAME"
        local o = ""
		for i in (getINISetting s "ABOUT") do o += i + "\r\n"
        local d = getINISetting s "INFO" "DEV"
        local h = getINISetting s "INFO" "HELP"
        local c = getINISetting s "INFO" "CLIENT"
        
		struct data (version, author, name, description, developer, client, help, releases)
		
        local r = for i in (getINISetting s) where (i != "ABOUT" and i != "SCRIPT" and i != "COPY") collect i
		
		return (data version: v author: a name: n description: o developer: d client: c help: h releases: r)
    )
	
	on tmrRestart tick do (
		this = getThisScriptFileName()
		try(fileIn this) catch()
		vo = getIniSetting this "INFO" "VERSION"
		m = ("Script updated to version " + vo + "!\n\n\n")
		for c in (getIniSetting this vo) do (
			m += c + "\n"
		)
		
		--messageBox m title: "Success!" beep: false
		print "---UPDATED---"
		print m
		tmrRestart.active = false
	)

    on _rGCAutoGLBConverter_About open do (
		edtDescription.MultiLine = true
		edtDescription.WordWrap = true
		edtDescription.ReadOnly = true
		edtDescription.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
		
		
        local i = getScriptInfo (getThisScriptFilename())
		
        lblName.caption = i.name
        lblAuthor.caption = i.author
        lblVer.caption = i.version
        lblCopy.address = lblCopy.caption = i.developer
        lblClient.caption = i.client
		edtDescription.text = i.description
		
		try (_fGCAutoGLBConverter.title = i.client) catch()
		try (_rGCAutoGLBConverter_Main.title = i.name + " v" +  i.version) catch()
		
		updateWorker()
    )		
)

addRollout _rGCAutoGLBConverter_Main _fGCAutoGLBConverter rolledUp: false
addRollout _rGCAutoGLBConverter_About _fGCAutoGLBConverter rolledUp: true
