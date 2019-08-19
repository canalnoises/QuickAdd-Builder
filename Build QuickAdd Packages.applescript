use AppleScript version "2.4" -- Yosemite (10.10) or later
use scripting additions

-- Automatically build Jamf QuickAdd packages for multiple sites
-- Isaac Nelson <isaac.nelson@churchofjesuschrist.org>
-- Version 1.0 - 3 March 2018
-- Version 2.0 - 13 August 2019
-- Version 2.1 - 19 August 2019 (public release)



-- SET CUSTOM VARIABLES
set jamfServer1 to "Company's Jamf Pro Server" -- Change to the name of your production Jamf Pro server
set jamfServer2 to "Company's Jamf Pro Server" -- Change to the name of your beta Jamf Pro server
set jamfServer3 to "Company's Jamf Pro Server" -- Change to the name of your dev Jamf Pro server

set certName to "Developer ID Installer: Your Company (ID number)" -- Change to the name of your Developer ID Installer certificate. If you don't want to sign the packages

set defaultPath to "My External HD:Packages and Scripts:Enrollment Packages:" -- Change this to the default path you want Recon to use for saving packages. I have mine set to a network volume, so if that volume isn't mounted when the script runs it will default to the desktop.

-- If you want to change the naming convention for your QuickAdd packages, search the script for the first instance of "QuickAddName" and edit that line. The default is "QuickAdd-[site name]-[ProdLane/BetaLane/DevLane]-[Recon version]"

-- NO NEED TO EDIT BELOW THIS LINE (unless you want to change the pkg naming convention as described above)

(*

-- Can’t figure out how to get Recon to point to a different server. 
-- Modifying the com.jamfsoftware.recon and com.jamfsoftwarre.jss plists with the defaults command 
-- doesn’t seem to change what server Recon points to, even though it’s one of those same files that  
-- gets changed when you change the server in the Recon.app GUI. 
-- Instead we just grab the name of the Jamf Pro server from Recon.app's title bar

set lanes to {"1. Dev", "2. Beta", "3. Prod"}
set selLane to (choose from list lanes with prompt "Choose a Jamf Pro server:") as text

if selLane is "1. Dev" then
	set selLane to "Dev"
	do shell script "defaults write com.jamfsoftware.recon server -string 'https://jamf-dev.company.com:8443'"
else if selLane is "2. Beta" then
	set selLane to "Beta"
	do shell script "defaults write com.jamfsoftware.recon server -string 'https://jamf-beta.company.com:8443'"
else if selLane is "3. Prod" then
	set selLane to "Prod"
	do shell script "defaults write com.jamfsoftware.recon server -string 'https://jamf-prod.company.com:8443'"
end if
*)

tell application "Recon" to activate

tell application "System Events"
	tell process "Recon"
		
		if (count of windows) > 0 then
			set windowName to name of front window
			set reconVersion to (do shell script "echo " & quoted form of windowName & " | awk '{print $2}'")
			repeat while windowName is "Recon " & reconVersion & " for  - Local Enrollment"
				set windowName to name of front window
				delay 3
			end repeat
			if windowName contains jamfServer1 then
				set selLane to "Prod"
			else if windowName contains jamfServer2 then
				set selLane to "Beta"
			else if windowName contains "jamfServer3" then
				set selLane to "Dev"
			end if
		else
			display dialog "Recon.app must be running and logged in to a Jamf Pro server"
			return
		end if
		
		
		
		--Change to the QuickAdd Package panel
		if windowName does not contain "QuickAdd Package" then
			--Find out where on the screen the button is
			set QuickAddButtonPos to position of static text 1 of row 3 of table 1 of scroll area 1 of window 1
			
			set x to (item 1 of QuickAddButtonPos)
			set y to (item 2 of QuickAddButtonPos)
			do shell script " 
/usr/bin/python <<END
import sys
import time
from Quartz.CoreGraphics import * 
def mouseEvent(type, posx, posy):
          theEvent = CGEventCreateMouseEvent(None, type, (posx,posy), kCGMouseButtonLeft)
          CGEventPost(kCGHIDEventTap, theEvent)
