-- ---------------------------------------------------------------------------
-- Create the Edit menu and attach the callback functions

local frame    = ide.frame
local menuBar  = frame.menuBar

local editMenu = wx.wxMenu{
		{ ID_CUT,       "Cu&t\tCtrl-X",        "Cut selected text to clipboard" },
		{ ID_COPY,      "&Copy\tCtrl-C",       "Copy selected text to the clipboard" },
		{ ID_PASTE,     "&Paste\tCtrl-V",      "Insert clipboard text at cursor" },
		{ ID_SELECTALL, "Select A&ll\tCtrl-A", "Select all text in the editor" },
		{ },
		{ ID_UNDO,      "&Undo\tCtrl-Z",       "Undo the last action" },
		{ ID_REDO,      "&Redo\tCtrl-Y",       "Redo the last action undone" },
		{ },
		{ ID "edit.showtooltip",  "Show &Tooltip\tCtrl+T",			"Show tooltip for current position. Place cursor after opening bracket of function."},
		{ ID_AUTOCOMPLETE,        "Complete &Identifier\tCtrl+K", "Complete the current identifier" },
		{ ID_AUTOCOMPLETE_ENABLE, "Auto complete Identifiers",    "Auto complete while typing", wx.wxITEM_CHECK },
		{ },
		{ ID_COMMENT, "C&omment/Uncomment\tCtrl-Q", "Comment or uncomment current or selected lines"},
		{ },
		{ ID_FOLD,    "&Fold/Unfold all\tF12", "Fold or unfold all code folds"} }
menuBar:Append(editMenu, "&Edit")

editMenu:Check(ID_AUTOCOMPLETE_ENABLE, ide.config.autocomplete)

function OnUpdateUIEditMenu(event) -- enable if there is a valid focused editor
	local editor = GetEditor()
	event:Enable(editor ~= nil)
end

local shellboxeditor = ide.frame.vsplitter.splitter.bottomnotebook.shellbox.input
function OnEditMenu(event)
		
	local menu_id = event:GetId()
	local editor = GetEditor()
	if shellboxeditor:FindFocus():GetId() == shellboxeditor:GetId() then
		editor = shellboxeditor
	end
	if editor == nil then return end

	if     menu_id == ID_CUT       then editor:Cut()
	elseif menu_id == ID_COPY      then editor:Copy()
	elseif menu_id == ID_PASTE     then editor:Paste()
	elseif menu_id == ID_SELECTALL then editor:SelectAll()
	elseif menu_id == ID_UNDO      then editor:Undo()
	elseif menu_id == ID_REDO      then editor:Redo()
	end
end

frame:Connect(ID_CUT, wx.wxEVT_COMMAND_MENU_SELECTED, OnEditMenu)
frame:Connect(ID_CUT, wx.wxEVT_UPDATE_UI, OnUpdateUIEditMenu)

frame:Connect(ID_COPY, wx.wxEVT_COMMAND_MENU_SELECTED, OnEditMenu)
frame:Connect(ID_COPY, wx.wxEVT_UPDATE_UI, OnUpdateUIEditMenu)

frame:Connect(ID_PASTE, wx.wxEVT_COMMAND_MENU_SELECTED, OnEditMenu)
frame:Connect(ID_PASTE, wx.wxEVT_UPDATE_UI,
		function (event)
			local editor = GetEditor()
			-- buggy GTK clipboard runs eventloop and can generate asserts
			event:Enable(editor and (wx.__WXGTK__ or editor:CanPaste()))
		end)

frame:Connect(ID_SELECTALL, wx.wxEVT_COMMAND_MENU_SELECTED, OnEditMenu)
frame:Connect(ID_SELECTALL, wx.wxEVT_UPDATE_UI, OnUpdateUIEditMenu)

frame:Connect(ID_UNDO, wx.wxEVT_COMMAND_MENU_SELECTED, OnEditMenu)
frame:Connect(ID_UNDO, wx.wxEVT_UPDATE_UI,
		function (event)
			local editor = GetEditor()
			event:Enable(editor and editor:CanUndo())
		end)

