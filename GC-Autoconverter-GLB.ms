/*
[INFO]
NAME=GC Autoconverter GLB
VERSION=1.0.7
AUTHOR=Vasyl Lukianenko
DEV=https://3dground.net
HELP=
CLIENT=Great Catalog
[ABOUT]
Auto Converter to GLB/SKP/BLEND script=


[1.0.0]
*Initial release =

[1.0.1]
+ Added: Debug section =

[1.0.2]
+ Added: Test connections in Credentials =

[1.0.3]
+ Added: Support Telegrams notifications =

[1.0.4]
- BugFix: SKP withou archive =

[1.0.5]
+ Added: Telegram success/error processing reports with screenshots and technical logs=
+ Added: result_json file listing for successful uploads=
+ Added: 3ds Max restart after 20 processed queue items=
+ Added: Remaining files before restart indicator=
+ Added: error.jpg fallback image for Telegram error reports=
+ Improved: JSON string escaping for API payloads=

[1.0.6]
- BugFix: Small fixes=

[1.0.7]
+ Added: External watchdog heartbeat with visible restart countdown=
+ Added: Configurable watchdog timeout in Settings=
+ Improved: Converted output file names now include autoconversion id and slug=
+ Improved: Watchdog uses UTC Unix timestamps consistently between MaxScript and BAT=

[FILES]
Install.mcr=
jpegoptim.exe=
convert.exe=
gltfpack.exe=
7za.exe=
denoise.bat=
gltfpack.bat=
vdenoise.xml=
normalmap.exe=
xnormal.bat=deleted
xnormal.xml=deleted
lowes-viewer.zip=deleted
model-viewer.zip=
api-error.jpg=
error.jpg=
chrome-screenshot.bat=
chrome-preview.bat=
chrome.bat=deleted
archivate.bat=
extract.bat=
screenshot.bat=
disable-windows-nags.reg=
blender-screenshot.bat=
blender-zoom-extends.py=
blender-import-glb.py=
blender-bg-import.bat=
blender-gen-ini.py=
blender-bg-run.bat=
download.bat=
restart.bat=
get-max-render.bat=
sync-to-aws.bat=deleted
blender-render.bat=
blender-render.py=
clamp-colors.bat=
contrast.bat=
s3-uploader.bat=
telegram-uploader.bat=
test-telegram-uploader.bat=
watchdog.bat=
curl.exe=
web-request.bat=deleted
sketchup-convert.bat=
template.skp=
listener-error-observer.ms=
test-s3-uploader.ms=


[SCRIPT]
*/

heapSize += (1000000 * 40) -- 40Mb

struct listenerObserverWrapper (
	currentPath = getFileNamePath (getThisScriptFileName()),
	script = currentPath + "listener-error-observer.ms",
	fn run = (
		try (fileIn script) catch (print "Can't run Listener Observer service!")
	),
	fn destroy = (
		try (DestroyDialog listenerObserver) catch ()
	)
)

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

	fn addZero p = (
		p = p as string
		if (p.count == 1) do p = "0" + p
		return p
	),

	fn getCurrentDateTime = (
		local n = (dotNetClass "System.DateTime").Now
		local d = addZero n.day
		local m = addZero n.month
		local y = n.year as string
		local hh = addZero n.hour
		local mm = addZero n.minute
		local ss = addZero n.second

		return d + "." + m + "." + y + " " + hh + ":" + mm + ":" + ss
	),

	fn writeFileUTF8 o b = (
		local s = dotNetObject "System.IO.StreamWriter" (o) true ((dotNetClass "System.Text.Encoding").GetEncoding("UTF-8"))

		for l in b where l.count > 0 do s.WriteLine(dotNetObject "System.String" l)
		s.Close()
	),

	fn escapeJsonString s = (
		s = s as string
		s = substituteString s "\\" "\\\\"
		s = substituteString s "\"" "\\\""
		s = substituteString s "\r" "\\r"
		s = substituteString s "\n" "\\n"
		s = substituteString s "\t" "\\t"
		return s
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
				String:  j += qq + (escapeJsonString p[2]) + qq + comma
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

									j += t + t + t + q + pp[1] + q + ": \"" + (escapeJsonString pp[2]) + q + comma3
								)
							j += t + t + "}" + comma2
						) else (
							j += t + t + q + (escapeJsonString z) + q + comma2
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
		try (deleteFile fname) catch ()

		-- Force add some data in the end
		addData data "date" (getCurrentDateTime())
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
	a_id = -1,
	model_id = -1,
	version_id = -1,
	slug = "",
	apiUrl = "", -- !!!!Change new to PROD
	apiGetQueue = apiUrl  + "queue.php",
	apiPostStatus = apiUrl  + "status.php",
	apiPostLog = apiUrl  + "log.php",
	apiKey = "",
	fn setBaseUrl url = (
		if (url == undefined) do url = ""
		url = trimLeft (trimRight (url as string))

		if (url != "" and (substring url url.count 1) != "/") do url += "/"

		apiUrl = url
		apiGetQueue = apiUrl + "queue.php"
		apiPostStatus = apiUrl + "status.php"
		apiPostLog = apiUrl + "log.php"
	),
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
		catch ()

		try (client.Dispose()) catch()
		return result
	),
	fn getQueue = (
		return this.downloadString apiGetQueue
	),
	fn postStatus status txt: "" result_json: undefined = (
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
			#("autoconvertion_id", a_id),
			#("status_id", s),
			#("txt", txt)
		)

		if (result_json != undefined) do (
			append data #("result_json", result_json)
		)

		return this.post apiPostStatus data
	),
	fn postAttempt = (
		local data = #(
			#("autoconvertion_id", a_id),
			#("attempt_convertion", true)
		)

		return this.post apiPostStatus data
	),
	fn postLog txt: "" = (
		if (txt == "") do return false

		local data = #(
			#("autoconvertion_id", a_id),
			#("txt", txt)
		)
		return this.post apiPostLog data
	),
	fn checkCredentialsError = (
		if (apiUrl.count < 10) do return true
		if (apiKey.count < 20) do return true

		return false
	)
)

global requestMgr = requestWrapper()

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