def mousemove(posx,posy):
          mouseEvent(kCGEventMouseMoved, posx,posy);
def mouseclick(posx,posy):
          mouseEvent(kCGEventLeftMouseDown, posx,posy);
          mouseEvent(kCGEventLeftMouseUp, posx,posy);
ourEvent = CGEventCreate(None); 
currentpos=CGEventGetLocation(ourEvent);             # Save current mouse position
mouseclick(" & x & "," & y & ");
mousemove(int(currentpos.x),int(currentpos.y));      # Restore mouse position
END"
			-- Python code to simulate mouse click from https://discussions.apple.com/thread/3708948?answerId=25436093022#25436093022
			-- This probably isn't the most effecient way to do it... but it's the first one I found
		end if
		
		activate
		
		display dialog "Do you want to build QuickAdd packages for specific sites in the " & selLane & " lane?" buttons {"Yes", "No Site"} default button 1
		
		if button returned of result is "No Site" then
			set siteSel to {"All Sites"}
			set siteShort to "No_Site"
		else
			set siteList to {"Site 1", "Site 2", "Site 3", "Site 4", "Site 5"}
			set siteSel to items of (choose from list siteList with prompt "Choose which sites you want to build QuickAdd packages for:" with multiple selections allowed)
		end if
		
		set mgmtUsername to ""
		set mgmtPassword to ""
		
		repeat while mgmtUsername is ""
			set mgmtUsername to text returned of (display dialog "Enter a Management Account Username: (This will be used for all packages built during this session)" default answer "")
		end repeat
		repeat while mgmtPassword is ""
			set mgmtPassword to text returned of (display dialog "Enter a Management Account Password:" default answer "" with hidden answer)
			if mgmtPassword is equal to mgmtUsername then
				set mgmtPassword to ""
				display dialog "Hey. Dude. Don't make the password the same as the username. You should know better. 👎" with icon caution buttons {"Try Again"} default button 1
			end if
		end repeat
		
		try
			set defaultPath to defaultPath & selLane & ":" as alias
		on error
			set defaultPath to (path to desktop)
		end try
		
		set saveLoc to (choose folder with prompt "Choose a location to save QuickAdd packages:" default location defaultPath)
		
		
		repeat with site in siteSel
			
			set siteShort to (do shell script "echo " & quoted form of site & " | awk '{print $1}'")
			
			set QuickAddName to "QuickAdd-" & siteShort & "-" & selLane & "Lane-" & reconVersion
			set QuickAddPath to (saveLoc as text) & QuickAddName & ".pkg"
			
			set overwriteOld to false
			try
				set QuickAddAlias to QuickAddPath as alias --If this fails then we know the file doesn't exist yet.
				try
					beep
					set buttonChoice to button returned of (display dialog "A QuickAdd package for " & site & " in the " & selLane & " lane already exists. Do you want to archive it or overwrite it?" buttons {"Archive", "Overwrite", "Cancel"} default button 1 cancel button 3 with icon caution) as text
				on error
					return
				end try
				if buttonChoice is "Archive" then
					set archiveLoc to (POSIX path of saveLoc) & "/old/"
					set archivePKG to archiveLoc & QuickAddName & "-" & (do shell script "date +%Y%m%d_%H%M%S") & ".pkg"
					set QuickAddPOSIX to POSIX path of my alias QuickAddPath
					do shell script "if [ ! -d '" & archiveLoc & "' ]; then mkdir '" & archiveLoc & "'; fi"
					do shell script "mv " & (quoted form of QuickAddPOSIX) & " " & (quoted form of archivePKG)
				else if buttonChoice is "Overwrite" then
					set overwriteOld to true
				end if
			end try
			
			
			
			tell application "Recon" to activate
			tell window 1
				tell scroll area 2
					--Enter Management Account Username
					tell (first text field whose name contains "Username")
						set focused to true
						keystroke "a" using command down
						keystroke mgmtUsername
					end tell
					
					tell pop up button 1
						click
						tell menu 1
							click menu item "Specify password"
						end tell
					end tell
					
					--Enter Management Account Password
					tell (first text field whose name contains "Password")
						set focused to true
						keystroke "a" using command down
						keystroke mgmtPassword
					end tell
					tell (second text field whose name contains "Password")
						set focused to true
						keystroke "a" using command down
						keystroke mgmtPassword
					end tell
					
					set mgmtPassword to ""
					
					-- Checkboxes
					tell (first checkbox whose name is "Create management account if it does not exist")
						if value is 0 then click
					end tell
					
					tell (first checkbox whose name is "Hide management account")
						if value is 0 then click
					end tell
					
					tell (first checkbox whose name is "Allow SSH access for management account only")
						if value is 1 then click
					end tell
					
					tell (first checkbox whose name is "Ensure SSH is enabled")
						if value is 0 then click
					end tell
					
					tell (first checkbox whose name is "Launch Self Service when done")
						if value is 1 then click
					end tell
					
					tell (first checkbox whose name is "Sign with:")
						if value is 0 then click -- NO SIGNING: change 0 to 1
					end tell
					
					tell (first checkbox whose name is "Use existing site membership, if applicable")
						if value is 1 then click
					end tell
					
					--Set certificate -- NO SIGNING: comment out or delete this tell block 
					tell pop up button 2
						click
						tell menu 1 to click menu item certName
					end tell
					
					--Set site
					tell pop up button 3
						click
						tell menu 1 to click menu item site
					end tell
					
				end tell
				
				if overwriteOld is true then
					set QuickAddPOSIX to POSIX path of my alias QuickAddPath
					do shell script "rm " & quoted form of QuickAddPOSIX
				end if
				
				click (first button whose name is "Create...")
				
				tell sheet 1
					set value of text field 1 to QuickAddName & ".pkg"
					keystroke "G" using command down --Capital G means "shift + g". Command + Shift + G is the "Go to folder" dialog box
					set value of combo box 1 of sheet 1 to (POSIX path of saveLoc as text)
					keystroke return
					set doneSaving to false
					tell button "Save" to click
				end tell
				
				tell application "Finder"
					repeat while doneSaving is false
						try
							set QuickAddAlias to QuickAddPath as alias --If this fails then we know the file doesn't exist and the script will loop back to checking for the file.
							set doneSaving to true
						on error
							delay 1
						end try
					end repeat
				end tell
				delay 1
				--tell application "Recon" to display notification "Done building " & QuickAddName & ".pkg" --Goes away too quickly to be useful
			end tell
		end repeat
	end tell