frame:Connect(ID_REDO, wx.wxEVT_COMMAND_MENU_SELECTED, OnEditMenu)
frame:Connect(ID_REDO, wx.wxEVT_UPDATE_UI,
		function (event)
			local editor = GetEditor()
			event:Enable(editor and editor:CanRedo())
		end)
		
frame:Connect(ID "edit.showtooltip", wx.wxEVT_COMMAND_MENU_SELECTED,
		function (event)
			local editor = GetEditor()
				local pos = editor:GetCurrentPos()
				local line = editor:GetCurrentLine()
				local linetx = editor:GetLine(line)
				local linestart = editor:PositionFromLine(line)
				local localpos = pos-linestart
				
				linetxtopos = linetx:sub(1,localpos)
				
				local tip = GetTipInfo(editor,linetxtopos)
				if tip then
					editor:CallTipShow(pos,tip)
				end
		end)

frame:Connect(ID_AUTOCOMPLETE, wx.wxEVT_COMMAND_MENU_SELECTED,
		function (event)
			local editor = GetEditor()
			if (editor == nil) then return end
			
			-- retrieve the current line and get a string to the current cursor position in the line
			local pos = editor:GetCurrentPos()
			local line = editor:GetCurrentLine()
			local linetx = editor:GetLine(line)
			local linestart = editor:PositionFromLine(line)
			local localpos = pos-linestart
			
			local acstart = 1
			local state = ""
			for i=localpos,1,-1 do -- find out what should be completed
				local c = linetx:sub(i,i)
				if c : match "[%s]" and state~="begin" then 
					state = "space"
				elseif c : match "[_0-9a-zA-Z]" then
					if state == "space" then
						acstart = i+1
						break
					end
					state = "word"
				elseif c : match "[%.:]" then
					state = "begin"
				elseif c : match "[^%s]" then -- unknown char
					acstart = i + 1
					break
				end
			end
			
			local complete = linetx:sub(acstart,localpos) : gsub("%s","")
			-- know now which string is to be completed
			
			--DisplayOutput("> "..complete.."\n")
			
			local userList = CreateAutoCompList(editor.api,complete)
			if userList and string.len(userList) > 0 then
				editor:UserListShow(1, userList)
				--ShowList(userList)
			end
		end)
frame:Connect(ID_AUTOCOMPLETE, wx.wxEVT_UPDATE_UI, OnUpdateUIEditMenu)

frame:Connect(ID_AUTOCOMPLETE_ENABLE, wx.wxEVT_COMMAND_MENU_SELECTED,
		function (event)
			ide.config.autocomplete = event:IsChecked()
		end)

frame:Connect(ID_COMMENT, wx.wxEVT_COMMAND_MENU_SELECTED,
		function (event)
			local editor = GetEditor()
			local buf = {}
			if editor:GetSelectionStart() == editor:GetSelectionEnd() then
				local lineNumber = editor:GetCurrentLine()
				editor:SetSelection(editor:PositionFromLine(lineNumber), editor:GetLineEndPosition(lineNumber))
			end
			local lc = editor.spec.linecomment
			for line in string.gmatch(editor:GetSelectedText()..'\n', "(.-)\r?\n") do
				if string.sub(line,1,2) == lc then
					line = string.sub(line,3)
				else
					line = lc..line
				end
				table.insert(buf, line)
			end
			editor:ReplaceSelection(table.concat(buf,"\n"))
		end)
frame:Connect(ID_COMMENT, wx.wxEVT_UPDATE_UI, OnUpdateUIEditMenu)


frame:Connect(ID_FOLD, wx.wxEVT_COMMAND_MENU_SELECTED,
		function (event)
			FoldSome()
		end)
frame:Connect(ID_FOLD, wx.wxEVT_UPDATE_UI, OnUpdateUIEditMenu)

