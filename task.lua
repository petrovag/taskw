
local awful = require("awful")
local wibox=require("wibox") 
local gears = require("gears")

----------------------------
-- Zulu time to Unix time --
----------------------------
function zulu2time (iso)
	local year, monts, day, hour, min, sec = string.match(iso,"(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)(%d%d)Z")
	return os.time({year=tonumber(year), month=tonumber(monts), day=tonumber(day), hour=tonumber(hour), min=tonumber(min), sec=tonumber(sec)})
end


------------------------------------------
-- Set colors for the contexts of tasks --
------------------------------------------
local tagcolor = {}
function taskcontextes(colorscheme)
	local file = io.popen("task context list")
	local l
	for i=1,3 do
		l=file:read("*line")
	end
	local tab = l:find("%s")
	-- print(tab)
	local nextline = file:read("*line")
	while ( nextline ) do -- contexts loop
		for i=1,2 do -- read/write loop
			l=nextline:sub(1,string.len(nextline)-3)
			nextline = file:read("*line")
			while ( nextline ) do -- long line concat loop
				if string.match(nextline:sub(1,tab+5),"%S") == nil then
					l=l..nextline:sub(tab+5)
					nextline = file:read("*line")
				else
					break
				end
			end
			-- print(">>",l)
			if i == 1 then
				contextname = string.match(string.sub(l,1,tab),"%S+")
			end
			local rw = string.match(string.sub(l,tab),"%w+")
			l=string.sub(l,tab+5)
			for tag in string.gmatch(l, "[+](%S+)") do tagcolor[tag]=colorscheme[contextname] end
			for project in string.gmatch(l, "roject:(%S+)") do tagcolor[project]=colorscheme[contextname] end
			-- print(">",nextline)
		end
	end
end

taskcontextes({Loh = '#FF2222', Science = '#4444FF', hardandsoft = '#666666', rest = '#00FF00' })


------------------------------------------
-- Build widget                         --
------------------------------------------
function wtask()
	local worktime = 60
	local widget = wibox.widget{
		{   
			id		= "taskname",
			text   = "<>",
			align  = "center",
			valign = "center", 
			ellipsize = "none",
			widget = wibox.widget.textbox,
			set_taskname = function(self, val)
				print("1:"..val)
				self.text  = val
			end,
		},
		id		= "taskcontainer",
		border_color = "#111111",
		color		 = "#00FF00",
		border_width =	2,
		value     = 0,
		v		= 10,
		max_value = 60,
		min_value = 00,
		widget    = wibox.container.radialprogressbar,
		set_taskcontainer = function(self, val)
				-- {"id":1,"start":"20230126T111903Z","tags":["droplet","plasmon","Точная поправка к энергии плазмона, вызванная поверхностными диполями"]}
				if type(worktime) == "nil" then
					worktime = 60
				end
				self.max_value	= worktime
				if type(val) == "table" then
					self.v = math.floor(os.difftime(os.time(os.date("!*t",os.time())),zulu2time(val.start))/60)
					title=val.tags[#val.tags]
					for i, v in ipairs(val.tags) do 
						print(i,v)
						if string.match(v,"(%s)") == " " then 
							title = v
							print("set ",v)
						end
						if tagcolor[v] ~= nil	then
							self.color = tagcolor[v]
							color = tagcolor[v]
							-- print( tagcolor[v],color,self.color)
						end
					end
					self.max_value	=	worktime
					print("!!!",worktime)
					if type(val["end"]) == "string" then	-- Not active
						worktime		=	math.floor(os.difftime(zulu2time(val["end"]),zulu2time(val.start))/60)
						self.color		=	"#00FF00"
						self.taskname.markup = string.format("<span foreground='grey'>%s %3d/%3d </span>",title,self.v,worktime)
					else									-- Active 
						self.taskname.markup = string.format("<span foreground='"..(string.gsub(self.color,"[0-4]","6")).."'>%s %3d/%3d </span>",title,self.v,worktime)
					end
				else
					self.taskname.markup = string.format("<span foreground='grey'>%s %3d/%3d </span> ",title,self.v,worktime)
					self.max_value	= worktime
				end
				self.value = self.v
		end,
	}

	---------------------
	-- Buttons signals --
	---------------------
	widget:connect_signal("button::press", 
		function(self, lx, ly, button, mods, meta)
			if button == 4 then
				worktime=worktime+5
				widget.taskcontainer=''
				print(worktime)
			elseif  button == 5 then
				worktime=worktime-5
				widget.taskcontainer=''
				print(worktime)
			end
		end
	)

	------------------
	-- Set timer    --
	------------------
	gears.timer {
		timeout   = 60,
		call_now  = true,
		autostart = true,
		callback  = function()
			awful.spawn.easy_async(--{"timew"},
				{"timew", "get", "dom.active.json"},
				function(stdout, stderr, reason, exit_code)
					if string.len(stdout) <2 then
						awful.spawn.easy_async({"timew", "get", "dom.tracked.1.json"},
						function(stdout, stderr, reason, exit_code)
							-- widget.rest = json.decode(stdout)
							widget.taskcontainer = json.decode(stdout)
						end
					)
					else
						widget.taskcontainer = json.decode(stdout)
					end
				end
			)
		end
	}

	return widget
end 
