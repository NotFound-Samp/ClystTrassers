local sampev = require 'lib.samp.events'
local memory = require 'memory'
local imgui = require 'imgui'
local ffi = require "ffi"
local encoding = require "encoding"
local inicfg = require 'inicfg'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local font = renderCreateFont("Arial", 10, 1);

local directIni = 'TrassersForMarino.ini'
local ini = inicfg.load({
    state = {
        active = true, -- вкл/выкл
        cbEnd = true -- окончания линий
    },
    int = {
        timeRenderBullets = 10, -- время рендера
        sizeOffLine = 1, -- толщина линий
        sizeOffPolygonEnd = 1, -- размер окончания
        rotationPolygonEnd = 10, -- количество углов окончания
        degreePolygonEnd = 50,  -- градус поворота окончаний 
        maxLineLimit = 10 -- макс кол-во линий
    }
}, directIni) 
inicfg.save(ini, directIni)

local config = {
    state = {
        window = imgui.ImBool(false),
        active = imgui.ImBool(ini.state.active),
        cbEnd = imgui.ImBool(ini.state.cbEnd)
    },
    int = {
        timeRenderBullets = imgui.ImInt(ini.int.timeRenderBullets),
        sizeOffLine = imgui.ImInt(ini.int.sizeOffLine),
        sizeOffPolygonEnd = imgui.ImInt(ini.int.sizeOffPolygonEnd),
        rotationPolygonEnd = imgui.ImInt(ini.int.rotationPolygonEnd),
        degreePolygonEnd = imgui.ImInt(ini.int.degreePolygonEnd),
        maxLineLimit = imgui.ImInt(ini.int.maxLineLimit)
    }
}

 
local bulletSync = {lastId = 0, maxLines = config.int.maxLineLimit.v}
for i = 1, bulletSync.maxLines do
	bulletSync[i] = { other = {time = 0, t = {x,y,z}, o = {x,y,z}, type = 0, color = 0, id = -1, colorText = 0}}
end

local PLAYERS = {}
setmetatable( PLAYERS, {
	__index = function ( t, k )
		rawset( t, k, {
			last = 0,
			lines = {}
		}) 
	  return t[ k ]
	end
})

function main()
    while not isSampAvailable() do wait(0) end
        sampRegisterChatCommand('btrack', btrack)
        style()
        bulletSyncUpdate()
    while true do
        wait(0)
        local oTime = os.time()
        imgui.Process = config.state.window.v
        if config.state.active.v then
            for i = 1, bulletSync.maxLines do
                if bulletSync[i].other.time >= oTime then
                    local result, wX, wY, wZ, wW, wH = convert3DCoordsToScreenEx(bulletSync[i].other.o.x, bulletSync[i].other.o.y, bulletSync[i].other.o.z, true, true)
                    local resulti, pX, pY, pZ, pW, pH = convert3DCoordsToScreenEx(bulletSync[i].other.t.x, bulletSync[i].other.t.y, bulletSync[i].other.t.z, true, true)
                    if result and resulti then
                        local xResolution = memory.getuint32(0x00C17044)
                        if wZ < 1 then
                            wX = xResolution - wX
                        end
                        if pZ < 1 then
                            pZ = xResolution - pZ
                        end
                        renderDrawLine(wX, wY, pX, pY, config.int.sizeOffLine.v, '0x'..bulletSync[i].other.color)
                        if config.state.cbEnd.v then
                            renderDrawPolygon(pX, pY-1, 3 + config.int.sizeOffPolygonEnd.v, 3 + config.int.sizeOffPolygonEnd.v, 1 + config.int.rotationPolygonEnd.v, config.int.degreePolygonEnd.v, '0x'..bulletSync[i].other.color)
                        end
                    end
                end
            end
        end
    end
end

function bulletSyncUpdate()
    for i = 1, bulletSync.maxLines do
        bulletSync[i] = { other = {time = 0, t = {x,y,z}, o = {x,y,z}, type = 0, color = 0, id = -1, colorText = 0}}
    end