end tell

(*

These are some attempts at watching the QuickAdd file to see when it's done being written. Wasn't able to get it to work, though.

--set quickAddBusy to isBusy((my QuickAddAlias))
--repeat until quickAddBusy is false
--	set quickAddBusy to isBusy((my QuickAddAlias))
--	delay 1
--end repeat
--beep

set stillSaving to true
repeat while stillSaving is true
	try
		open for access file QuickAddAlias with write permission
		close access result
		set stillSaving to false
	on error
		set stillSaving to true
	end try
end repeat

on isBusy(f)
	(*
	Originally written by Julio. from the post macscripter.net/viewtopic.php?pid=33693#p33693
	McUsr cleaned up bad BBCode, and removed the info for command altogether
	and didnt replace it with the System Events version because he BELIEVED that to be as errant
	as the now deprecated info for command.
	https://macscripter.net/viewtopic.php?pid=130534#p130534
	
	isBusy
	Checks if you can write to a file or not (if it is opened for access by other process).
	
	Parameters:
	f: file path, alias, posix path
	
	Example:
	isBusy("path:to:file.txt") --> false
	*)
	
	set f to f as Unicode text
	if f does not contain ":" then set f to POSIX file f as Unicode text
	
	try
		open for access file f with write permission
		close access result
		return false
	on error
		return true
	end try
end isBusy
*)