struct awsUploaderWrapper (
	currentPath = getFileNamePath (getThisScriptFileName()),
	region = "",
	bucket = "",
	user = "",
	key = "",

	fn readUploadLog logFile = (
		if (logFile == undefined or logFile == "" or not doesFileExist logFile) do return ""

		local result = ""
		local stream = undefined
		try (
			stream = openFile logFile mode: "rt"
			while not eof stream do (
				result += (readLine stream) + "\n"
			)
		) catch ()

		try (close stream) catch ()
		try (deleteFile logFile) catch ()
		return trimRight result
	),

	fn upload f = (
		if (f == undefined or f == "") do return #("false", "Upload failed: empty file path.", 2)
		if (not doesFileExist f) do return #("false", ("Upload failed: file does not exist: " + f), 3)

		local n = filenameFromPath f
		local logFile = (getDir #temp) + "\\s3-uploader-" + (timestamp() as string) + ".log"
		local args = f + ";" + bucket + ";" + region + ";" + n + ";" + user + ";" + key + ";" + logFile
		local cmd = "s3-uploader.bat \"" +  args + "\""
		local exitcode = 0
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		try (
			HiddenDOSCommand cmd exitCode: &exitcode donotwait: false
		) catch (
			exitcode = -1
		)

		sysInfo.currentDir = curDir

		if (exitcode == 0) then (
			return #("true", ("Uploaded to S3: " + n), exitcode)
		) else (
			local curlLog = readUploadLog logFile
			local msg = case exitcode of (
				2: "Upload failed: S3 uploader received invalid arguments for " + n + "."
				3: "Upload failed: file not found: " + n + "."
				4: "Upload failed: curl.exe not found."
				10: "Upload failed: S3 rejected or interrupted upload for " + n + "."
				default: "Upload failed: " + n + ". Exit code: " + (exitcode as string) + "."
			)

			if (curlLog != "") do (
				format "S3 upload error for %:\n%\n" n curlLog
				msg += "\n\nCurl output:\n" + curlLog
			)
			return #("false", msg, exitcode)
		)
	),
	fn checkCredentialsError = (
		if (region.count < 5) do return true
		if (bucket.count < 3) do return true
		if (user.count < 18) do return true
		if (key.count < 30) do return true

		return false
	)
)

global awsUploaderMgr = awsUploaderWrapper()

struct TelegramWrapper (
	currentPath = getFileNamePath (getThisScriptFileName()),
	bat = currentPath + "telegram-uploader.bat",
	token = "",
	chatId = "",
	lastExitCode = 0,
	lastError = "",

	fn checkCredentialsError = (
		if (token.count < 20) do return true
		if (chatId.count < 3) do return true
		if (not doesFileExist bat) do return true

		return false
	),

	fn writeTextFile f txt = (
		local stream = undefined
		try (
			stream = dotNetObject "System.IO.StreamWriter" f false ((dotNetClass "System.Text.Encoding").GetEncoding("UTF-8"))
			stream.Write (txt as string)
			stream.Close()
			return true
		) catch (
			try (stream.Close()) catch ()
			return false
		)
	),

	fn readTextFile f = (
		if (not doesFileExist f) do return ""
		local stream = undefined
		try (
			stream = dotNetObject "System.IO.StreamReader" f ((dotNetClass "System.Text.Encoding").GetEncoding("UTF-8"))
			local txt = stream.ReadToEnd()
			stream.Close()
			return txt
		) catch (
			try (stream.Close()) catch ()
			return ""
		)
	),

	fn send txt image: "" = (
		lastExitCode = 0
		lastError = ""

		if (this.checkCredentialsError()) do (
			lastError = "Telegram credentials are missing or invalid, or telegram-uploader.bat was not found."
			return false
		)
		if (txt == undefined) do txt = ""

		local stamp = timestamp() as string
		local textFile = (getDir #temp) + "\\telegram-message-" + stamp + ".txt"
		local logFile = (getDir #temp) + "\\telegram-send-" + stamp + ".log"
		if (not (writeTextFile textFile txt)) do (
			lastError = "Cannot write temporary Telegram message file."
			return false
		)

		local args = token + ";" + chatId + ";" + textFile + ";" + image + ";" + logFile
		local cmd = "telegram-uploader.bat \"" + args + "\""

		local curDir = sysInfo.currentDir
		local exitcode = 0
		sysInfo.currentDir = currentPath
		try (
			HiddenDOSCommand cmd exitCode: &exitcode donotwait: false
		) catch (
			exitcode = -1
		)
		sysInfo.currentDir = curDir

		lastExitCode = exitcode
		lastError = this.readTextFile logFile
		try (deleteFile textFile) catch ()
		try (deleteFile logFile) catch ()

		if (exitcode != 0) do (
			if (lastError == "") do lastError = "curl exit code: " + (exitcode as string)
			return false
		)

		return true
	),

	fn sendMessage txt = (
		return this.send txt
	),

	fn sendPhoto txt image = (
		return this.send txt image: image
	),

	fn getLastError = (
		local msg = ""
		if (lastError != "") do msg += lastError
		if (msg == "") do msg = "Unknown Telegram error."
		return msg
	)
)

global telegramMgr = TelegramWrapper()

struct settingsWrapper (
	currScript = getThisScriptFileName(),
	name = getFilenameFile currScript,
	pth = getFileNamePath currScript,
	ini = pth +  "global@settings.ini",
	--ini = (getThisScriptFileName()) + ".ini",
	sec = name,

	fn trim s tag: "" = (
		s as string
		return (trimLeft (trimRight s tag) tag)
	),

	fn add k v sec: "" = (
		if (sec == "") do sec = this.sec
		if (v == undefined) do v = ""
		setIniSetting this.ini sec k (v as string)
	),

	fn get k sec: "" type: #string = (
		if (sec == "") do sec = this.sec

		if (k == "") do return getINISetting this.ini sec

		local v = getIniSetting this.ini sec k

		case type of (
			#bool_true: return if (v == "true") then true else false
			#bool_false: return if (v == "false") then false else true
			#int: return try (v as integer) catch(0)
			#float: return try (v as float) catch(0.0)
		)

		return v
	),

	fn del k sec: "" = (
		if (sec == "") do sec = this.sec
		delIniSetting ini sec k
	),

	fn delSec s = (
		delIniSetting ini s
	)
)

global '*' = settingsWrapper()

struct watchdogWrapper (
	currentPath = getFileNamePath (getThisScriptFileName()),
	ini = currentPath + "watchdog.ini",
	sec = "WATCHDOG",
	settingsIni = currentPath + "global@settings.ini",
	settingsSec = getFilenameFile (getThisScriptFileName()),
	defaultTimeoutMin = 15,

	fn getTimeoutMin = (
		local timeoutMin = try ((getIniSetting settingsIni settingsSec "spnWatchdogTimeoutMin") as integer) catch (0)
		if (timeoutMin < 1) do timeoutMin = defaultTimeoutMin
		return timeoutMin
	),

	fn getTimeoutSec = (
		return (this.getTimeoutMin()) * 60
	),

	fn saveTimeout = (
		setIniSetting this.settingsIni this.settingsSec "spnWatchdogTimeoutMin" ((this.getTimeoutMin()) as string)
	),

	fn nowSec = (
		-- Keep this in UTC Unix seconds; watchdog.bat uses the same .NET time basis.
		local now = (dotNetClass "System.DateTimeOffset").UtcNow
		return trimRight ((now.ToUnixTimeSeconds()) as string) "L"
	),

	fn start slug a_id stage: "in_progress" = (
		local startedAt = this.nowSec()
		setIniSetting this.ini this.sec "slug" (slug as string)
		setIniSetting this.ini this.sec "a_id" (a_id as string)
		setIniSetting this.ini this.sec "stage" (stage as string)
		setIniSetting this.ini this.sec "startedAt" startedAt
		setIniSetting this.ini this.sec "heartbeatAt" startedAt
	),

	fn beat stage: "" = (
		local activeSlug = getIniSetting this.ini this.sec "slug"
		if (activeSlug == undefined or activeSlug == "") do return false
		if (stage != "") do setIniSetting this.ini this.sec "stage" (stage as string)
		setIniSetting this.ini this.sec "heartbeatAt" (this.nowSec())
		return true
	),

	fn clear = (
		setIniSetting this.ini this.sec "slug" ""
		setIniSetting this.ini this.sec "a_id" ""
		setIniSetting this.ini this.sec "stage" ""
		setIniSetting this.ini this.sec "startedAt" ""
		setIniSetting this.ini this.sec "heartbeatAt" ""
	)
)

global watchdogMgr = watchdogWrapper()

fn getCredentialsMode = (
	local m = '*'.get "mode"
	if (m == "2") then #test else #prod
)

fn getCredentialsModeLabel mode = (
	case mode of (
		#test: "Testing"
		default: "Production"
	)
)

fn getCredentialsPrefix mode = (
	case mode of (
		#test: "test"
		default: "prod"
	)
)

fn getCredentialsKey mode key = (
	return (getCredentialsPrefix mode) + key
)

fn migrateCredentialsSettings = (
	local migrations = #(
		#("WebApiSecretKey", "edtWebApiSecretKey"),
		#("AwsRegion", "edtAwsRegion"),
		#("AwsBucket", "edtAwsBucket"),
		#("AwsUser", "edtAwsUser"),
		#("AwsSecretKey", "edtAwsSecretKey"),
		#("TelegramToken", "edtTelegramToken"),
		#("TelegramChatId", "edtTelegramChatId")
	)

	if (('*'.get (getCredentialsKey #prod "WebApiBaseUrl")) == "") do (
		'*'.add (getCredentialsKey #prod "WebApiBaseUrl") ((requestWrapper()).apiUrl)
	)

	for m in migrations do (
		local newKey = getCredentialsKey #prod (m[1])
		local oldValue = '*'.get (m[2])

		if (('*'.get newKey) == "" and oldValue != "") do (
			'*'.add newKey oldValue
		)
	)
)

fn getCredentialValue mode key defaultValue: "" = (
	migrateCredentialsSettings()

	local v = '*'.get (getCredentialsKey mode key)
	if (v == "" and defaultValue != "") do return defaultValue
	return v
)

fn applyCredentialProfile mode = (
	migrateCredentialsSettings()

	local defaultBaseUrl = if (mode == #prod) then (requestWrapper()).apiUrl else ""
	local baseUrl = getCredentialValue mode "WebApiBaseUrl" defaultValue: defaultBaseUrl

	requestMgr.setBaseUrl baseUrl
	requestMgr.apiKey = getCredentialValue mode "WebApiSecretKey"

	awsUploaderMgr.region = getCredentialValue mode "AwsRegion"
	awsUploaderMgr.bucket = getCredentialValue mode "AwsBucket"
	awsUploaderMgr.user = getCredentialValue mode "AwsUser"
	awsUploaderMgr.key = getCredentialValue mode "AwsSecretKey"

	telegramMgr.token = getCredentialValue mode "TelegramToken"
	telegramMgr.chatId = getCredentialValue mode "TelegramChatId"
)

struct utilsWrapper (
	fn maxVer  = (
		local v = (maxVersion())[1]
		v = 2000 + ((v / 1000) - 2)
		return v
	),
	fn boost = (
		windows.processPostedMessages()
	),
	fn formatString s v: #() tag: "$" = (
		for i in 1 to v.count  do (
			local t = v[i] as string
			s = substituteString s (tag + i as string) (t)
		)

		return s
	),
	fn trim s tag: " "= (
		return trimLeft (trimRight s tag) tag
	),
	fn polyCount s = (
		local iPoly = 0
		local iVert = 0

		local a = for i in s collect (getPolygonCount i)
		for i in a do (
			iPoly += i[1]
			iVert += i[2]
		)

		return #(iPoly, iVert)
	)
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
	fn makeArchive = (
		archivate this.zip this.tmpOut
		this.j.addData json "name" (filenameFromPath this.zip)
		this.j.addData json "sizeMb" (getFileMb this.zip)
	),
	fn makeJson = (
		this.j.writeJson this.jsonFile this.json
	),

	fn init input: "" glb: "" name: "" = (
		this.json = #()

		local p = getFilenamePath glb
		local pp = p + name + @"\"
		makeDir pp all: true

		this.input = input
		this.glb = glb

		this.preview = p + name + ".png"
		this.zip = p + name + ".zip"
		this.outFile = pp + name + ".skp"
		this.jsonFile = p + name + ".json"
		this.tmpOut = pp
	)
)

struct WebGLPlayerWrapper (
	currentPath = getFilenamePath (getThisScriptFilename()),
	zippedPlayer = currentPath + "model-viewer.zip",
	playerPath = currentPath + @"model-viewer\",
	imgPath =  playerPath + @"images\",
	webserver = playerPath + "webserver.bat",
	port = "33333",
	localhost = "http://localhost:" + port,
	urlModelPreview = localhost + "/?model=",
	urlImgPreview = localhost + "/img-preview.html?id=",

	fn extractZip f o = (
        if (f == undefined or not doesFileExist f) do return false
        if (getFilenameType f != ".zip") do return false

		local args = f + ";" + o
		args = substituteString args "/" @"\"

		local cmd = "start /b /min extract.bat \"" +  args + "\""

		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath

		hiddenDosCommand cmd exitCode: &exitcode donotwait: true

		sysInfo.currentDir = curDir
    ),

	fn makeBrowserScreenshot f s = (
		local ne = filenameFromPath f
		local n = getFilenameFile f
		local destGLB = playerPath + ne

		deleteFile destGLB
		copyFile f destGLB

		curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath

		local args = (urlModelPreview + ne) + ";" + s
		local cmd2 = "chrome-screenshot.bat \"" +  args + "\""
		hiddenDosCommand cmd2 exitcode:&exitcode

		sysInfo.currentDir = curDir
	),

	fn previewModel f kill: "1" = (
		local ne = filenameFromPath f
		local n = getFilenameFile f
		local destGLB = playerPath + ne

		deleteFile destGLB
		copyFile f destGLB

		curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath

		local args = (urlModelPreview + ne) + ";" + kill
		local cmd = "chrome-preview.bat \"" +  args + "\""
		hiddenDosCommand cmd exitcode:&exitcode

		sysInfo.currentDir = curDir
	),

	fn previewImg id kill: "1" type: #web = (
		if (type == #local) do (
			local ne = filenameFromPath id
			local n = getFilenameFile id
			local destImg = imgPath + ne

			deleteFile destImg
			copyFile id destImg
			id = "/images/" + ne
		)

		curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath

		local args = urlImgPreview + id + ";" + kill
		local cmd2 = "chrome-preview.bat \"" +  args + "\""
		hiddenDosCommand cmd2 exitcode:&exitcode

		sysInfo.currentDir = curDir
	),

	fn startWebServer  = (
		makeDir imgPath all: true
		for i in (getFiles (imgPath + "*.*")) do deleteFile i
		for i in (getFiles (playerPath + "*.glb")) do deleteFile i

		if (doesFileExist zippedPlayer /*and not doesFileExist webserver*/) do (
			extractZip	zippedPlayer playerPath
		)

		if (not doesFileExist webserver) do return  messageBox "Cannot find Model Viewer Player or Webserver. Please reinstall the script." title: "Warning!"

		curDir = sysInfo.currentDir
		sysInfo.currentDir = playerPath

		local args = playerPath + ";" + port
		local cmd = "start /b /min " + (filenameFromPath webserver) + " \"" +  args + "\""

		hiddenDosCommand cmd exitcode:&exitcode
	),

	fn run = (
		startWebServer()
	)
)

struct BatchGLBConverterWrapper (
	selfPath = getFilenamePath (getThisScriptFilename()),
	texturesQueueNames = #(),
	normalsQueueNames = #(),
	texturesQueue = #(),
	normalsQueue = #(),
	outPath = "",
	convertexe = "",
	json = #(),
	j = JsonWrapper(),
	w = WebGLPlayerWrapper(),

	fn isValidObject o = (
		return o.material != undefined and isValidNode o and not isDeleted o and canConvertTo o Editable_mesh
	),

	fn getDependents m = (
		return for r in refs.dependents m where isKindOf r textureMap or isKindOf r Material collect r
	),

	fn getRefSlotId m ref out: undefined = (
		for i in 1 to getNumSubTexmaps m do (
			local sm = getSubTexmap m i
			if (sm == ref) do return i
		)

		return undefined
	),

	fn ungroupRecursive = (
		local s = objects
		fn tmpUngroup s = (
			local o = false
			for i in s where isGroupHead i and isValidNode i do (
				explodeGroup i
				o = true
			)
			return o
		)

		while k != false do k = tmpUngroup s
	),

	fn fixGeometry = (
		local oo = objects as array
		with redraw off (
			with undo off (
				for o in oo where this.isValidObject o do (
					ResetXForm o
					convertToMesh o
					local a = snapshot o
					a.name = o.name
					a.wirecolor = o.wirecolor

					if (classOf a == Editable_Mesh or classOf a == Editable_Poly) do (
						update a
					)
					try(delete o) catch()
				)
			)
		)
	),

	fn instnceDuplicateMaps = (
		local names = #()
		local maps = #()
		for i in getClassInstances Bitmaptexture do (
			if (i.filename == undefined or i.filename == "") do continue
			local n = toLower (filenameFromPath i.filename)
			local id = findItem names n
			if (id == 0) then (
				append names n
				maps[names.count] = #(i)
			) else (
				appendIfUnique maps[id] i
			)
		)

		for i in maps do (
			for id in 2 to i.count do (
				replaceInstances i[id] i[1]
			)
		)

		free names
		free maps
	),

	fn optimizeImages files: #() quality: 90 = (
		if (files.count == 0) do return false

		local jpgoptim = "\"" + this.selfPath + "jpegoptim.exe\""
		local p = getFilenamePath files[1]
		makeDir p all: true


		curDir = sysInfo.currentDir
		sysInfo.currentDir = p

		local imgs = ""

		for i in files do imgs += "\"" + (filenameFromPath i) + "\" "

		local cmd = jpgoptim + " --strip-all --all-progressive -f -o -q -m" + (quality as string) + "  " + imgs

		hiddenDosCommand cmd exitcode:&exitcode

		sysInfo.currentDir = curDir
	),

	fn deployConvertExe = (
		local convertexe = this.selfPath + "convert.exe"
		local tmpDir = @"C:\temp\"
		local tmpConvertexe = tmpDir + "convert.exe"
		makeDir tmpDir
		copyFile convertexe tmpConvertexe
		return tmpConvertexe
	),

	fn convertImageTo f isDelete: true type: #jpg = (
		local p = getFilenamePath f
		local n = getFilenameFile f
		local ext = getFilenameType f
		local exe = this.convertexe

		local tt = case type of (
			#png: ".png"
			default: ".jpg"
		)

		local ff = p + n + tt

		local curDir = sysInfo.currentDir
		sysInfo.currentDir = this.selfPath

		local cmd = exe + " \"" + f + "\" \"" + ff + "\""
		hiddenDosCommand cmd exitcode:&exitcode
		sysInfo.currentDir = curDir

		if (isDelete and ext != tt) do deleteFile f

		this.optimizeImages files: #(ff)

		return ff
	),

	fn contrastImage f = (
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = this.selfPath

		local args = f + ";" + f
		local cmd = "contrast.bat \"" + args + "\""

		hiddenDosCommand cmd exitcode:&exitcode
		sysInfo.currentDir = curDir
	),

	fn clampImageColors f = (
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = this.selfPath

		local args = f + ";" + f
		local cmd = "clamp-colors.bat \"" + args + "\""


		hiddenDosCommand cmd exitcode:&exitcode
		sysInfo.currentDir = curDir
	),

	fn resizeImage f maxSize: 2048 type: #jpg = (
		local size = maxSize as string + "x" + maxSize as string + @">"

		local convertexe = this.selfPath + "convert.exe"
		local tmpDir = @"C:\temp\"
		local tmpConvertexe = tmpDir + "convert.exe"
		makeDir tmpDir
		copyFile convertexe tmpConvertexe

		local exe = tmpConvertexe

		if (doesFileExist f and getFileSize f > 0) do return f

		local curDir = sysInfo.currentDir
		sysInfo.currentDir = this.selfPath

		local cmd = exe + " \"" + f + "\" -resize \"" + size + "\" \"" + f + "\""
		hiddenDosCommand cmd exitcode:&exitcode
		sysInfo.currentDir = curDir

		this.optimizeImages files: #(f)

		return f
	),

	fn getSceneDir = (
		local n = this.getSceneName()
		local p = maxFilePath
		if (p == "") do p = this.outPath + n + @"\"
		return p
	),

	fn getCacheMapsDir = (
		local p = (getSceneDir()) + @"_glb_cache\"
		makeDir p all: true
		return p
	),

	fn getUnusedDirs = (
		local s = this.getSceneName()
		local dd = #()

		append dd (this.outPath + s + @"\")

		return dd
	),

	fn generateCacheFilename type: #jpg = (
		local p = this.getCacheMapsDir()
		local ext = case type of (
			#png: ".png"
			default: ".jpg"
		)

		return p + "__cache_" + (timeStamp() as string) + ext
	),

	fn getCurrentMaxVersion = (
		local v = maxVersion()
		v = (v[1] / 1000) - 2

		return (2000 + v) as string
	),

	fn clearCacheMapsDir = (
		local p = getCacheMapsDir()
		for i in getFiles (p + "__cache_*.jpg") do deleteFile i
	),

	fn getSceneName = (
		return getFileNameFile maxFileName
	),

	fn getMapChannel t = (
		for i in (getClassInstances Bitmaptexture target: t) do (
			return try (i.coords.mapChannel) catch (1)
		)

		return 1
	),

	fn renderTargetMap t size: [2048, 2048] isReplace: true type: #jpg clamp: true = (
		if (t == undefined) do return undefined

		local mapChannel = getMapChannel t
		local p = this.getCacheMapsDir()
		makeDir p all: true
		local f = this.generateCacheFilename type: #png

		local rm = renderMap t size: size filename: f --display: true  --into: lm
		rm.gamma = 2.2
		rm.filename = f

		save rm
		close rm

		if (type != #png) do (
			f = this.convertImageTo f type: #jpg
		)

		if (clamp) do this.clampImageColors f

		this.optimizeImages files: #(f)

		local bt = Bitmaptexture filename: f
		bt.coords.mapChannel = mapChannel

		if (isReplace) do replaceInstances t bt

		return bt
	),

	fn getMapFullPath f = (
		return mapPaths.getFullFilePath (filenameFromPath f)
	),

	fn cacheBitmap t resize: true type: #jpg clamp: true = (
		local f = t.filename
		if (f == undefined or f == "") do return undefined
		local ff = this.generateCacheFilename()
		f = this.getMapFullPath f

		copyFile f ff

		ff = this.convertImageTo ff type: type

		if (resize) do this.resizeImage ff
		if (clamp) do this.clampImageColors ff

		t.filename = ff

		if (not doesFileExist ff) do return undefined

		return t
	),

	fn extractBitmapFromSlot m = (
		local a = getClassInstances Bitmaptexture target: m
		return a[1]
	),

	fn convertBumpToNormal t = (
		if (t == undefined) do return false

		local normalmap = this.selfPath + "normalmap.exe"
		local tmpDir = @"C:\temp\"
		local tmpNormalmap = tmpDir + "normalmap.exe"
		makeDir tmpDir
		copyFile normalmap tmpNormalmap

		local exe = tmpNormalmap

		local bt = undefined
		if (classOf t == Bitmaptexture) then (
			bt = this.cacheBitmap t type: #png
		) else (
			-- If possible extract one bitmap for normal
			local _tmp = this.extractBitmapFromSlot t
			if (_tmp == undefined) then (
				bt = this.renderTargetMap t isReplace: false type: #png
			) else (
				bt = this.cacheBitmap _tmp type: #png
			)
		)

		if (bt == undefined) do return false

		local f = bt.filename
		local ff = this.generateCacheFilename type: #png

		local p = getFilenamePath f
		makeDir p all: true

		curDir = sysInfo.currentDir
		sysInfo.currentDir = this.selfPath

		local cmd = exe + " -i \"" + f + "\" -o \"" + ff + "\""

		hiddenDosCommand cmd exitcode:&exitcode

		sysInfo.currentDir = curDir

		local nn = this.convertImageTo ff type: #jpg

		this.optimizeImages files: #(nn)

		deleteFile f

		if (classOf t == Bitmaptexture) then (
			bt.filename = nn
			return bt
		)

		return Bitmaptexture filename: nn
	),

	fn addTextureToQueue t = (
		if (t == undefined) do return false
		if (classOf t == Bitmaptexture and t.filename != undefined and t.filename != "") do (
			local n = toLower (filenameFromPath t.filename)
			local id = findItem this.texturesQueueNames n

			-- To copy
			if (id == 0) then (
				append texturesQueue #(t)
				this.texturesQueueNames[this.texturesQueue.count] = n

				return true
			) else (
				return appendIfUnique this.texturesQueue[id] t
			)
		)

		-- To bake
		-- To bake map, cnt = 1, classOf not Bitmaptex
		return append this.texturesQueue #(t)
	),

	fn addNormalToQueue t = (
		if (t == undefined) do return false

		if (classOf t == CoronaNormal and t.normalMap != undefined) do (
			local b =  t.normalMap
			-- Kill CoronaNormal
			replaceInstances t b
			return this.addTextureToQueue b
		)

		-- To convert
		if (classOf t == Bitmaptexture and t.filename != undefined and t.filename != "") do (
			local n = toLower (filenameFromPath t.filename)
			local id = findItem this.normalsQueueNames n

			-- To convert to normal
			if (id == 0) then (
				append this.normalsQueue #(t)
				this.normalsQueueNames[this.normalsQueue.count] = n

				return true
			) else (
				return appendIfUnique this.normalsQueue[id] t
			)
		)

		-- To bake map and convert to normal, cnt = 1, classOf not Bitmaptex
		return appendIfUnique normalsQueue #(t)
	),

	fn renderNormalsQueue = (
		for t in this.normalsQueue do (
			if (classOf t[1] == Bitmaptexture) then (
				local n = this.convertBumpToNormal t[1]
				for i in t where n != false do replaceInstances i n
			) else (
				local n = this.convertBumpToNormal t[1]
				if (n != undefined and n != false) do replaceInstances t[1] n
			)
		)
	),

	fn renderTexturesQueue = (
		for t in this.texturesQueue do (
			if (classOf t[1] == Bitmaptexture) then (
				local b = cacheBitmap t[1]
				for i in t where i != undefined and b != undefined do replaceInstances i b
			) else if (t[1] != undefined) then (
				this.renderTargetMap t[1] isReplace: true type: #jpg
			)
		)
	),

	fn getMaterialsWithFalloff = (
		local o = #()
		for i in getClassInstances CoronaPhysicalMtl where i.baseTexmap != undefined do (
			for ii in getClassInstances Falloff target: i.baseTexmap do (
				append o i
				exit
			)
		)
		return o
	),

	fn neutralizeMeshSmooth = (
		local a = #()
		for i in getClassInstances MeshSmooth do appendIfUnique a i
		for i in getClassInstances TurboSmooth do appendIfUnique a i

		for i in a do (
			if (i.renderIterations > i.iterations) do i.iterations = i.renderIterations
			try (i.isolineDisplay = false) catch ()
		)
	),

	fn neutralizeRaySwitch = (
		for i in getClassInstances CoronaRaySwitchMtl do (
			if (classOf i.giMtl == CoronaPhysicalMtl and i.giMtl.baseTexmap == undefined) then (
				if (i.directMtl != undefined) then (
					replaceInstances i i.directMtl
				) else if (i.reflectMtl != undefined) then (
					replaceInstances i i.reflectMtl
				) else if (i.refractMtl != undefined) then (
					replaceInstances i i.refractMtl
				) else (
					replaceInstances i i.giMtl
				)
			) else if (i.giMtl != undefined) do (
				replaceInstances i i.giMtl
			)
		)
	),

	fn replaceToBlackEmptyBitmap = (
		for i in getClassInstances Bitmaptexture do (
			if (i.filename != undefined and i.filename != "") do continue
			local f = this.generateCacheFilename()
			local b = bitmap 128 128 color: (color 5 5 5)
			b.filename = f
			save b
			close b

			i.filename = f
		)
	),

	fn neutralizeCoronaMix = (
		for i in getClassInstances CoronaMix do (
			local nm = Mix()
			nm.name = i.name + "_" + (random 1000 10000) as string

			nm.mixAmount = i.mixAmount * 100.0
			nm.mask = i.texmapMix

			nm.color1 = i.colorTop
			nm.color2 = i.colorBottom

			nm.map1 = i.texmapTop
			nm.map2 = i.texmapBottom

			replaceInstances i nm
		)
	),

	/* fn neutralizeFalloff = (
		for i in getClassInstances Falloff do (
			local nm = Mix()
			nm.name = i.name

			nm.mixAmount = 50.0

			nm.color1 = i.color1
			nm.color2 = i.color2

			nm.map1 = i.map1
			nm.map2 = i.map2

			if (classOf i.map1 == Bitmaptexture) do (
				return replaceInstances i i.map1
			)
			if (nm.map2 == undefined) do nm.map2 = nm.map1

			replaceInstances i nm
		)
	), */

	fn neutralizeFalloff = (
		for f in getClassInstances Falloff do (
			for m in getDependents f do (
				local id = getRefSlotId m f
				if (id == undefined) do continue

				local nm = f.map1
				if (nm == undefined) do nm = f.map2

				setSubTexmap m id nm
			)
		)
	),

	fn neutralizeDoubleSided = (
		for i in getClassInstances doubleSided do (
			local nm = i.material1
			nm.name = i.name

			replaceInstances i nm
		)
	),

	fn neutralizeNoise = (
		for i in getClassInstances Noise do (
			i.color1 = gray
			i.color2 = gray
		)
	),

	fn neutralizeCoronaSkinMtl = (
		for i in getClassInstances CoronaSkinMtl do (
			local nm = CoronaPhysicalMtl()
			nm.name = i.name
			nm.baseColor = i.skinColor
			nm.baseTexmap = i.texmapSkinColor
			nm.baseRoughness = 1.0 - i.reflection1Glossiness
			nm.baseIor = i.reflection1Ior

			replaceInstances i nm
		)
	),

	fn neutralizeCoronaLayered = (
		for i in getClassInstances CoronaLayeredMtl do (
			local nm = i.baseMtl
			nm.name = i.name

			replaceInstances i nm
		)
	),

	fn neutralizeBlendMtl = (
		for i in getClassInstances Blend do (
			local nm = i.map1
			nm.name = i.name

			replaceInstances i nm
		)
	),

	fn neutralizeCoronaAO = (
		for i in getClassInstances CoronaAO do (
			i.texmapOccluded = i.texmapUnoccluded
			i.colorOccluded = color 128 128 128
			i.colorUnoccluded = i.colorOccluded
		)
	),

	fn setVrayMtlFogColorToDiffuse = (
		for i in getClassInstances VRayMtl do (
			if (i.refraction_fogColor == white) do continue
			if (i.Refraction == black) do continue

			i.Diffuse = i.refraction_fogColor
		)
	),

	fn enableGammaCoronaNormal= (
		for i in getClassInstances CoronaNormal do (
			i.addGamma = true
		)
	),

	fn normalizeRealWorldUVWbyTiling = (
		for o in objects do (
			if (not isValidNode o or isDeleted o or not (canConvertTo o Editable_Mesh) or classOf o.material == undefined) do continue

			global normalizeBitmaps = #()
			global normalizeValues = #()
			global normalizeOffsets = #()

			fn normalizeMaterialTiling m o id = (
				local bb = getClassInstances Bitmaptexture target: m
				if (bb.count == 0) do continue
				local isRealWorld = try(bb[1].coords.realWorldScale == true) catch (false)

				try (bb[1].coords.realWorldScale = false) catch ()
				local u = bb[1].coords.U_Tiling as float
				local v = bb[1].coords.V_Tiling as float
				local uOffset = bb[1].coords.U_Offset as float
				local vOffset = bb[1].coords.V_Offset as float

				if (u == 1.0 and v == 1.0) do continue

				local moVolSelect = Vol__Select()
				moVolSelect.level = 2
				moVolSelect.volume = 5
				moVolSelect.matID = id
				addModifier o moVolSelect

				local modUvwXForm = UVW_Xform()
				modUvwXForm.U_Tile = u
				modUvwXForm.V_Tile = v
				modUvwXForm.U_Offset = uOffset
				modUvwXForm.V_Offset = vOffset
				addModifier o modUvwXForm

				for b in bb do (
					try (b.coords.realWorldScale = false) catch ()

					if (appendifUnique normalizeBitmaps b) do (
						local _u = b.coords.U_Tiling / u
						local _v = b.coords.V_Tiling / v
						local _uOffset = b.coords.U_Offset - uOffset
						local _vOffset = b.coords.V_Offset - vOffset

						append normalizeValues #(_u, _v)
						append normalizeOffsets #(_uOffset, _vOffset)
					)

					--b.coords.U_Tiling = b.coords.U_Tiling / u
					--b.coords.V_Tiling = b.coords.V_Tiling / v
				)
			)

			if (classOf o.material == Multimaterial) then (
				for id in o.material.materialIDList do (
					local m = o.material.materialList[id]
					if (m == undefined) do continue

					normalizeMaterialTiling m o id
				)
			) else (
				normalizeMaterialTiling o.material o 1
			)

			for i in 1 to normalizeBitmaps.count do (
				local b = normalizeBitmaps[i]
				b.coords.U_Tiling = normalizeValues[i][1]
				b.coords.V_Tiling = normalizeValues[i][2]
				b.coords.U_Offset = normalizeOffsets[i][1]
				b.coords.V_Offset = normalizeOffsets[i][2]
			)

			convertToMesh o
		)
	),

	fn coronaLightMtlToGltfMaterial = (
		for i in getClassInstances CoronaLightMtl do (
			local nm = glTFMaterial()
			nm.name = i.name

			nm.emissionColor = i.color
			nm.emissionMap = i.texmap
			if (i.opacityTexmap != undefined) do (
				nm.AlphaMap = i.opacityTexmap
				this.addTextureToQueue nm.AlphaMap
				nm.alphaMode = 2
			)

			replaceInstances i nm
		)
	),

	fn clampColor c = (
		if (c == black) do return color 6 6 6
		if (c == white) do return color 248 248 248
		return c
	),

	fn isGlass i = (
		if (i.refractionAmount >= 0.75 and i.baseRoughness < 0.5) do return true
		if (MatchPattern i.name pattern: "*glass*") do return true
		return false
	),

	fn coronaPhysicalMtlToGltfMaterial falloffMaterials: #() = (
		for i in getClassInstances CoronaPhysicalMtl do (
			i.roughnessMode = 0
			local nm = glTFMaterial()
			nm.name = i.name
			nm.DoubleSided = false

			local isUsedFalloff = (findItem falloffMaterials i) != 0
			local preset = #none

			if (isUsedFalloff) do preset = #cloth
			if (this.isGlass i) do preset = #glass

			-- Diffuse
			if (i.baseTexmap != undefined) then (
				nm.baseColorMap = i.baseTexmap
				this.addTextureToQueue nm.baseColorMap

				if (i.baseLevel != 1.0) do (
					local c = i.baseLevel * 255.0
					nm.baseColor = color c c c
					nm.baseColor = this.clampColor nm.baseColor
				)
			) else (
				nm.baseColor = this.clampColor i.basecolor
			)

			-- Roughness
			nm.roughness = if (i.roughnessMode == 1) then (1.0 - i.baseRoughness) else (i.baseRoughness)
			if (i.baseRoughnessTexmap != undefined) then (
				nm.roughnessMap = i.baseRoughnessTexmap
				this.addTextureToQueue nm.roughnessMap

				if (nm.roughness == 1) do nm.roughness = 0.75
			) else if (isUsedFalloff and nm.roughness == 0) do (
				nm.roughness = 0.75
			)

			-- Opacity
			if (i.opacityTexmap != undefined) do (
				-- Force bake Alpha (Tiling not supported)
				local cc = Color_Correction()
				-- Invert
				--cc.rewireMode = 2
				cc.map = i.opacityTexmap
				nm.AlphaMap = cc
				this.addTextureToQueue cc
				nm.alphaMode = 2
			)

			local clampNormalMap = 0.2

			-- Bump
			nm.normal = i.baseBumpMapAmount
			if (nm.normal > clampNormalMap) do nm.normal = clampNormalMap
			if (i.baseBumpTexmap != undefined) do (
				nm.normalMap = copy i.baseBumpTexmap
				this.addNormalToQueue nm.normalMap
			)

			-- Displace
			if (i.displacementTexmap != undefined) do (
				nm.normalMap = copy i.displacementTexmap
				this.addNormalToQueue nm.normalMap
				nm.normal = clampNormalMap
			)

			-- Metalness
			nm.metalness_map = i.metalnessTexmap
			this.addTextureToQueue nm.metalness_map

			if (i.metalnessMode == 1) do (
				nm.metalness = 1
			)

			-- IOR
			nm.enableIndexOfRefraction = true
			nm.indexOfRefraction = i.baseIor
			if (i.baseIor < 1.1) do nm.roughness = 1.0

			-- Self Illumination
			if (i.selfIllumLevel != 0) do (
				nm.emissionColor = i.selfIllumColor
				nm.emissionMap = i.selfIllumTexmap
				this.addTextureToQueue nm.emissionMap
			)

			-- Refraction
			if (i.refractionAmountTexmap != undefined) then (
				nm.AlphaMap = i.refractionAmountTexmap
				this.addTextureToQueue nm.AlphaMap
				nm.alphaMode = 3
			) else if (i.refractionAmount != 0) do (
				local c = (1.0 - i.refractionAmount) * 255.0

				-- Clamp black color
				if (c < 30) do c = 30

				nm.AlphaMap = ColorMap()
				nm.AlphaMap.solidcolor = color c c c
				nm.alphaMode = 3

				this.addTextureToQueue nm.AlphaMap
			)

			-- Clearcoat
			if (i.clearcoatAmount != 0) do (
				nm.enableClearCoat = true
				nm.clearcoat = i.clearcoatAmount
				nm.clearcoatMap = i.clearcoatAmountTexmap
				this.addTextureToQueue nm.clearcoatMap

				nm.clearcoatNormal = i.clearcoatBumpMapAmount
				nm.clearcoatNormalMap = copy i.clearcoatBumpTexmap
				addNormalToQueue nm.clearcoatNormalMap

				nm.clearcoatRoughness = i.clearcoatRoughness
				nm.clearcoatRoughnessMap = i.clearcoatRoughnessTexmap
				this.addTextureToQueue nm.clearcoatRoughnessMap
			)

			-- Sheen
			if (i.sheenAmount != 0) then (
				nm.enableSheen = true
				nm.sheenColor = i.sheenColor
				nm.sheenRoughness = i.sheenRoughness
				nm.sheenColorMap = i.sheenColorTexmap
				this.addTextureToQueue nm.sheenColorMap

				nm.sheenRoughnessMap = i.sheenRoughnessTexmap
				this.addTextureToQueue nm.sheenRoughnessMap
			)

			-- Force Clamp Roughness
			if (nm.roughness > 0.75) do nm.roughness = 0.75

			-- Force set prams for specific presets
			if (preset == #cloth) do (
				nm.normal = 0.25

				if (i.sheenAmount != 0) do (
					nm.enableSheen = true
					nm.sheenRoughness = 0.3
					nm.sheenColor = color 65 65 65
					nm.metalness = 0
				)
			)

			if (preset == #glass) do (
				nm.roughness = 0.15
				nm.DoubleSided = true
				nm.enableClearCoat = true
				nm.clearcoat = 1
				nm.clearcoatRoughness = 1
				nm.enableSheen = true
				nm.sheenRoughness = 0.3
				nm.sheenColor = color 255 255 255 255
				nm.indexOfRefraction = 20
				nm.AlphaMap = ColorMap()
				nm.AlphaMap.solidcolor = color 110 110 110
				nm.alphaMode = 3

				this.addTextureToQueue nm.AlphaMap
			)


			-- Replacement
			replaceInstances i nm
		)
	),

	fn convertToCorona = (
		::CoronaConverterSuppressGui = true
		::CoronaConverter
		local ff = getFiles (@"c:\Program Files\Corona\Corona Renderer for 3ds Max\" + getCurrentMaxVersion() + @"\Scripts\coronaConverter*.ms")
		try (fileIn ff[1]) catch ()

		::CoronaConverter.converterTools.convertCoronaBitmapToBitmap()
		::CoronaConverter.converterSettings.convertCoronaLegacyMtl = true
		::CoronaConverter.CoronaConverterRoll.convertCoronaLegacyMtlCheckbox.checked = true

		::CoronaConverter.convertScene()

		::CoronaConverterSuppressGui = false
	),

	fn autoUnwrap obj = (
		with redraw off with undo off (
			select obj
			max hierarchy mode
			modPanel.addModToSelection (Unwrap_UVW ()) ui:on
			subobjectLevel = 3
			local uvw =  obj.modifiers[1]
			uvw.setMapChannel 2
			uvw.setApplyToWholeObject true
			max modify mode
			subobjectLevel = 3
			max select all

			/*ss = #{}
			for i in 1 to uvw.numberPolygons() do append ss i
			uvw.selectPolygons ss*/

			uvw.flattenMap 50 #([1,0,0], [-1,0,0], [0,1,0], [0,-1,0], [0,0,1], [0,0,-1]) 0.0085 true 2 true true
			uvw.unwrap4.setThickOpenEdges false

			max select none
			subobjectLevel = 0
			convertToMesh obj
		)
	),

	fn attachObjectsByMaterials = (
		local mats = #()
		for i in objects where this.isValidObject i do appendIfUnique mats i.material

		local objsByMats = #()
		for i in 1 to mats.count do (
			objsByMats[i] = for o in objects where this.isValidObject o and o.material == mats[i] collect o
		)

		for oo in objsByMats where oo.count > 1 do (
			convertToPoly oo[1]
			for i in oo.count to 2 by -1 do (
				polyop.attach oo[1] oo[i]
				deleteItem oo i
			)
		)

		return for i in objsByMats collect i[1]
	),

	fn getDenoisedImage f = (
		local p = getFilenamePath f
		local n = getFilenameFile  f
		local ext = getFilenameType f
		local d = getFiles (p + n + "_denoised*" + ext)
		if (d[1] == undefined or not doesFileExist d[1]) do return f
		return d[1]
	),

	fn denoiseImage f = (
		local v = getCurrentMaxVersion()

		local args = v + ";" + f
		args = substituteString args "/" @"\"

		local cmd = "denoise.bat \"" +  args + "\""

		local curDir = sysInfo.currentDir
		sysInfo.currentDir = this.selfPath

		hiddenDosCommand cmd exitCode: &exitcode donotwait: false

		sysInfo.currentDir = curDir
	),

	fn bakeCoronaAO obj filename ao: undefined = (
		if (ao == undefined) do return false

		try (convertToMesh obj) catch ()
		max tool zoomextents
		max views redraw
		clearSelection()
		select obj

		local originalMaterial = obj.material

		local p = getFilenamePath filename
		local n = getFilenameFile filename
		local ext = getFilenameType filename

		makeDir p all: true

		renderers.current = Corona()
		local r = renderers.current

		local tmp_PassesLimit = r.progressive_passLimit
		r.progressive_passLimit = ao.passes
		r.denoise_filterType = 4
		r.denoise_blendAmount = 1.0
		r.shading_onlyElements = true
		renderSceneDialog.commit()
		renderSceneDialog.update()

		local m = CoronaPhysicalMtl()
		m.baseColor = white
		m.baseRoughness = 1.0
		local cao = CoronaAO()
		cao.maxDistance = units.decodeValue ao.size
		cao.colorSpread = 0.022
		cao.Quality = 64
		cao.normalMode = 0
		cao.rayDirectionality = 0.03
		--cao.occlusionFrom = 3
		m.baseTexmap = cao
		obj.material = m

		obj.iNodeBakeProperties.removeAllBakeElements()
		local be = Corona_DiffuseColor()
		be.outputSzX = be.outputSzY = ao.resolution
		be.fileType = "jpg"
		be.filename = filename
		be.enabled = true
		be.filter = true
		obj.INodeBakeProperties.addBakeElement be
		obj.INodeBakeProperties.bakeEnabled = true
		obj.INodeBakeProperties.bakeChannel = 2
		obj.INodeBakeProperties.nDilations = 2
		select obj

		render rendertype:#bakeSelected vfb: true progressBar:true outputSize:[ao.resolution, ao.resolution] vfb: false

		this.optimizeImages files: #(filename)

		if (ao.denoise) do denoiseImage filename

		obj.material = originalMaterial
		r.progressive_passLimit = tmp_PassesLimit
	),

	fn getXNormal = (
		local p = @"c:\Program Files\xNormal\"
		if (not doesDirectoryExist p) do return undefined
		local dd = getDirectories (p + "*")
		local d = dd[dd.count]
		if (d == undefined) do return undefined

		local f = d + @"x64\xNormal.exe"
		if (not doesFileExist f) do return undefined

		return f
	),

	fn xNomralCmd fbx jpg size = (
		local selfPath = getFileNamePath (getThisScriptFileName())

		local curDir = sysInfo.currentDir
		sysInfo.currentDir = selfPath

		local xNormal = this.getXNormal()
		if (xNormal == undefined) do return false

		local args = xNormal + ";" + fbx + ";" + jpg + ";" + size
		local cmd = "xnormal.bat \"" +  args + "\""

		hiddenDosCommand cmd exitcode:&exitcode

		sysInfo.currentDir = curDir
	),

	fn bakeXNormalAO obj filename ao: undefined = (
		if (ao == undefined) do return false

		local denoise = ao.denoise
		local res = ao.resolution as string

		local p = getFilenamePath filename
		local n = getFilenameFile filename
		local ext = getFilenameType filename

		deleteFile filename
		makeDir p all: true

		local clone = snapshot obj

		channelInfo.CopyChannel clone 3 2
		channelInfo.PasteChannel clone 3 1

		select clone

		FbxImporterSetParam "Cameras" false
		FbxImporterSetParam "Lights" false
		FbxImporterSetParam "Animation" false
		FbxExporterSetParam "EmbedTextures" false
		FbxExporterSetParam "SmoothingGroups" true

		local nn = "__tmpBakeAO_Mesh_" + (timeStamp() as string) + ".fbx"
		local f = p + nn

		exportFile f #noPrompt selectedOnly: true
		local generatedFile = p + n + "_cavity" + ext
		deleteFile generatedFile

		this.xNomralCmd f filename res

		renameFile generatedFile filename

		delete clone
		deleteFile f

		this.optimizeImages files: #(filename)
		if (ao.denoise) do denoiseImage filename
	),

	fn setAOmap obj f = (
		if (f == "" or not doesFileExist f) do return false

		local d = getDenoisedImage f
		if (d != undefined) do f = d

		local b = Bitmaptexture()
		b.filename = f
		b.coords.mapChannel = 2
		b.name = "AO"

		for i in getClassInstances glTFMaterial target: obj.material do (
			i.ambientOcclusionMap = b
		)
	),

	fn createAOmap ao: undefined = (
		max unhide all
		local oo = geometry as array
		for o in oo where this.isValidObject o do (
			local n = o.material.name
			o.material = copy o.material
			o.material.name = n

			local f = this.generateCacheFilename()

			this.autoUnwrap o
			if (ao.type == #corona) do (
				this.bakeCoronaAO o f ao: ao
				this.setAOmap o f
			)

			if (ao.type == #xnormal) do (
				this.bakeXNormalAO o f ao: ao
				this.setAOmap o f
			)
		)
	),

	fn rmDir d = (
		local cmd = "timeout /t 5 /nobreak & rmdir /S /Q \"" + d + "\""
		HiddenDOSCommand cmd donotwait: true
	),

	fn saveGLBScene = (
		local p = getSceneDir()
		saveMaxFile (p + "GLB.max") quiet: true
	),

	fn packGLTF i o o2 = (
		local args = i + ";" + o + ";" + o2
		args = substituteString args "/" @"\"

		local cmd = "gltfpack.bat \"" +  args + "\""

		local curDir = sysInfo.currentDir
		sysInfo.currentDir = this.selfPath

		hiddenDosCommand cmd exitCode: &exitcode donotwait: false

		sysInfo.currentDir = curDir

		for p in this.getUnusedDirs() do rmDir p
	),

	fn exportGLB p n: undefined = (
		ATSOps.Refresh()
		select geometry
		try (unhide selection doLayer: true) catch ()
		if (n == undefined) do n = this.getSceneName()
		local pp = p + n + @"\"
		makeDir pp all: true
		local i = pp + n + ".gltf"
		local o = p + n + ".glb"
		local o2 = p + n + "-WEBGL.glb"
		local preview = p + n + ".png"

		deleteFile o
		deleteFile o2
		exportFile i #noPrompt selectedOnly: true
		deleteFile (i + ".log")

		packGLTF i o o2

		-- JSON: Filename
		this.j.addData this.json "version" (getCurrentMaxVersion())
		this.j.addData this.json "name" (n + ".glb")
		-- JSON: Scenename
		this.j.addData this.json "scene" maxFileName

		-- Web Preview
		w.run()
		w.makeBrowserScreenshot	o preview

		return o
		-- Remove ktx2
		--for i in getFiles (glbFolder + "*.ktx2") do deleteFile i
	),

	fn removeExtraObjects = (
		try (delete lights) catch ()
		try (delete cameras) catch ()
		if (VRayFur != undefined) do (
			local vv = for i in objects where classOf i == VRayFur collect i
			try (delete vv) catch ()
		)
	),

	fn getFileMb f = (
		if (not doesFileExist f) do return 0.0
		s = (getFileSize f) / 1048576.0
		return ((s * 100) as integer) / 100.0
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

	fn getMaterialsCnt = (
		if (glTFMaterial == undefined) do return 0
		local cc = 0

		for o in objects do (
			local c = (getClassInstances glTFMaterial target: o).count
			cc += c
		)

		return cc
	),

	fn run out: "" scn: undefined ao: undefined isNormalizeTiling: false = (
		this.json = #()
		SetQuietMode true
		/*
			@Input
			ao = AO_Settings (enabled, passes, resolution, denoise, size)
			scn = scn (file, path, name, ext, type, del, opened, maxName)
		*/

		if (ao == undefined or scn == undefined) do return false
		this.convertexe = deployConvertExe()
		ATSOps.Refresh()

		this.outPath = out
		this.texturesQueueNames = #()
		this.normalsQueueNames = #()
		this.texturesQueue = #()
		this.normalsQueue = #()

		-- Normalize Mesh
		this.ungroupRecursive()
		this.removeExtraObjects()
		this.neutralizeMeshSmooth()
		this.fixGeometry()
		this.attachObjectsByMaterials()

		-- Save Fog color before conversion to Corona
		this.setVrayMtlFogColorToDiffuse()

		-- Purge cache
		this.clearCacheMapsDir()

		-- @@ Convert all to Corona Physical Mtl
		this.convertToCorona()

		-- Bitmap instansing
		this.instnceDuplicateMaps()

		local falloffMaterials = this.getMaterialsWithFalloff()

		-- Simplify maps
		this.enableGammaCoronaNormal()
		this.neutralizeFalloff()
		this.neutralizeCoronaAO()
		this.neutralizeRaySwitch()
		this.neutralizeCoronaSkinMtl()
		this.neutralizeCoronaLayered()
		this.neutralizeNoise()
		this.neutralizeBlendMtl()
		this.neutralizeDoubleSided()
		this.neutralizeCoronaMix()

		-- Convert to GLTF Material
		this.coronaPhysicalMtlToGltfMaterial falloffMaterials: falloffMaterials
		this.coronaLightMtlToGltfMaterial()

		-- Tiling to proper mapping	(Kill Tiling)
		if (isNormalizeTiling) do normalizeRealWorldUVWbyTiling()

		-- Empty maps to Black!
		replaceToBlackEmptyBitmap()

		-- Render Maps
		this.renderTexturesQueue()
		this.renderNormalsQueue()

		if (ao.enabled) do this.createAOmap ao: ao

		local o = this.exportGLB out n: scn.name

		-- JSON: Data
		local glbPolys = polyCount objects
		local glbSize = getFileMb o

		this.j.addData this.json "program" "glb"
		this.j.addData this.json "ao" ao.enabled
		this.j.addData this.json "aoType" ao.type
		this.j.addData this.json "sizeMb" glbSize
		this.j.addData this.json "polys" glbPolys[1]
		this.j.addData this.json "verts" glbPolys[2]
		this.j.addData this.json "size" (getDim objects)
		this.j.addData this.json "units" (getUnits())
		this.j.addData this.json "objectsCount" (objects.count)
		this.j.addData this.json "materialsCount" (getMaterialsCnt())

		-- Write JSON
		local jsonFile = out + scn.name + ".json"
		this.j.writeJson jsonFile this.json

		this.saveGLBScene()

		if (scn.del != undefined) do rmDir scn.del

		SetQuietMode false

		return o
	),

	fn extractZip f o = (
        if (f == undefined or not doesFileExist f) do return false
        if (getFilenameType f != ".zip") do return false

		local args = f + ";" + o
		args = substituteString args "/" @"\"

		local cmd = "start /b /min /wait extract.bat \"" +  args + "\""

		local curDir = sysInfo.currentDir
		sysInfo.currentDir = this.selfPath

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

	fn enableBackFaceCull = (
		for i in objects do try (i.backfacecull = true) catch ()
	),

	fn setMapsVisible = (
		local classes = #(
			CoronaPhysicalMtl,
			CoronaLegacyMtl,
			VRayMtl
		)

		for c in classes where c != undefined do (
			for i in getClassinstances c do (
				try (showTextureMap i true) catch ()
			)
		)
	),

	fn unfreezeAll = (
		for i in objects do try (i.isFrozen = false) catch ()
	),

	fn unhideAll = (
		for i in objects do try (i.isHidden = false) catch ()
	),

	fn explodeAllGroups = (
		local gg = for o in objects where isGroupHead o collect o
		for g in gg do try (explodeGroup g) catch ()
	),

	fn disableIsolineDisplayForSmooth = (
		for i in getClassInstances MeshSmooth do i.isolineDisplay = false
		for i in getClassInstances TurboSmooth do i.isolineDisplay = false
	),

	fn load f = (
		sleep 0.1
		try (resetMaxFile #noprompt) catch ()

		struct scn (file, path, name, ext, type, del, opened, maxName)
		local r = scn()

		SetQuietMode true
		local ext = getFilenameType f
		local p = getFilenamePath f
		local n = getFilenameFile f
		local nn = filenameFromPath f

		r.file = f
		r.path = p
		r.name = n
		r.ext = ext
		r.del = undefined
		r.opened = false

		-- For Max files
		if (ext == ".max") do (
			loadMaxFile f quiet: true
			r.type = #max
			r.opened = maxFileName == nn
			r.maxName = nn

			return r
		)

		-- For archives
		local o = p + n + @"\"
		extractZip f o

		r.type = #zip
		r.del = o

		local m = getMaxFile o

		if (m == undefined) do (
			SetQuietMode false
			return r
		)

		nn = filenameFromPath m
		r.maxName = nn

		loadMaxFile m quiet: true
		SetQuietMode false
		r.opened = maxFileName == nn

		max tool zoomextents
		max tool maximize
		unfreezeAll()
		unhideAll()
		enableBackFaceCull()
		--setMapsVisible()
		max views redraw

		return r
	)
)

global API_BATCH_GLB_CONVERTER = BatchGLBConverterWrapper()


global _rGCAutoGLBConverter_Main = undefined
global _rGCAutoGLBConverter_Settings = undefined
global _rGCAutoGLBConverter_About = undefined

try(closeRolloutFloater _fGCAutoGLBConverter) catch()
global _fGCAutoGLBConverter = newRolloutFloater "" 300 460


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

rollout _rGCAutoGLBConverter_Main "Main" category: 1 (
	global _MAX_ALLOWED_POLYS = 250000

	local maxProcessFilesInSession = 20 --20 files in a row
	local onstartDelay = 20 --sec
	local restartProgramInterval = 60
	local restartReadQueue = 1 -- min !!!!! 5
	local nextProcess = 10 -- sec

	local jsonReaderMgr = JsonReaderWrapper()
	local startupScript = (getDir #userStartupScripts) + @"\AUTO_CONVERTER_GLB_STARTUP.ms"

	local countdownNextProcess = nextProcess
	local countdownBeforeStart = onstartDelay
	local countdownMaxRestart = 60 -- sec
	local countdownQueueRestart = restartReadQueue
	local processedFilesInSession = 0
	local apiQueueFailureCount = 0
	local apiQueueTelegramAlertSent = false
	local processTelegramLogs = #()

	group "Working Path" (
		edittext edtInputPath "" readonly: true across: 2 align: #left fieldwidth: 215 height: 22
		button btnSearchInputPath "..." width: 35 height: 24  align: #right offset: [0, -1]
	)

	group "Mode" (
		checkbutton cbxModeProd "Production" across: 2 highlightColor: (color 52 168 83) width: 122
		checkbutton cbxModeTest "Testing" highlightColor: (color 186 169 55) width: 122
	)

	group "Additional Conversion" (
		checkbox cbxConvertToBlend "Convert to BLEND"
		checkbox cbxConvertToSketchup "Convert to SKP"
	)

	group "Settings" (
		checkbox cbxBakeCoronaAO "Bake Corona AO"
		checkbox cbxRunListenerErrorObserver "Run Listener Error Observer"
	)

	progressBar pbProgress "" height: 9 color: (color 52 168 83) value: 0 offset: [0, 5]
	label lblSlug "--"  align: #left
	label lblStatus "" align: #left offset: [0, 5]
	checkbutton btnStartStartupProcess "Autostart and Process" width: 260 height: 32 enabled: false highlightColor: (color 52 168 83)

	timer tmrOnStartDelay active: false interval: (onstartDelay * 1000)
	timer tmrQueueRestart active: false interval: (restartReadQueue * 60 * 1000)
	timer tmrNextProcess active: false interval: (nextProcess * 1000)

	timer tmrCounterBeforeStart active: false interval: 1000
	timer tmrCounteRestart active: false interval: (restartProgramInterval * 1000)
	timer tmrCounterMaxRestart active: false interval: 1000
	timer tmrCounterQueueRestart active: false interval: 1000
	timer tmrCounterNextProcess active: false interval: 1000

	fn writeFile f s = (
		local f = createFile f mode: "wt"

		format(s as string) to:f

		flush f
		close f
	)

	fn loadSettings = (
		local p1 = '*'.get "edtInputPath"
		if (p1 != "" and doesDirectoryExist p1) do edtInputPath.text = p1

		btnStartStartupProcess.enabled = edtInputPath.text != ""

		local n = '*'.get "cbxConvertToBlend"
		cbxConvertToBlend.checked = n != "false"

		local a = '*'.get "cbxConvertToSketchup"
		cbxConvertToSketchup.checked = a != "false"

		local ao = '*'.get "cbxBakeCoronaAO"
		cbxBakeCoronaAO.checked = ao != "false"

		local p2 = '*'.get "cbxRunListenerErrorObserver"
		cbxRunListenerErrorObserver.checked = p2 != "false"

		watchdogMgr.saveTimeout()
	)

	fn setMode mode: #prod = (
		if (mode == #test) then (
			cbxModeProd.checked = false
			cbxModeTest.checked = true
			'*'.add "mode" "2"
		) else (
			cbxModeProd.checked = true
			cbxModeTest.checked = false
			'*'.add "mode" "1"
			mode = #prod
		)

		applyCredentialProfile mode
		return mode
	)

	fn updateMode = (
		return setMode mode: (getCredentialsMode())
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
		local d = '*'.get "edtInputPath"
		local p = getSavePath initialDir: d

		if (p == undefined) do return false
		p += @"\"

		edtInputPath.text = p
		'*'.add "edtInputPath" p

		loadSettings()
	)

	fn warnAboutNecessaryOptions = (
		local opts = #(
			cbxConvertToBlend,
			cbxConvertToSketchup,
			cbxBakeCoronaAO
		)

		local anyDisabled = false
		for i in opts where not i.checked do anyDisabled = true

		if (not anyDisabled or getCredentialsMode() != #prod) do return false

		local m = "For Production mode, it is strongly recommended to enable the following options:\n\n"
		for i in 1 to opts.count where not opts[i].checked do m += (i as string) + ". " + opts[i].caption + "\n"
		messageBox m title: "Warning!"

		return true
	)

	fn statusMessageNextProcess create: false dispose: false = (
		if (countdownNextProcess <= 0 or dispose) do (
			tmrCounterNextProcess.active = false
			return false
		)

		countdownNextProcess -= 1
		if (create) do (
			tmrCounterNextProcess.active = false
			tmrCounterNextProcess.active = true
			countdownNextProcess = nextProcess
		)

		lblStatus.caption = "Done. Taking the next file in " + (countdownNextProcess as string) + " seconds..."
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
			countdownMaxRestart = restartProgramInterval
			tmrCounterMaxRestart.active = false
			tmrCounterMaxRestart.active = true
		)

		local m = (countdownMaxRestart / 60) as string
		local s = (mod countdownMaxRestart 60) as string
		if (s.count < 2) do s = "0" + s

		local timeMin = m + ":" + s
		local f = if (m == "0") then "sec" else "min"

		lblStatus.caption = formatString "Restarting 3ds Max in $1 $2..." v: #(timeMin, f)
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
			countdownQueueRestart = restartReadQueue * 60

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

	fn restart3dsMax = (
		local maxExe = (pathConfig.GetDir #maxroot) + "3dsmax.exe"
		local args = maxExe + ";"
		local cmd = "restart.bat \"" + args + "\""
		local curDir = sysInfo.currentDir

		sysInfo.currentDir = currentPath
		hiddenDosCommand cmd donotwait: true
		sysInfo.currentDir = curDir
	)

	fn schedule3dsMaxRestartAfterProcessedLimit = (
		local msg = "Processed files limit reached (" + (processedFilesInSession as string) + " of " + (maxProcessFilesInSession as string) + "). Restarting 3ds Max..."
		print msg
		requestMgr.postLog txt: msg

		tmrNextProcess.active = false
		tmrQueueRestart.active = false
		tmrOnStartDelay.active = false

		statusMessageNextProcess dispose: true
		statusMessageRestartQueueIn dispose: true
		statusMessageRestartMaxIn create: true

		tmrCounteRestart.active = false
		tmrCounteRestart.active = true
	)

	fn getRemainingFilesInSession = (
		local remaining = maxProcessFilesInSession - processedFilesInSession
		if (remaining < 0) do remaining = 0
		return remaining
	)

	fn updateRemainingFilesLabel = (
		lblSlug.caption = "Files before restart: " + ((getRemainingFilesInSession()) as string) + " of " + (maxProcessFilesInSession as string)
	)

	fn shortenText txt maxLen: 1200 = (
		if (txt == undefined) do return ""
		txt = txt as string
		if (txt.count > maxLen) do txt = (substring txt 1 maxLen) + "..."
		return txt
	)

	fn sendApiQueueFailureTelegram response modeLabel = (
		if (apiQueueTelegramAlertSent) do return false

		apiQueueTelegramAlertSent = true

		local txt = "GC Autoconverter GLB API error\n\n"
		txt += "Mode: " + modeLabel + "\n"
		txt += "Queue API failed 3 times in a row.\n"
		txt += "URL: " + requestMgr.apiGetQueue + "\n\n"
		txt += "Response:\n" + (shortenText response)

		if (telegramMgr.checkCredentialsError()) do (
			print "[Telegram] API error alert was not sent: Telegram credentials are missing or invalid."
			return false
		)

		local image = (getFileNamePath (getThisScriptFileName())) + "api-error.jpg"
		local isOk = if (doesFileExist image) then (
			telegramMgr.sendPhoto txt image
		) else (
			telegramMgr.sendMessage txt
		)

		if (isOk) then (
			print "[Telegram] API error alert sent."
		) else (
			print ("[Telegram] API error alert failed: " + telegramMgr.getLastError())
		)

		return isOk
	)

	fn explodeAllGroups = (
		local gg = for o in objects where isGroupHead o collect o
		for g in gg do try (explodeGroup g) catch ()
	)

	fn disableIsolineDisplayForSmooth = (
		for i in getClassInstances MeshSmooth do i.isolineDisplay = false
		for i in getClassInstances TurboSmooth do i.isolineDisplay = false
	)

	fn resetXForAllObjects = (
		for o in geometry where isValidNode o and not isDeleted o do (
			ResetXForm o
			collapseStack o
		)
	)

	fn boxTrick = (
		local oo = geometry as array

		for o in oo where isValidNode o do (
			local b = convertToPoly (box())
			b.rotation = o.rotation
			b.name = o.name
			b.pos = o.pos
			b.wirecolor = o.wirecolor

			polyOp.deleteFaces b #{1..6}
			polyOp.attach b o
			convertToMesh b
		)
	)

	fn setSnenePivotBottom = (
		MaxOps.pivotMode = #pivotOnly

		local center = objects.center
		local bottom = objects.min.z

		for i in objects do (
			i.pivot = center
			i.pivot.z = bottom
			i.pos = [0, 0, 0]
		)

		MaxOps.pivotMode = #none
	)

	fn attachSceneObjects = (
		local objs = geometry as array
		if (objs.count < 2) do return false

		local base = objs[1]
		try (collapseStack base) catch ()
		try (convertToPoly base) catch ()
		base.parent = undefined

		for i in objs.count to 2 by -1 do (
			local o = objs[i]
			if (o == undefined or not isValidNode o) do continue
			try (convertToPoly o) catch ()
			o.parent = undefined
			try (polyop.attach base o) catch ()
		)

		CenterPivot base
		base.wirecolor = gray
		base.name = getFilenameFile maxFileName
	)

	fn checkExistingFiles ff = (
		local result = 0
		for f in ff do (
			if (doesFileExist f) do result += 1
		)

		return result
	)

	fn buildUploadedFilesResultJson uploadedFiles = (
		local glbFiles = #()
		local blendFiles = #()
		local skpFiles = #()
		local regex = dotNetClass "System.Text.RegularExpressions.Regex"

		for f in uploadedFiles do (
			local fileName = filenameFromPath f
			local lowerName = toLower (getFilenameFile fileName)

			if (regex.IsMatch lowerName "-glb(-[0-9]+)?(-webgl)?$") then (
				append glbFiles fileName
			) else if (regex.IsMatch lowerName "-blend(-[0-9]+)?$") then (
				append blendFiles fileName
			) else if (regex.IsMatch lowerName "-skp(-[0-9]+)?$") then (
				append skpFiles fileName
			)
		)

		local data = #()
		if (glbFiles.count > 0) do append data #("GLB", glbFiles)
		if (blendFiles.count > 0) do append data #("BLEND", blendFiles)
		if (skpFiles.count > 0) do append data #("SKP", skpFiles)

		return (JsonWrapper()).buildJson data
	)

	fn resetProcessTelegramLogs = (
		processTelegramLogs = #()
	)

	fn addProcessTelegramLog txt = (
		if (txt == undefined) do txt = ""
		append processTelegramLogs (txt as string)
	)

	fn postProcessLog txt = (
		addProcessTelegramLog txt
		requestMgr.postLog txt: txt
	)

	fn markProcessedFileInSession = (
		processedFilesInSession += 1
		updateRemainingFilesLabel()
		postProcessLog ("Processed files in this 3ds Max session: " + (processedFilesInSession as string) + " of " + (maxProcessFilesInSession as string) + ". Remaining before restart: " + ((getRemainingFilesInSession()) as string))
	)

	fn implodeLines lines maxChars: 3500 = (
		local result = ""

		for line in lines do (
			local nextLine = line as string
			if ((result.count + nextLine.count + 1) > maxChars) do exit
			if (result != "") do result += "\n"
			result += nextLine
		)

		if (lines.count > 0 and result == "") do result = substring (lines[1] as string) 1 maxChars
		return result
	)

	fn findFirstGLBScreenshot expectedExitFiles = (
		local regex = dotNetClass "System.Text.RegularExpressions.Regex"

		for f in expectedExitFiles do (
			local name = toLower (getFilenameFile f)
			if (toLower (getFilenameType f) == ".png" and regex.IsMatch name "-glb(-[0-9]+)?$" and doesFileExist f) do return f
		)

		for f in expectedExitFiles do (
			if (toLower (getFilenameType f) == ".png" and doesFileExist f) do return f
		)

		return ""
	)

	fn sendProcessingTelegramReport isSuccess slug sourceName expectedExitFiles uploadedFiles failedFiles resultJson errorMessage: "" = (
		if (telegramMgr.checkCredentialsError()) do (
			print "[Telegram] Processing report was not sent: Telegram credentials are missing or invalid."
			return false
		)

		local modeLabel = getCredentialsModeLabel (getCredentialsMode())
		local title = if (isSuccess) then "GC Autoconverter GLB: uploaded successfully" else "GC Autoconverter GLB: processing failed"
		local txt = title + "\n\n"
		txt += "Mode: " + modeLabel + "\n"
		txt += "Slug: " + slug + "\n"
		txt += "Original file: " + sourceName + "\n"
		txt += "Model ID: " + (requestMgr.model_id as string) + "\n"
		txt += "Version ID: " + (requestMgr.version_id as string) + "\n"
		txt += "Expected files: " + (expectedExitFiles.count as string) + "\n"
		txt += "Uploaded files: " + (uploadedFiles.count as string) + "\n"
		txt += "Failed files: " + (failedFiles.count as string) + "\n"

		if (errorMessage != "") do txt += "\nError:\n" + (shortenText errorMessage maxLen: 500) + "\n"
		if (resultJson != "") do txt += "\nResult JSON:\n" + (shortenText resultJson maxLen: 700) + "\n"

		txt += "\nUploaded:\n" + (shortenText (implodeString uploadedFiles) maxLen: 500) + "\n"
		if (failedFiles.count > 0) do txt += "\nFailed:\n" + (shortenText (implodeString failedFiles) maxLen: 500) + "\n"
		txt += "\nConversion log:\n" + (implodeLines processTelegramLogs maxChars: 2500)

		local image = if (isSuccess) then (
			findFirstGLBScreenshot expectedExitFiles
		) else (
			(getFileNamePath (getThisScriptFileName())) + "error.jpg"
		)

		local isPhotoSent = true
		local photoError = ""
		if (image != "" and doesFileExist image) do (
			isPhotoSent = telegramMgr.sendPhoto title image
			if (not isPhotoSent) do photoError = telegramMgr.getLastError()
		)

		local isMessageSent = telegramMgr.sendMessage txt
		local isSent = isPhotoSent and isMessageSent

		if (isSent) then (
			print "[Telegram] Processing report sent."
		) else (
			local err = telegramMgr.getLastError()
			if (photoError != "") do err = "Photo error: " + photoError + "\nMessage error: " + err
			print ("[Telegram] Processing report failed: " + err)
		)

		return isSent
	)

	fn failCurrentProcess slug sourceName message statusCaption: "" expectedExitFiles: #() uploadedFiles: #() failedFiles: #() = (
		local errorMessage = message
		if (findString errorMessage "[Error]" == undefined) do errorMessage = "[Error] " + errorMessage

		postProcessLog errorMessage
		watchdogMgr.beat stage: "posting_error"
		requestMgr.postStatus #error txt: message
		if (statusCaption == "") do statusCaption = message
		lblStatus.caption = statusCaption

		markProcessedFileInSession()
		sendProcessingTelegramReport false slug sourceName expectedExitFiles uploadedFiles failedFiles "" errorMessage: message
		watchdogMgr.clear()
		if (processedFilesInSession >= maxProcessFilesInSession) do (
			schedule3dsMaxRestartAfterProcessedLimit()
			return false
		)

		statusMessageNextProcess create: true
		tmrNextProcess.active = true
		return false
	)

	fn getGeometryLayerNames = (
		local names = #()

		for o in geometry where isValidNode o and not isDeleted o do (
			local layerName = try (o.layer.name as string) catch ("")
			if (layerName != "") do appendIfUnique names layerName
		)

		return names
	)

	fn getGeometryPolyStats nodes label: "" = (
		local polys = (utilsWrapper()).polyCount nodes
		return #(label, polys[1], polys[2], nodes.count)
	)

	fn getGeometryLayerPolyStats layerName = (
		local layerObjects = #()

		for o in geometry where isValidNode o and not isDeleted o do (
			local objectLayerName = try (o.layer.name as string) catch ("")
			if (objectLayerName == layerName) do append layerObjects o
		)

		return getGeometryPolyStats layerObjects label: layerName
	)

	fn formatPolyStats stat = (
		return stat[1] + " (" + (stat[2] as string) + " polys, " + (stat[4] as string) + " objects)"
	)

	fn formatPolyStatsList stats = (
		local items = #()
		for stat in stats do append items (formatPolyStats stat)
		return implodeString items
	)

	fn logLayerPolyStats layerNames = (
		postProcessLog ("Polygon limit per exported variant: " + (_MAX_ALLOWED_POLYS as string))

		for layerName in layerNames do (
			local stat = getGeometryLayerPolyStats layerName
			postProcessLog ("Layer polygon count: " + (formatPolyStats stat))
		)
	)

	fn getLayersOverPolyLimit layerNames = (
		local failed = #()

		for layerName in layerNames do (
			local stat = getGeometryLayerPolyStats layerName
			if (stat[2] > _MAX_ALLOWED_POLYS) do append failed stat
		)

		return failed
	)

	fn keepOnlyGeometryFromLayer layerName = (
		local nodesToDelete = #()

		for o in geometry where isValidNode o and not isDeleted o do (
			local objectLayerName = try (o.layer.name as string) catch ("")
			if (objectLayerName != layerName) do append nodesToDelete o
		)

		if (nodesToDelete.count > 0) do try (delete nodesToDelete) catch ()
		return (geometry as array).count
	)

	fn resetLoadedSceneState = (
		try (max unhide all) catch ()
		try (for o in objects do o.isFrozen = false) catch ()
		try (max views redraw) catch ()
	)

	fn convertSceneVariant scn glbName blendName skpName d ao blendGLBMgr skpMgr expectedExitFiles convertToBlend: undefined convertToSketchup: undefined postLogs: true = (
		if (convertToBlend == undefined) do convertToBlend = cbxConvertToBlend.checked
		if (convertToSketchup == undefined) do convertToSketchup = cbxConvertToSketchup.checked

		fn logMessage txt postLogs: true = (
			print txt
			addProcessTelegramLog txt
			if (postLogs) do requestMgr.postLog txt: txt
		)

		lblStatus.caption = "Preparing scene: BoxTrick, Attach All, Set Pivot..."
		watchdogMgr.beat stage: "preparing_scene"
		logMessage ("Preparing scene for conversion: " + glbName) postLogs: postLogs

		explodeAllGroups()
		disableIsolineDisplayForSmooth()
		boxTrick()
		resetXForAllObjects()
		attachSceneObjects()
		setSnenePivotBottom()

		scn.name = glbName

		join expectedExitFiles #(
			d + glbName + ".glb",
			d + glbName + ".png",
			d + glbName + ".json",
			d + glbName + "-WEBGL.glb"
		)

		lblStatus.caption = "Converting to GLB..."
		watchdogMgr.beat stage: "converting_glb"
		logMessage ("Converting to GLB: " + glbName) postLogs: postLogs
		local glb = ::API_BATCH_GLB_CONVERTER.run scn: scn out: d ao: ao isNormalizeTiling: false

		-- Convert to Blender
		if (convertToBlend) do (
			if (blendGLBMgr.isBlenderExist()) then (
				lblStatus.caption = "Converting to Blender..."
				watchdogMgr.beat stage: "converting_blend"
				logMessage ("Converting to Blender: " + blendName) postLogs: postLogs

				blendGLBMgr.init glb: glb name: blendName
				join expectedExitFiles #(
					d + blendName + ".zip",
					d + blendName + ".json",
					d + blendName + ".png"
				)

				blendGLBMgr.convertGLB2Blend()
				--blendGLBMgr.makeScreenshot()
				blendGLBMgr.makeRender()
				blendGLBMgr.makeArchive()
				blendGLBMgr.makeJson()
			) else (
				logMessage "[Error] Blender conversion is enabled, but Blender was not found." postLogs: postLogs
			)
		)

		-- Convert to SketchUp
		if (convertToSketchup) do (
			if (skpMgr.isSketchupExist()) then (
				lblStatus.caption = "Converting to SketchUp..."
				watchdogMgr.beat stage: "converting_skp"
				logMessage ("Converting to SketchUp: " + skpName) postLogs: postLogs

				skpMgr.init name: skpName glb: glb
				join expectedExitFiles #(
					d + skpName + ".zip",
					d + skpName + ".json",
					d + skpName + ".png"
				)

				skpMgr.convertMax2Skp()
				skpMgr.makeArchive()
				skpMgr.makeJson()
			) else (
				logMessage "[Error] SketchUp conversion is enabled, but SketchUp was not found." postLogs: postLogs
			)
		)

		return glb
	)

	/* PROCESS FILES */
	fn processFiles = (
		resetProcessTelegramLogs()
		watchdogMgr.clear()
		lblSlug.caption = ""
		local credentialsMode = getCredentialsMode()
		local credentialsModeLabel = getCredentialsModeLabel credentialsMode
		applyCredentialProfile credentialsMode

		local isAwsCredentialsError = awsUploaderMgr.checkCredentialsError()
		if (isAwsCredentialsError) do (
			messageBox (credentialsModeLabel + " AWS S3 credentials are missing or invalid. Check the settings and try again.") title: "Error!"
			return false
		)

		local isRequestCredentialsError = requestMgr.checkCredentialsError()
		if (isRequestCredentialsError) do (
			messageBox (credentialsModeLabel + " Web API credentials are missing or invalid. Check the settings and try again.") title: "Error!"
			return false
		)

		if (cbxRunListenerErrorObserver.checked) do (
			(listenerObserverWrapper()).run()
		)

		local r = false
		statusMessageRestartQueueIn dispose: true
		statusMessageRestartMaxIn dispose: true
		statusMessageScanningWillStart dispose: true

		local d = edtInputPath.text
		local jr = JsonReaderWrapper()
		local q = requestMgr.getQueue()
		jr.read q

		lblStatus.caption = "Getting queue..."

		-- Is correct JSON (Restart)
		local isSuccess = jr.getBool "success"
		if (not isSuccess) do (
			apiQueueFailureCount += 1
			if (apiQueueFailureCount >= 3 and not apiQueueTelegramAlertSent) do (
				sendApiQueueFailureTelegram q credentialsModeLabel
			)
			restartProcessFiles msg: "Cannot retrieve a request from the API. Restarting in"
			return false
		)

		apiQueueFailureCount = 0

		-- Is Queue empty (Restart)
		if (jr.getString "message" != "queue_item_received") do (
			restartProcessFiles msg: "Queue is empty. Restarting in"
			return false
		)

		statusMessageRestartQueueIn dispose: true
		statusMessageRestartMaxIn dispose: true
		statusMessageScanningWillStart dispose: true

		lblStatus.caption = "Parsing queue response..."

		-- Parse JSON
		local a_id = jr.getString "autoconvertion_id"
		local model_id = jr.getString "model_id"
		local version_id = jr.getString "version_id"
		local slug = jr.getString "slug"
		local download_url = jr.getString "download_url"
		local status_id = jr.getString "status_id"
		local source_original_name = jr.getString "source_original_name"
		local count_total = jr.getInt "count_total"
		local outputBaseName = a_id + "-" + slug
		requestMgr.a_id = a_id
		requestMgr.model_id = model_id
		requestMgr.version_id = version_id
		requestMgr.slug = slug

		postProcessLog "Updating status to In Progress..."
		lblStatus.caption = "Updating status to In Progress..."

		-- Set Status: in_progress
		requestMgr.postStatus #in_progress txt: ("Processing file: " + slug)
		lblSlug.caption = a_id + "-" + slug
		watchdogMgr.start slug a_id stage: "in_progress"

		local downloadMgr = DownloadWrapper()
		local guid = genGUID()
		local fname = guid + ".zip"
		local file = d + fname
		-- Clear all files in folder
		lblStatus.caption = "Clearing working folder..."
		watchdogMgr.beat stage: "clearing_working_folder"
		clearFolder d

		-- Download file
		postProcessLog "Downloading source file..."
		lblStatus.caption = "Downloading source file..."
		watchdogMgr.beat stage: "downloading_source"

		downloadMgr.download download_url file

		postProcessLog "Source file downloaded. Validating file..."
		lblStatus.caption = "Validating downloaded file..."
		watchdogMgr.beat stage: "validating_download"

		-- Tell that we try conversion
		watchdogMgr.beat stage: "post_attempt"
		requestMgr.postAttempt()

		-- Is file not valid immediately request next file
		if (not downloadMgr.isValidFile file) do (
			return failCurrentProcess slug source_original_name ("Downloaded file is invalid: " + slug) statusCaption: "Downloaded file is invalid."
		)

		postProcessLog ("Source file downloaded: " + slug)
		requestMgr.postStatus #downloaded txt: ("Source file downloaded: " + slug)

		local blendGLBMgr = BlenderGLBWrapper()
		local skpMgr = SketchupConverterWrapper()

		SceneConverter.BackupOriginalFiles = false
		SetQuietMode true
		escapeEnable = true
		clearListener()

		struct AO_Settings (enabled, passes, resolution, denoise, size, type)
		local ao = AO_Settings()
		ao.enabled = cbxBakeCoronaAO.checked
		ao.size = (::_rGCAutoGLBConverter_Settings.spnAOSize.value as string) + "cm"
		ao.passes = ::_rGCAutoGLBConverter_Settings.spnAOPasses.value
		ao.resolution = ::_rGCAutoGLBConverter_Settings.spnAOResolution.value
		ao.denoise = ::_rGCAutoGLBConverter_Settings.cbxAODenoise.checked
		ao.type = #corona

		lblStatus.caption = "Extracting archive and loading scene..."
		postProcessLog "Extracting archive and loading scene..."
		watchdogMgr.beat stage: "loading_scene"
		local r = ::API_BATCH_GLB_CONVERTER.load file

		if (not r.opened) do (
			clearFolder d
			return failCurrentProcess slug source_original_name "Cannot open scene file."
		)

		local expectedExitFiles = #()
		local layerNames = getGeometryLayerNames()
		local splitByLayers = layerNames.count > 1
		local sourceSceneFile = maxFilePath + maxFileName
		local sourceDeleteDir = r.del

		if (splitByLayers and doesFileExist sourceSceneFile) then (
			watchdogMgr.beat stage: "checking_layers"
			postProcessLog ("Scene has " + (layerNames.count as string) + " layers with objects. Converting each layer separately.")
			logLayerPolyStats layerNames

			watchdogMgr.beat stage: "checking_polygons"
			local failedLayerStats = getLayersOverPolyLimit layerNames
			if (failedLayerStats.count > 0) do (
				local m = "Layer polygon limit exceeded. Limit per layer: " + (_MAX_ALLOWED_POLYS as string) + ". Failed layers: " + (formatPolyStatsList failedLayerStats) + "."
				return failCurrentProcess slug source_original_name m statusCaption: "Layer polygon limit exceeded. Skipping file."
			)

			r.del = undefined

			for i in 1 to layerNames.count do (
				local layerName = layerNames[i]
				local suffix = "-" + (i as string)
				local glbName = outputBaseName + "-GLB" + suffix
				local blendName = outputBaseName + "-BLEND" + suffix
				local skpName = outputBaseName + "-SKP" + suffix

				lblStatus.caption = "Loading layer " + (i as string) + " of " + (layerNames.count as string) + "..."
				postProcessLog ("Loading source scene for layer " + (i as string) + ": " + layerName)
				watchdogMgr.beat stage: ("loading_layer_" + (i as string))
				loadMaxFile sourceSceneFile quiet: true
				resetLoadedSceneState()

				local objectsCount = keepOnlyGeometryFromLayer layerName
				if (objectsCount == 0) then (
					postProcessLog ("[Warning] Layer has no geometry after reload. Skipping layer: " + layerName)
				) else (
					postProcessLog ("Converting layer " + (i as string) + " of " + (layerNames.count as string) + ": " + layerName)
					watchdogMgr.beat stage: ("converting_layer_" + (i as string))
					convertSceneVariant r glbName blendName skpName d ao blendGLBMgr skpMgr expectedExitFiles
				)
			)

			if (sourceDeleteDir != undefined) do ::API_BATCH_GLB_CONVERTER.rmDir sourceDeleteDir
		) else (
			if (splitByLayers and not doesFileExist sourceSceneFile) do (
				postProcessLog "[Warning] Multiple layers were detected, but the source scene file could not be reloaded. Converting the whole scene."
			)

			watchdogMgr.beat stage: "checking_polygons"
			local sceneStat = getGeometryPolyStats (geometry as array) label: "Whole scene"
			postProcessLog ("Polygon limit per exported variant: " + (_MAX_ALLOWED_POLYS as string))
			postProcessLog ("Scene polygon count: " + (formatPolyStats sceneStat))
			if (sceneStat[2] > _MAX_ALLOWED_POLYS) do (
				local m = "The polygon count exceeds the allowed limit. Limit: " + (_MAX_ALLOWED_POLYS as string) + ". Scene polygons: " + (sceneStat[2] as string) + "."
				return failCurrentProcess slug source_original_name m statusCaption: "Polygon limit exceeded. Skipping file."
			)

			convertSceneVariant r (outputBaseName + "-GLB") (outputBaseName + "-BLEND") (outputBaseName + "-SKP") d ao blendGLBMgr skpMgr expectedExitFiles
		)

		watchdogMgr.beat stage: "collecting_outputs"
		local cntExistingFiles = checkExistingFiles expectedExitFiles
		if (cntExistingFiles != expectedExitFiles.count) then (
			local m = "Not all files were converted. Expected: " + expectedExitFiles.count as string + ". Found: " + cntExistingFiles as string + "."
			postProcessLog m
		) else (
			local m = "All files were converted. Uploading to S3..."
			postProcessLog m
		)

		local uploadedFiles = #()
		local failedFiles = #()

		lblStatus.caption = "Uploading files to S3..."
		postProcessLog "Uploading files to S3..."
		watchdogMgr.beat stage: "uploading_files"

		local uploadIndex = 0
		for f in expectedExitFiles do (
			uploadIndex += 1
			local fileName = filenameFromPath f
			watchdogMgr.beat stage: ("uploading_file_" + (uploadIndex as string))

			if (not doesFileExist f) then (
				local m = "[Error] Upload skipped. File does not exist: " + fileName
				append failedFiles fileName
				postProcessLog m
			) else (
				local uploadResult = awsUploaderMgr.upload f
				local isUploaded = (uploadResult[1] == "true")
				local uploadMessage = uploadResult[2]

				if (isUploaded) then (
					append uploadedFiles fileName
					postProcessLog ("Uploaded to S3: " + fileName)
				) else (
					append failedFiles fileName
					postProcessLog ("[Error] " + uploadMessage)
				)
			)
		)
		
		if (uploadedFiles.count == expectedExitFiles.count) then (
			local m = "All files were uploaded to S3 successfully: " + (implodeString uploadedFiles)
			local successMessage = "Uploaded successfully!"
			lblStatus.caption = "All files were uploaded to S3."
			requestMgr.postStatus #uploaded txt: m
			postProcessLog m
			postProcessLog successMessage

			local result_json = buildUploadedFilesResultJson uploadedFiles
			postProcessLog ("Result JSON: " + result_json)

			watchdogMgr.beat stage: "posting_result"
			requestMgr.postStatus #success txt: successMessage result_json: result_json
			markProcessedFileInSession()
			sendProcessingTelegramReport true slug source_original_name expectedExitFiles uploadedFiles failedFiles result_json
			watchdogMgr.clear()
		) else (
			local m = "No files were uploaded to S3. Failed files: " + (implodeString failedFiles)
			lblStatus.caption = "No files were uploaded."
			watchdogMgr.beat stage: "posting_error"
			requestMgr.postStatus #error txt: m
			postProcessLog m
			markProcessedFileInSession()
			sendProcessingTelegramReport false slug source_original_name expectedExitFiles uploadedFiles failedFiles "" errorMessage: m
			watchdogMgr.clear()
		)

		if (processedFilesInSession >= maxProcessFilesInSession) do (
			schedule3dsMaxRestartAfterProcessedLimit()
			return true
		)

		statusMessageNextProcess create: true
		tmrNextProcess.active = true
	)

	on cbxBakeCoronaAO changed v do '*'.add "cbxBakeCoronaAO" v
	on cbxConvertToBlend changed v do '*'.add "cbxConvertToBlend" v
	on cbxConvertToSketchup changed v do '*'.add "cbxConvertToSketchup" v
	on cbxRunListenerErrorObserver changed v do '*'.add "cbxRunListenerErrorObserver" v

	on btnStartStartupProcess changed v do (
		local errors = #()
		local isBlenderExist = (BlenderGLBWrapper()).isBlenderExist()
		local isSketchupExist = (SketchupConverterWrapper()).isSketchupExist()
		local credentialsMode = getCredentialsMode()
		local credentialsModeLabel = getCredentialsModeLabel credentialsMode
		applyCredentialProfile credentialsMode

		local d = edtInputPath.text

		if (d == "") do (
			btnStartStartupProcess.checked = false
			append errors #("Please set the working path.", true)
		)

		local isAwsCredentialsError = awsUploaderMgr.checkCredentialsError()
		if (isAwsCredentialsError) do (
			btnStartStartupProcess.checked = false
			append errors #(("Invalid " + credentialsModeLabel + " AWS credentials. Check the settings and try again!"), true)
		)

		local isRequestCredentialsError = requestMgr.checkCredentialsError()
		if (isRequestCredentialsError) do (
			btnStartStartupProcess.checked = false
			append errors #(("Invalid " + credentialsModeLabel + " Web API credentials. Check the settings and try again!"), true)
		)

		if (cbxConvertToBlend.checked and not isBlenderExist) do append errors #("Blender was not found.", false)
		if (cbxConvertToSketchup.checked and not isSketchupExist) do append errors #("SketchUp was not found.", false)
		if (not cbxBakeCoronaAO.checked) do append errors #("AO baking is disabled.", false)

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
			processedFilesInSession = 0
			updateRemainingFilesLabel()

			local s = "try (fileIn @\"" + (getThisScriptFilename()) + "\") catch (print \"Error! Can't GC-Autoconverter-GLB.ms!\")"
			writeFile startupScript s

			statusMessageScanningWillStart create: true

			tmrOnStartDelay.active = true

			print "Auto-conversion is enabled."
		) else (
			forceDeleteFile startupScript
			tmrOnStartDelay.active = false
			tmrNextProcess.active = false
			tmrQueueRestart.active = false
			tmrCounteRestart.active = false

			statusMessageRestartMaxIn dispose: true
			statusMessageScanningWillStart dispose: true
			statusMessageNextProcess dispose: true
			statusMessageRestartQueueIn dispose: true

			lblStatus.caption =	"Auto-conversion is disabled."
			print "Auto-conversion is disabled."
		)

		updateButtonStatus()
	)

	on _rGCAutoGLBConverter_Main open do (
		_fGCAutoGLBConverter.pos = [0, 25]

		loadSettings()
		updateMode()
		updateButtonStatus()

		if (btnStartStartupProcess.checked) do (
			local d = edtInputPath.text

			if (d == "") do (
				btnStartStartupProcess.checked = false
				forceDeleteFile startupScript
				return messageBox "Please set the working path." title: "Error!"
			)

			statusMessageScanningWillStart create: true
			tmrOnStartDelay.active = true
		)
	)

	on _rGCAutoGLBConverter_Main close do (
		(listenerObserverWrapper()).destroy()
	)

	on tmrCounterBeforeStart tick do (
		statusMessageScanningWillStart()
	)

	on tmrCounterMaxRestart tick do (
		statusMessageRestartMaxIn()
	)

	on tmrCounteRestart tick do (
		tmrCounteRestart.active = false
		restart3dsMax()
	)

	on tmrOnStartDelay tick do (
		tmrOnStartDelay.active = false
		processFiles retry: true
	)

	on tmrNextProcess tick do (
		tmrNextProcess.active = false
		processFiles retry: true
	)

	on tmrCounterQueueRestart tick do (
		statusMessageRestartQueueIn()
	)

	on tmrQueueRestart tick do (
		tmrQueueRestart.active = false
		processFiles()
	)

	on cbxModeProd changed v do (
		setMode mode: #prod
		warnAboutNecessaryOptions()
	)

	on cbxModeTest changed v do (
		setMode mode: #test
	)
)