end

function imgui.OnDrawFrame()
    if config.state.window.v then
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 320, 200 -- WINDOW SIZE
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2 - sizeX / 2, resY / 2 - sizeY / 2), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('Trasser Config(/btrack)', config.state.window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
        imgui.Checkbox(u8'Отрисовка пуль', config.state.active)
        imgui.SameLine()
        imgui.Checkbox(u8'Отрисовка окончаний', config.state.cbEnd)
        imgui.PushItemWidth(118)
        imgui.SliderInt(u8'Время рендера', config.int.timeRenderBullets, 1, 50)
        imgui.SliderInt(u8'Толщина линий', config.int.sizeOffLine, 1, 10)
        imgui.SliderInt(u8'Размер окончания', config.int.sizeOffPolygonEnd, 1, 10)
        imgui.SliderInt(u8'Количество углов окончания', config.int.rotationPolygonEnd, 1, 10)
        imgui.SliderInt(u8'Градус поворота окончаний', config.int.degreePolygonEnd, 1, 180)
        if imgui.SliderInt(u8'Макс кол-во линий', config.int.maxLineLimit, 1, 30) then
            bulletSync.maxLines = config.int.maxLineLimit.v
            bulletSyncUpdate()
        end
        imgui.End()
    end
end

function btrack()
    config.state.window.v = not config.state.window.v
end

function sampev.onBulletSync(playerid, data)
    processBulletSync(playerid, data)
    if config.state.active.v then
        if data.center.x ~= 0 and data.center.y ~= 0 and data.center.z ~= 0 then
            bulletSync.lastId = bulletSync.lastId + 1
            if bulletSync.lastId < 1 or bulletSync.lastId > bulletSync.maxLines then
                bulletSync.lastId = 1
            end
            local playerColor = sampGetPlayerColor(playerid)
            bulletSync[bulletSync.lastId].other.time = os.time() + config.int.timeRenderBullets.v
            bulletSync[bulletSync.lastId].other.o.x, bulletSync[bulletSync.lastId].other.o.y, bulletSync[bulletSync.lastId].other.o.z = data.origin.x, data.origin.y, data.origin.z
            bulletSync[bulletSync.lastId].other.t.x, bulletSync[bulletSync.lastId].other.t.y, bulletSync[bulletSync.lastId].other.t.z = data.target.x, data.target.y, data.target.z
            bulletSync[bulletSync.lastId].other.color = ColorCorrection(('%0X'):format(playerColor))
        end
    end
end

function processBulletSync(id, data)
    local playerId = tonumber( id ) or isLocalPlayerID()
    local last_data = PLAYERS[ playerId ]
    last_data.last = os.clock()

    local bulletSync = { }
    while #last_data.lines >= config.int.maxLineLimit.v do
		table.remove(last_data.lines, 1)
	end

	last_data.lines[#last_data.lines + 1] = bulletSync
end

function join_argb(a, r, g, b)
    local argb = b  -- b
    argb = bit.bor(argb, bit.lshift(g, 8))  -- g
    argb = bit.bor(argb, bit.lshift(r, 16)) -- r
    argb = bit.bor(argb, bit.lshift(a, 24)) -- a
    return argb
end
        
function explode_argb(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
end
        
function argb_to_rgba(argb)
    local a, r, g, b = explode_argb(argb)
    return join_argb(r, g, b, a)
end

function ColorCorrection(string)
    if #string > 8 then
        return string:sub(#string-7, #string)
    else return string end
end

function onScriptTerminate(s)
	if s == thisScript() then
        ini.state.active = config.state.active.v
        ini.state.cbEnd = config.state.cbEnd.v
        ini.int.timeRenderBullets = config.int.timeRenderBullets.v
        ini.int.sizeOffLine = config.int.sizeOffLine.v
        ini.int.sizeOffPolygonEnd = config.int.sizeOffPolygonEnd.v
        ini.int.rotationPolygonEnd = config.int.rotationPolygonEnd.v
        ini.int.degreePolygonEnd = config.int.degreePolygonEnd.v
        ini.int.maxLineLimit = config.int.maxLineLimit.v
        inicfg.save(ini, directIni)
    end
end

function style()
    imgui.SwitchContext()
	style = imgui.GetStyle()
    colors = style.Colors
    clr = imgui.Col
    ImVec4 = imgui.ImVec4
    ImVec2 = imgui.ImVec2
    
	style.WindowRounding = 2.0
    style.WindowTitleAlign = ImVec2(0.5, 0.5)
    style.ChildWindowRounding = 2.0
    style.FrameRounding = 2.0
    style.ItemSpacing = ImVec2(5.0, 4.0)
    style.ScrollbarSize = 13.0
    style.ScrollbarRounding = 0
    style.GrabMinSize = 8.0
    style.GrabRounding = 1.0
	colors[clr.Text] = ImVec4(0.95, 0.96, 0.98, 1.00)
    colors[clr.TextDisabled] = ImVec4(0.36, 0.42, 0.47, 1.00)
    colors[clr.WindowBg] = ImVec4(0.11, 0.15, 0.17, 1.00)
    colors[clr.ChildWindowBg] = ImVec4(0.15, 0.18, 0.22, 1.00)
    colors[clr.PopupBg] = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.Border] = ImVec4(1, 1, 1, 0.5)
    colors[clr.BorderShadow] = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.FrameBg] = ImVec4(0.20, 0.25, 0.29, 1.00)
    colors[clr.FrameBgHovered] = ImVec4(0.12, 0.20, 0.28, 1.00)
    colors[clr.FrameBgActive] = ImVec4(0.09, 0.12, 0.14, 1.00)
    colors[clr.TitleBg] = ImVec4(0.09, 0.12, 0.14, 0.65)
    colors[clr.TitleBgCollapsed] = ImVec4(0.00, 0.00, 0.00, 0.51)
    colors[clr.TitleBgActive] = ImVec4(0.08, 0.10, 0.12, 1.00)
    colors[clr.ScrollbarBg] = ImVec4(0.02, 0.02, 0.02, 0.39)
    colors[clr.ScrollbarGrab] = ImVec4(0.20, 0.25, 0.29, 1.00)
    colors[clr.ScrollbarGrabHovered] = ImVec4(0.18, 0.22, 0.25, 1.00)
    colors[clr.ScrollbarGrabActive] = ImVec4(0.09, 0.21, 0.31, 1.00)
    colors[clr.Button] = ImVec4(0.20, 0.25, 0.29, 1.00)
    colors[clr.ButtonHovered] = ImVec4(0.52, 0.2, 0.92, 1.00)
    colors[clr.ButtonActive] = ImVec4(0.60, 0.2, 1.00, 1.00)
    colors[clr.ComboBg] = ImVec4(0.20, 0.20, 0.20, 0.70)
    colors[clr.CheckMark] = ImVec4(0.52, 0.2, 0.92, 1.00)
    colors[clr.SliderGrab] = ImVec4(0.52, 0.2, 0.92, 1.00)
    colors[clr.SliderGrabActive] = ImVec4(0.60, 0.2, 1.00, 1.00)
    colors[clr.ResizeGrip] = ImVec4(0.26, 0.59, 0.98, 0.25)
    colors[clr.ResizeGripHovered] = ImVec4(0.26, 0.59, 0.98, 0.67)
    colors[clr.ResizeGripActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.CloseButton] = ImVec4(0.40, 0.39, 0.38, 0.16)
    colors[clr.CloseButtonHovered] = ImVec4(0.40, 0.39, 0.38, 0.39)
    colors[clr.CloseButtonActive] = ImVec4(0.40, 0.39, 0.38, 1.00)
    colors[clr.TextSelectedBg] = ImVec4(0.20, 0.25, 0.29, 1.00)
end