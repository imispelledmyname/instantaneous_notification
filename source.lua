type table = {
	[any]: any
}

local Targets = {
	["Master Sprinkler"] = true,
	["Tanning Mirror"] = true,
	["Sugar Apple"] = true,
	["Paradise Egg"] = true,
	["Lightning Rod"] = true
}

local WeatherTargets = {
	["Thunderstorm"] = true,
	["Heatwave"] = true
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = cloneref(game:GetService("HttpService"))
local VirtualUser = cloneref(game:GetService("VirtualUser"))
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

RunService:Set3dRenderingEnabled(false)

if _G.StockBot then return end
_G.StockBot = true

local Webhook = ""
local WebhookWeather = ""

local AlertLayouts = {
	["SeedsAndGears"] = {
		Color = 0x38EE17,
		Layout = {
			["ROOT/SeedStock/Stocks"] = "SEEDS",
			["ROOT/GearStock/Stocks"] = "GEARS"
		}
	},
	["EventShop"] = {
		Color = 0xFF2A4A,
		Layout = {
			["ROOT/EventShopStock/Stocks"] = "EVENT SHOP"
		}
	},
	["Eggs"] = {
		Color = 0xD42AFF,
		Layout = {
			["ROOT/PetEggStock/Stocks"] = "EGG SHOP"
		}
	},
	["CosmeticStock"] = {
		Color = 0xFBFF0E,
		Layout = {
			["ROOT/CosmeticStock/ItemStocks"] = "COSMETICS SHOP"
		}
	}
}

local PathToLayoutName = {
	["ROOT/SeedStock/Stocks"] = "SeedsAndGears",
	["ROOT/GearStock/Stocks"] = "SeedsAndGears",
	["ROOT/EventShopStock/Stocks"] = "EventShop",
	["ROOT/PetEggStock/Stocks"] = "Eggs",
	["ROOT/CosmeticStock/ItemStocks"] = "CosmeticStock"
}

local DataStream = ReplicatedStorage.GameEvents.DataStream
local WeatherEventStarted = ReplicatedStorage.GameEvents.WeatherEventStarted

local function WebhookSend(Type: string, Fields: table, Color: number?, Url)
	Url = Url or Webhook
	local Body = {
		embeds = {{
			color = Color or 16777215,
			fields = Fields
		}}
	}
	task.spawn(function()
		HttpService:RequestAsync({
			Url = Url,
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = HttpService:JSONEncode(Body)
		})
	end)
end

local function SendPing(Url: string, Content: string)
	task.spawn(function()
		HttpService:RequestAsync({
			Url = Url,
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = HttpService:JSONEncode({ content = Content })
		})
	end)
end

local function GetDataPacket(Data, Target: string)
	for _, Packet in Data do
		local Name = Packet[1]
		local Content = Packet[2]
		if Name == Target then
			return Content
		end
	end
end

local function MakeStockString(Stock: table)
	local String = {}
	local HitTargets = {}
	for Name, Data in Stock do
		local Amount = Data.Stock
		local EggName = Data.EggName
		Name = EggName or Name
		if Targets[Name] then
			HitTargets[#HitTargets + 1] = Name
		end
		String[#String + 1] = Name .. ": **x" .. Amount .. "**\n"
	end
	return table.concat(String), HitTargets
end

local function ProcessPacket(Data, Type: string, Layout)
	local Fields = {}
	local HitTargets = {}
	local FieldsLayout = Layout.Layout
	if not FieldsLayout then return end

	for Packet, Title in FieldsLayout do
		local Stock = GetDataPacket(Data, Packet)
		if Stock then
			local StockString, TargetsHit = MakeStockString(Stock)
			HitTargets = TargetsHit
			table.insert(Fields, {
				name = Title,
				value = StockString,
				inline = true
			})
		end
	end

	WebhookSend(Type, Fields, Layout.Color)

	if #HitTargets > 0 then
		SendPing(Webhook, "@everyone " .. table.concat(HitTargets, ", "))
	end
end

DataStream.OnClientEvent:Connect(function(Type: string, Profile: string, Data: table)
	if Type ~= "UpdateData" then return end
	if not Profile:find(LocalPlayer.Name) then return end

	local LayoutsToProcess = {}

	for _, Packet in ipairs(Data) do
		local Path = Packet[1]
		local LayoutName = PathToLayoutName[Path]
		if LayoutName then
			LayoutsToProcess[LayoutName] = true
		end
	end

	for LayoutName in pairs(LayoutsToProcess) do
		ProcessPacket(Data, LayoutName, AlertLayouts[LayoutName])
	end
end)

WeatherEventStarted.OnClientEvent:Connect(function(Event: string, Length: number)
	local ServerTime = math.round(workspace:GetServerTimeNow())
	local EndUnix = ServerTime + Length
	WebhookSend("Weather", {{
		name = "WEATHER",
		value = "**" .. Event .. "** has started!\nends <t:" .. EndUnix .. ":R>",
		inline = true
	}}, 0x2AFFDB, WebhookWeather)

	if WeatherTargets[Event] then
		SendPing(WebhookWeather, "@everyone " .. Event)
	end
end)

LocalPlayer.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)
