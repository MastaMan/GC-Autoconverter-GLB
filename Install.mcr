/*  
[INFO] 
NAME=Auto Installer
AUTHOR=Vasyl Lukianenko
DEV=3DGROUND
DEV_WEB=https://3dground.net/
HELP=

MACRO=GC_Autoconverter_GLB
CAT=GreatCatalog
TXT=GC Autoconverter GLB
RUN=GC-Autoconverter-GLB.ms
VER=1.0.0
ICON=

[SCRIPT]
*/

struct SimpleInstallerWrapper (
    currentPath = getFileNamePath (getThisScriptFileName()),
    manifest = getThisScriptFileName(),
        
    fn settings k s: "INFO" = (
        return getINISetting this.manifest s k
    ),
    
    macro = this.settings "MACRO",
    cat = this.settings "CAT",
    txt = this.settings "TXT",
    run = this.settings "RUN",
    ver = this.settings "VER",
    embedPath = substituteString this.currentPath @"\" "\\\\",
    upd = this.embedPath + "update.ms",
    script = this.embedPath + this.run,
	iconFile = this.settings "ICON",

    fn installMacroScript = (
        local exec = ""
        exec += "macroScript " + this.macro + "\n"
        exec += "buttontext: \"" + this.txt + "\"\n"
        exec += "category: \"" + this.cat + "\"\n"
        if (iconFile != "") do exec += "icon: #(\"" + this.iconFile + "\", 1)\n"
        exec += "(\n"
        exec += "\ton execute do (\n"
        exec += "\t\tlocal s = \"" + this.script + "\"\n"
        exec += "\t\tlocal u = \"" + this.upd + "\"\n"
        exec += "\t\ttry(fileIn(s)) catch(messageBox \"Script not found! Download " + this.txt + " again!\" title: \"Error!\")\n"
        exec += "\t\ttry(fileIn(u)) catch()\n"
        exec += "\t)\n"
        exec += ")\n"
        
        try (execute exec) catch (print "Can't install MacroScript")
    ),
        
    fn getNotes = (
        return getINISetting this.run this.ver
    ),
	
    on create do (
        local n = "\n"
        
        this.installMacroScript()
        
		colorman.reInitIcons()
		
        local m = n
        m += n
        m += "\t              " + this.txt + " installed successfully!" + "     " + n
        m += "\t==============================================" + n + n + n
        
        --m += this.txt + " added automatically to Quad Menu!" + n + n + n
        m += "[!] To add a button to the toolbar:" + n
        m += " 1. Go to Customize User Interface" + n
        m += " 2. Tab: Toolbars" + n 
        m += " 3. Category: \"" + this.cat + "\"" + n
        m += " 4. Drag&Drop the \"" +  this.txt + "\" to toolbar" + n + n + n
        
        messageBox m title: "Installation"
        
        try (execute ("fileIn \"" + this.script + "\"")) catch ()
    )
)

SimpleInstallerWrapper()