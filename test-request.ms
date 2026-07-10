/*
	Web API manual request test

	Usage:
	1. Run the main GC-Autoconverter-GLB.ms script first.
	2. Make sure Web API settings are loaded in the main script.
	3. Run this file, choose a request type, and click Send Request.

	Notes:
	- autoconvertion_id defaults to 1 and can be changed in the UI.
	- This script sends raw requests so the response body can be shown in the log.
*/

try (destroyDialog _rGCTestRequest) catch()

rollout _rGCTestRequest "Web API Request Test" width: 620 (
	local fixedAutoconvertionId = 1

	group "Request" (
		dropdownlist ddlRequest "Type:" width: 360 items: #(
			"GET queue",
			"POST status: in_progress",
			"POST status: downloaded",
			"POST status: uploaded",
			"POST status: success",
			"POST status: error",
			"POST attempt",
			"POST log"
		)
		spinner spnAutoconvertionId "a_id:" range: [1, 999999999, 1] type: #integer fieldwidth: 80 align: #left
		edittext edtText "Text:" text: "Manual request test" width: 560 height: 44
	)

	group "Result" (
		label lblResult "Ready" width: 580 align: #left
	)

	button btnSend "Send Request" width: 140 align: #center

	group "Response Log" (
		dotNetControl edtLog "System.Windows.Forms.TextBox" width: 580 height: 320
		button btnClearLog "Clear log" width: 90 align: #right
	)

	fn getRequestMgr = (
		try (return requestMgr) catch (return undefined)
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
	)

	fn makeResultCaption msg = (
		if (msg == undefined or msg == "") do return "Ready"
		local s = msg as string
		local lineEnd = findString s "\n"
		if (lineEnd != undefined) do s = substring s 1 (lineEnd - 1)
		if (s.count > 90) do s = (substring s 1 87) + "..."
		return s
	)

	fn setResult msg log: true = (
		lblResult.caption = makeResultCaption msg
		if (log) do appendLog msg
	)

	fn escapeJsonString s = (
		if (s == undefined) do s = ""
		s = s as string
		s = substituteString s "\\" "\\\\"
		s = substituteString s "\"" "\\\""
		s = substituteString s "\r" "\\r"
		s = substituteString s "\n" "\\n"
		s = substituteString s "\t" "\\t"
		return s
	)

	fn makeJsonPair key value quoteValue: true = (
		local v = if (quoteValue) then ("\"" + (escapeJsonString value) + "\"") else (value as string)
		return "\"" + key + "\":" + v
	)

	fn repeatText txt count = (
		local result = ""
		for i = 1 to count do result += txt
		return result
	)

	fn prettyJson s = (
		if (s == undefined) do return ""
		s = trimLeft (trimRight (s as string))
		if (s == "") do return s

		local firstChar = substring s 1 1
		if (firstChar != "{" and firstChar != "[") do return s

		local result = ""
		local indent = 0
		local inString = false
		local escaped = false
		local nl = "\r\n"
		local indentText = "  "

		for i = 1 to s.count do (
			local ch = substring s i 1

			if (inString) then (
				result += ch
				if (escaped) then (
					escaped = false
				) else if (ch == "\\") then (
					escaped = true
				) else if (ch == "\"") then (
					inString = false
				)
			) else (
				case ch of (
					"\"": (
						inString = true
						result += ch
					)
					"{": (
						result += ch
						indent += 1
						result += nl + (repeatText indentText indent)
					)
					"[": (
						result += ch
						indent += 1
						result += nl + (repeatText indentText indent)
					)
					"}": (
						indent -= 1
						if (indent < 0) do indent = 0
						result += nl + (repeatText indentText indent) + ch
					)
					"]": (
						indent -= 1
						if (indent < 0) do indent = 0
						result += nl + (repeatText indentText indent) + ch
					)
					",": (
						result += ch + nl + (repeatText indentText indent)
					)
					":": (
						result += ": "
					)
					" ": (
						-- Skip unquoted spaces in compact JSON.
					)
					default: (
						result += ch
					)
				)
			)
		)

		return result
	)

	fn buildPostBody requestName txt = (
		local autoconvertionId = spnAutoconvertionId.value as string
		case requestName of (
			"POST status: in_progress": (
				return "{" + (makeJsonPair "autoconvertion_id" autoconvertionId) + "," + (makeJsonPair "status_id" "#in_progress") + "," + (makeJsonPair "txt" txt) + "}"
			)
			"POST status: downloaded": (
				return "{" + (makeJsonPair "autoconvertion_id" autoconvertionId) + "," + (makeJsonPair "status_id" "#downloaded") + "," + (makeJsonPair "txt" txt) + "}"
			)
			"POST status: uploaded": (
				return "{" + (makeJsonPair "autoconvertion_id" autoconvertionId) + "," + (makeJsonPair "status_id" "#uploaded") + "," + (makeJsonPair "txt" txt) + "}"
			)
			"POST status: success": (
				local resultJson = "{\"GLB\":[\"manual-test.glb\"]}"
				return "{" + (makeJsonPair "autoconvertion_id" autoconvertionId) + "," + (makeJsonPair "status_id" "#success") + "," + (makeJsonPair "txt" txt) + "," + (makeJsonPair "result_json" resultJson) + "}"
			)
			"POST status: error": (
				return "{" + (makeJsonPair "autoconvertion_id" autoconvertionId) + "," + (makeJsonPair "status_id" "#error") + "," + (makeJsonPair "txt" txt) + "}"
			)
			"POST attempt": (
				return "{" + (makeJsonPair "autoconvertion_id" autoconvertionId) + ",\"attempt_convertion\":true}"
			)
			"POST log": (
				return "{" + (makeJsonPair "autoconvertion_id" autoconvertionId) + "," + (makeJsonPair "txt" txt) + "}"
			)
			default: (
				return "{}"
			)
		)
	)

	fn getRequestUrl mgr requestName = (
		case requestName of (
			"GET queue": mgr.apiGetQueue
			"POST log": mgr.apiPostLog
			default: mgr.apiPostStatus
		)
	)

	fn validateRequestMgr mgr = (
		if (mgr == undefined) do (
			setResult "requestMgr not found. Run the main script first."
			messageBox "requestMgr not found. Run the main script first." title: "Web API Request Test"
			return false
		)

		if (mgr.checkCredentialsError()) do (
			setResult "Web API credentials are missing or invalid."
			messageBox "Web API credentials are missing or invalid. Check the main script settings." title: "Web API Request Test"
			return false
		)

		return true
	)

	fn sendGet url apiKey = (
		local client = dotNetObject "System.Net.WebClient"
		local response = undefined
		try (
			local spm = dotNetClass "System.Net.ServicePointManager"
			spm.SecurityProtocol = spm.SecurityProtocol.TLS12
			client.Encoding = (dotNetClass "System.Text.Encoding").GetEncoding("UTF-8")
			client.Headers.Add "Accept" "application/json"
			client.Headers.Add "x-api-key" (apiKey as string)
			local glue = if ((findString url "?") == undefined) then "?" else "&"
			response = client.DownloadString (url + glue + "time=" + ((timestamp()) as string))
		) catch (
			local ex = getCurrentException()
			response = "[Exception]\n" + (ex as string)
		)
		try (client.Dispose()) catch()
		return response
	)

	fn sendPost url apiKey body = (
		local client = dotNetObject "System.Net.WebClient"
		local response = undefined
		try (
			local spm = dotNetClass "System.Net.ServicePointManager"
			spm.SecurityProtocol = spm.SecurityProtocol.TLS12
			client.Encoding = (dotNetClass "System.Text.Encoding").GetEncoding("UTF-8")
			client.Headers.Add "Content-Type" "application/json"
			client.Headers.Add "Accept" "application/json"
			client.Headers.Add "x-api-key" (apiKey as string)
			response = client.UploadString url "POST" body
		) catch (
			local ex = getCurrentException()
			response = "[Exception]\n" + (ex as string)
		)
		try (client.Dispose()) catch()
		return response
	)

	on btnSend pressed do (
		local mgr = getRequestMgr()
		if (not validateRequestMgr mgr) do return false

		mgr.a_id = spnAutoconvertionId.value

		local requestName = ddlRequest.items[ddlRequest.selection]
		if (requestName == undefined or requestName == "") do (
			setResult "Choose request type first."
			return false
		)

		local url = getRequestUrl mgr requestName
		local body = ""
		local response = ""

		setResult ("Sending: " + requestName + "\nURL: " + url)

		if (requestName == "GET queue") then (
			response = sendGet url mgr.apiKey
		) else (
			body = buildPostBody requestName edtText.text
			response = sendPost url mgr.apiKey body
		)

		local logText = requestName + "\na_id: " + (spnAutoconvertionId.value as string) + "\nURL: " + url
		if (body != "") do logText += "\n\nRequest body:\n" + (prettyJson body)
		logText += "\n\nResponse:\n" + (prettyJson response)

		setResult logText
	)

	on btnClearLog pressed do (
		edtLog.Text = ""
		lblResult.caption = "Ready"
	)

	on _rGCTestRequest open do (
		edtLog.Multiline = true
		edtLog.ReadOnly = true
		edtLog.WordWrap = false
		edtLog.ScrollBars = (dotNetClass "System.Windows.Forms.ScrollBars").Both
		edtLog.Font = dotNetObject "System.Drawing.Font" "Consolas" 9
		spnAutoconvertionId.value = fixedAutoconvertionId
		ddlRequest.selection = 1
		setResult "Ready" log: false
	)
)

createDialog _rGCTestRequest