rollout _rGCAutoGLBConverter_Credentails "Credentials" category: 2 (
	local activeCredentialMode = #prod
	local isLoadingCredentials = false

	dotNetControl tabControl "System.Windows.Forms.TabControl" height: 25 width: 280 offset: [-10, 0]

	group "Web API" (
		label lblWebApiBaseUrl "Base URL:" align: #left across: 2
		edittext edtWebApiBaseUrl "" align: #right width: 180

		label lblWebApiSecretKey "Secret Key:" align: #left across: 2
		edittext edtWebApiSecretKey "" align: #right width: 180

		button btnTestWebApi "Test" width: 80 align: #right
	)

	group "AWS S3" (
		label lblAwsRegion "Region:" align: #left across: 2
		edittext edtAwsRegion "" align: #right width: 180

		label lblAwsBucket "Bucket:" align: #left across: 2
		edittext edtAwsBucket "" align: #right width: 180

		label lblAwsUser "User:" align: #left across: 2
		edittext edtAwsUser "" align: #right width: 180

		label lblAwsSecretKey "Secret Key:" align: #left across: 2
		edittext edtAwsSecretKey "" align: #right width: 180

		button btnTestAws "Test" width: 80 align: #right
	)

	group "Telegram" (
		label lblTelegramToken "Bot Token:" align: #left across: 2
		edittext edtTelegramToken "" align: #right width: 180

		label lblTelegramChatId "Chat ID:" align: #left across: 2
		edittext edtTelegramChatId "" align: #right width: 180

		button btnTestTelegram "Test" width: 80 align: #right
	)

	fn trim s = (
		return trimLeft (trimRight s)
	)

	fn makeTab t = (
		return dotNetObject "System.Windows.Forms.TabPage" t
	)

	fn setupTabs = (
		if (tabControl.TabPages.Count == 0) do (
			tabControl.TabPages.Add (makeTab "Production")
			tabControl.TabPages.Add (makeTab "Testing")
		)
	)

	fn getSelectedTabMode = (
		if (tabControl.SelectedIndex == 1) then #test else #prod
	)

	fn selectTabByMode mode = (
		tabControl.SelectedIndex = if (mode == #test) then 1 else 0
	)

	fn saveSettings mode: activeCredentialMode = (
		'*'.add (getCredentialsKey mode "WebApiBaseUrl") (trim edtWebApiBaseUrl.text)
		'*'.add (getCredentialsKey mode "WebApiSecretKey") (trim edtWebApiSecretKey.text)
		'*'.add (getCredentialsKey mode "AwsRegion") (trim edtAwsRegion.text)
		'*'.add (getCredentialsKey mode "AwsBucket") (trim edtAwsBucket.text)
		'*'.add (getCredentialsKey mode "AwsUser") (trim edtAwsUser.text)
		'*'.add (getCredentialsKey mode "AwsSecretKey") (trim edtAwsSecretKey.text)
		'*'.add (getCredentialsKey mode "TelegramToken") (trim edtTelegramToken.text)
		'*'.add (getCredentialsKey mode "TelegramChatId") (trim edtTelegramChatId.text)

		if (mode == (getCredentialsMode())) do applyCredentialProfile mode
	)

	fn loadSettings mode: activeCredentialMode = (
		migrateCredentialsSettings()

		isLoadingCredentials = true
		activeCredentialMode = mode

		local defaultBaseUrl = if (mode == #prod) then (requestWrapper()).apiUrl else ""

		edtWebApiBaseUrl.text = getCredentialValue mode "WebApiBaseUrl" defaultValue: defaultBaseUrl
		edtWebApiSecretKey.text = getCredentialValue mode "WebApiSecretKey"
		edtAwsRegion.text = getCredentialValue mode "AwsRegion"
		edtAwsBucket.text = getCredentialValue mode "AwsBucket"
		edtAwsUser.text = getCredentialValue mode "AwsUser"
		edtAwsSecretKey.text = getCredentialValue mode "AwsSecretKey"
		edtTelegramToken.text = getCredentialValue mode "TelegramToken"
		edtTelegramChatId.text = getCredentialValue mode "TelegramChatId"

		isLoadingCredentials = false
	)

	fn testWebApiCredentials = (
		saveSettings mode: activeCredentialMode
		applyCredentialProfile activeCredentialMode

		local modeLabel = getCredentialsModeLabel activeCredentialMode

		if (requestMgr.checkCredentialsError()) do (
			messageBox (modeLabel + " Web API credentials are missing or invalid.") title: "Web API Test"
			return false
		)

		local response = requestMgr.getQueue()
		if (response == undefined or response == "") do (
			messageBox (modeLabel + " Web API test failed. Empty response.") title: "Web API Test"
			return false
		)

		local jr = JsonReaderWrapper()
		jr.read response
		local isSuccess = jr.getBool "success"

		if (isSuccess) then (
			messageBox (modeLabel + " Web API test passed.") title: "Web API Test"
			return true
		) else (
			messageBox (modeLabel + " Web API test failed. Response does not contain success:true.") title: "Web API Test"
			return false
		)
	)

	fn testAwsCredentials = (
		saveSettings mode: activeCredentialMode
		applyCredentialProfile activeCredentialMode

		local modeLabel = getCredentialsModeLabel activeCredentialMode

		if (awsUploaderMgr.checkCredentialsError()) do (
			messageBox (modeLabel + " AWS S3 credentials are missing or invalid.") title: "AWS S3 Test"
			return false
		)

		local testScript = (getFileNamePath (getThisScriptFileName())) + "test-s3-uploader.ms"
		if (not doesFileExist testScript) do (
			messageBox "Cannot find test-s3-uploader.ms. Please reinstall or update the script files." title: "AWS S3 Test"
			return false
		)

		fileIn testScript
		return true
	)

	fn testTelegramCredentials = (
		saveSettings mode: activeCredentialMode
		applyCredentialProfile activeCredentialMode

		local modeLabel = getCredentialsModeLabel activeCredentialMode

		if (telegramMgr.checkCredentialsError()) do (
			messageBox (modeLabel + " Telegram credentials are missing or invalid.") title: "Telegram Test"
			return false
		)

		local isTelegramSent = telegramMgr.sendMessage ("GC Autoconverter GLB Telegram test: " + modeLabel)
		if (isTelegramSent) then (
			messageBox (modeLabel + " Telegram test message sent.") title: "Telegram Test"
			return true
		) else (
			local err = telegramMgr.getLastError()
			print ("[Telegram] Test failed: " + err)
			messageBox (modeLabel + " Telegram test failed:\n\n" + err) title: "Telegram Test"
			return false
		)
	)

	on tabControl SelectedIndexChanged args do (
		if (not isLoadingCredentials) do (
			saveSettings mode: activeCredentialMode
			activeCredentialMode = getSelectedTabMode()
			loadSettings mode: activeCredentialMode
		)
	)

	on edtWebApiBaseUrl changed v do (
		if (not isLoadingCredentials) do (
			'*'.add (getCredentialsKey activeCredentialMode "WebApiBaseUrl") (trim v)
			if (activeCredentialMode == (getCredentialsMode())) do applyCredentialProfile activeCredentialMode
		)
	)

	on edtWebApiSecretKey changed v do (
		if (not isLoadingCredentials) do (
			'*'.add (getCredentialsKey activeCredentialMode "WebApiSecretKey") (trim v)
			if (activeCredentialMode == (getCredentialsMode())) do applyCredentialProfile activeCredentialMode
		)
	)

	on edtAwsRegion changed v do (
		if (not isLoadingCredentials) do (
			'*'.add (getCredentialsKey activeCredentialMode "AwsRegion") (trim v)
			if (activeCredentialMode == (getCredentialsMode())) do applyCredentialProfile activeCredentialMode
		)
	)

	on edtAwsBucket changed v do (
		if (not isLoadingCredentials) do (
			'*'.add (getCredentialsKey activeCredentialMode "AwsBucket") (trim v)
			if (activeCredentialMode == (getCredentialsMode())) do applyCredentialProfile activeCredentialMode
		)
	)

	on edtAwsUser changed v do (
		if (not isLoadingCredentials) do (
			'*'.add (getCredentialsKey activeCredentialMode "AwsUser") (trim v)
			if (activeCredentialMode == (getCredentialsMode())) do applyCredentialProfile activeCredentialMode
		)
	)

	on edtAwsSecretKey changed v do (
		if (not isLoadingCredentials) do (
			'*'.add (getCredentialsKey activeCredentialMode "AwsSecretKey") (trim v)
			if (activeCredentialMode == (getCredentialsMode())) do applyCredentialProfile activeCredentialMode
		)
	)

	on edtTelegramToken changed v do (
		if (not isLoadingCredentials) do (
			'*'.add (getCredentialsKey activeCredentialMode "TelegramToken") (trim v)
			if (activeCredentialMode == (getCredentialsMode())) do applyCredentialProfile activeCredentialMode
		)
	)

	on edtTelegramChatId changed v do (
		if (not isLoadingCredentials) do (
			'*'.add (getCredentialsKey activeCredentialMode "TelegramChatId") (trim v)
			if (activeCredentialMode == (getCredentialsMode())) do applyCredentialProfile activeCredentialMode
		)
	)

	on btnTestWebApi pressed do (
		testWebApiCredentials()
	)

	on btnTestAws pressed do (
		testAwsCredentials()
	)

	on btnTestTelegram pressed do (
		testTelegramCredentials()
	)

	on _rGCAutoGLBConverter_Credentails open do (
		setupTabs()
		activeCredentialMode = getCredentialsMode()

		isLoadingCredentials = true
		selectTabByMode activeCredentialMode
		isLoadingCredentials = false

		loadSettings mode: activeCredentialMode
	)
)

rollout _rGCAutoGLBConverter_Settings "Settings" category: 3 (
	group "AO Settings" (
		spinner spnAOPasses "Passes: " range: [1, 9999, 100] type: #integer fieldwidth: 50 align: #right across: 2 offset: [-15, 0]
		spinner spnAOSize "Size (cm): " range: [0.1, 9999.0, 5.0] type: #float fieldwidth: 50
		spinner spnAOResolution "Resolution:"  range: [512, 8192, 1024] scale: 512 type: #integer align: #right fieldwidth: 50 across: 2  offset: [-15, 0]
		checkbox cbxAODenoise "Use VRay Denoiser" offset: [15, 0]
	)

	group "Watchdog Settings" (
		spinner spnWatchdogTimeoutMin "Stuck timeout (min):" range: [1, 999, 15] type: #integer fieldwidth: 50 align: #right
	)

	fn loadSettings = (
		local p = '*'.get "spnAOPasses" type: #int
		spnAOPasses.value = if (p != 0) then p else 100

		local s = '*'.get "spnAOSize" type: #float
		spnAOSize.value = if (s != 0) then s else 5.0

		local r = '*'.get "spnAOResolution" type: #int
		spnAOResolution.value = if (r != 0) then r else 1024

		cbxAODenoise.checked = '*'.get "cbxAODenoise" type: #bool_false

		spnWatchdogTimeoutMin.value = watchdogMgr.getTimeoutMin()
		watchdogMgr.saveTimeout()
	)

	on spnDownloadQueueQuantity changed v do '*'.add  "spnDownloadQueueQuantity" v
	on spnAOPasses changed v do '*'.add  "spnAOPasses" v
	on spnAOSize changed v do '*'.add  "spnAOSize" v
	on spnAOResolution changed v do '*'.add  "spnAOResolution" v
	on cbxAODenoise changed v do '*'.add  "cbxAODenoise" v
	on spnWatchdogTimeoutMin changed v do (
		setIniSetting watchdogMgr.settingsIni watchdogMgr.settingsSec "spnWatchdogTimeoutMin" (v as string)
		watchdogMgr.saveTimeout()
	)

	on _rGCAutoGLBConverter_Settings open do (
		loadSettings()
	)
)

rollout _rGCAutoGLBConverter_Debug "Debug" category: 4 (
	local debugGLBFiles = #()

	group "Formats" (
		checkbox cbxDebugBakeCoronaAO "Bake Corona AO"
		checkbox cbxDebugConvertToBlend "Convert to BLEND"
		checkbox cbxDebugConvertToSketchup "Convert to SKP"
	)

	button btnDebugConvertCurrentScene "Convert Current Scene" width: 260 height: 32

	group "GLB Preview" (
		label lblDebugPreviewInfo "Double-click a GLB file to open it in the browser preview." align: #left
		listbox lbxDebugGLBFiles "" height: 5 width: 260
		button btnDebugUpdateGLBList "Update" width: 260 height: 24
	)

	label lblDebugStatus "" align: #left offset: [0, 5]

	fn debugLog txt = (
		print ("[Debug] " + txt)
		lblDebugStatus.caption = txt
		try (::_rGCAutoGLBConverter_Main.lblStatus.caption = txt) catch ()
	)

	fn ensureTrailingSlash p = (
		if (p == undefined) do p = ""
		p = trimLeft (trimRight (p as string))
		if ((p != "") and ((substring p p.count 1) != "\\")) do p += "\\"
		return p
	)

	fn getOutputPath = (
		local p = try (::_rGCAutoGLBConverter_Main.edtInputPath.text) catch ("")
		p = ensureTrailingSlash p
		if (p == "") do p = ensureTrailingSlash maxFilePath
		return p
	)

	fn buildAOSettings = (
		struct Debug_AO_Settings (enabled, passes, resolution, denoise, size, type)
		local ao = Debug_AO_Settings()
		local aoSize = try (::_rGCAutoGLBConverter_Settings.spnAOSize.value) catch (5.0)
		ao.enabled = cbxDebugBakeCoronaAO.checked
		ao.size = (aoSize as string) + "cm"
		ao.passes = try (::_rGCAutoGLBConverter_Settings.spnAOPasses.value) catch (100)
		ao.resolution = try (::_rGCAutoGLBConverter_Settings.spnAOResolution.value) catch (1024)
		ao.denoise = try (::_rGCAutoGLBConverter_Settings.cbxAODenoise.checked) catch (false)
		ao.type = #corona
		return ao
	)

	fn saveConvertedCompareScene filename = (
		try (
			saveMaxFile filename quiet: true
			return doesFileExist filename
		) catch (
			return false
		)
	)

	fn rememberLastDebugGLB expectedExitFiles = (
		for f in expectedExitFiles where (toLower (getFilenameType f) == ".glb" and doesFileExist f) do (
			'*'.add "debugLastGLB" f
			return f
		)

		return ""
	)

	fn updateDebugGLBList = (
		debugGLBFiles = #()
		local names = #()
		local d = getOutputPath()

		if (d != "" and doesDirectoryExist d) do (
			for f in (getFiles (d + "*.glb")) do (
				append debugGLBFiles f
				append names (filenameFromPath f)
			)
		)

		lbxDebugGLBFiles.items = names
		if (names.count == 0) do debugLog "No GLB files found in the debug output folder."
		return debugGLBFiles.count
	)

	fn previewDebugGLB f = (
		if (f == "") do (
			messageBox "Debug GLB file was not found. Run Convert Current Scene first, or click Update." title: "Debug"
			return false
		)

		debugLog ("Opening GLB preview: " + f)
		local viewer = WebGLPlayerWrapper()
		viewer.run()
		viewer.previewModel f kill: "0"
		return true
	)

	fn convertDebugScene = (
		if (maxFileName == "" or maxFilePath == "") do (
			messageBox "Please save the current scene before debug conversion." title: "Debug"
			return false
		)

		local sceneName = getFilenameFile maxFileName
		local d = getOutputPath()
		if (d == "") do (
			messageBox "Please set the working path or save the current scene." title: "Debug"
			return false
		)

		makeDir d all: true

		local originalSceneFile = d + sceneName + "-ORIGINAL.max"
		local workingSceneFile = d + sceneName + "-DEBUG-WORKING.max"
		local convertedSceneFile = d + sceneName + "-GLB.max"
		local expectedExitFiles = #()
		local convertedSceneFiles = #()

		debugLog ("Saving original compare scene: " + originalSceneFile)
		if (not (saveConvertedCompareScene originalSceneFile)) do (
			messageBox "Cannot save original compare scene." title: "Debug"
			return false
		)

		try (deleteFile workingSceneFile) catch ()
		if (not (copyFile originalSceneFile workingSceneFile)) do (
			messageBox "Cannot create debug working scene copy." title: "Debug"
			return false
		)

		clearListener()
		SetQuietMode true
		SceneConverter.BackupOriginalFiles = false
		escapeEnable = true

		local blendGLBMgr = BlenderGLBWrapper()
		local skpMgr = SketchupConverterWrapper()
		local ao = buildAOSettings()

		debugLog ("Loading debug working scene: " + workingSceneFile)
		local r = ::API_BATCH_GLB_CONVERTER.load workingSceneFile
		if (not r.opened) do (
			SetQuietMode false
			messageBox "Cannot open debug working scene." title: "Debug"
			return false
		)

		local layerNames = ::_rGCAutoGLBConverter_Main.getGeometryLayerNames()
		local splitByLayers = layerNames.count > 1

		if (splitByLayers) then (
			debugLog ("Scene has " + (layerNames.count as string) + " layers with objects. Converting each layer separately.")
			for layerName in layerNames do (
				local stat = ::_rGCAutoGLBConverter_Main.getGeometryLayerPolyStats layerName
				debugLog ("Layer polygon count: " + (::_rGCAutoGLBConverter_Main.formatPolyStats stat))
			)

			local failedLayerStats = ::_rGCAutoGLBConverter_Main.getLayersOverPolyLimit layerNames
			if (failedLayerStats.count > 0) do (
				local m = "Layer polygon limit exceeded. Limit per layer: " + (_MAX_ALLOWED_POLYS as string) + ". Failed layers: " + (::_rGCAutoGLBConverter_Main.formatPolyStatsList failedLayerStats) + "."
				SetQuietMode false
				messageBox m title: "Debug"
				return false
			)

			for i in 1 to layerNames.count do (
				local layerName = layerNames[i]
				local suffix = "-" + (i as string)
				local glbName = sceneName + "-GLB" + suffix
				local blendName = sceneName + "-BLEND" + suffix
				local skpName = sceneName + "-SKP" + suffix
				local layerCompareScene = d + glbName + ".max"

				debugLog ("Loading source scene for layer " + (i as string) + ": " + layerName)
				loadMaxFile workingSceneFile quiet: true
				::_rGCAutoGLBConverter_Main.resetLoadedSceneState()

				local objectsCount = ::_rGCAutoGLBConverter_Main.keepOnlyGeometryFromLayer layerName
				if (objectsCount == 0) then (
					debugLog ("Layer has no geometry after reload. Skipping layer: " + layerName)
				) else (
					debugLog ("Converting layer " + (i as string) + " of " + (layerNames.count as string) + ": " + layerName)
					::_rGCAutoGLBConverter_Main.convertSceneVariant r glbName blendName skpName d ao blendGLBMgr skpMgr expectedExitFiles convertToBlend: cbxDebugConvertToBlend.checked convertToSketchup: cbxDebugConvertToSketchup.checked postLogs: false
					if (saveConvertedCompareScene layerCompareScene) do append convertedSceneFiles layerCompareScene
				)
			)

			try (saveConvertedCompareScene convertedSceneFile) catch ()
		) else (
			local sceneStat = ::_rGCAutoGLBConverter_Main.getGeometryPolyStats (geometry as array) label: "Whole scene"
			debugLog ("Polygon limit per exported variant: " + (_MAX_ALLOWED_POLYS as string))
			debugLog ("Scene polygon count: " + (::_rGCAutoGLBConverter_Main.formatPolyStats sceneStat))
			if (sceneStat[2] > _MAX_ALLOWED_POLYS) do (
				local m = "The polygon count exceeds the allowed limit. Limit: " + (_MAX_ALLOWED_POLYS as string) + ". Scene polygons: " + (sceneStat[2] as string) + "."
				SetQuietMode false
				messageBox m title: "Debug"
				return false
			)

			::_rGCAutoGLBConverter_Main.convertSceneVariant r (sceneName + "-GLB") (sceneName + "-BLEND") (sceneName + "-SKP") d ao blendGLBMgr skpMgr expectedExitFiles convertToBlend: cbxDebugConvertToBlend.checked convertToSketchup: cbxDebugConvertToSketchup.checked postLogs: false
			if (saveConvertedCompareScene convertedSceneFile) do append convertedSceneFiles convertedSceneFile
		)

		local cntExistingFiles = ::_rGCAutoGLBConverter_Main.checkExistingFiles expectedExitFiles
		local lastGLB = rememberLastDebugGLB expectedExitFiles
		updateDebugGLBList()
		local m = "Debug conversion finished.\n\nOriginal scene:\n" + originalSceneFile + "\n\nConverted scene:\n" + convertedSceneFile + "\n\nConverted files found: " + (cntExistingFiles as string) + " of " + (expectedExitFiles.count as string) + "."
		if (lastGLB != "") do m += "\n\nPreview GLB:\n" + lastGLB
		if (convertedSceneFiles.count > 1) do m += "\n\nLayer compare scenes: " + (convertedSceneFiles.count as string)

		SetQuietMode false
		debugLog "Debug conversion finished."
		messageBox m title: "Debug"
		return true
	)

	fn loadSettings = (
		cbxDebugBakeCoronaAO.checked = '*'.get "cbxDebugBakeCoronaAO" type: #bool_true
		cbxDebugConvertToBlend.checked = '*'.get "cbxDebugConvertToBlend" type: #bool_true
		cbxDebugConvertToSketchup.checked = '*'.get "cbxDebugConvertToSketchup" type: #bool_true
	)

	on cbxDebugBakeCoronaAO changed v do '*'.add "cbxDebugBakeCoronaAO" v
	on cbxDebugConvertToBlend changed v do '*'.add "cbxDebugConvertToBlend" v
	on cbxDebugConvertToSketchup changed v do '*'.add "cbxDebugConvertToSketchup" v

	on btnDebugConvertCurrentScene pressed do (
		convertDebugScene()
	)

	on btnDebugUpdateGLBList pressed do (
		updateDebugGLBList()
	)

	on lbxDebugGLBFiles doubleClicked item do (
		if (item > 0 and item <= debugGLBFiles.count) do (
			previewDebugGLB debugGLBFiles[item]
		)
	)

	on _rGCAutoGLBConverter_Debug open do (
		loadSettings()
		updateDebugGLBList()
	)
)

rollout _rGCAutoGLBConverter_About "About" category: 5 (
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
addRollout _rGCAutoGLBConverter_Credentails _fGCAutoGLBConverter rolledUp: true
addRollout _rGCAutoGLBConverter_Settings _fGCAutoGLBConverter rolledUp: true
addRollout _rGCAutoGLBConverter_Debug _fGCAutoGLBConverter rolledUp: true
addRollout _rGCAutoGLBConverter_About _fGCAutoGLBConverter rolledUp: true
