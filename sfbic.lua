script_name('sfbi-script')
script_version('0.0.1')
script_author('Разработчик: William Raines. Отдельная благодарность: Donny Provenzano, Gabriel Marques и Kevin Norberg')
script_properties('work-in-pause')

local console = {}

function console.table(node)
   local cache, stack, output = {},{},{}
   local depth = 1
   local output_str = "{\n"

   while true do
       local size = 0
       for k,v in pairs(node) do
           size = size + 1
       end

       local cur_index = 1
       for k,v in pairs(node) do
           if (cache[node] == nil) or (cur_index >= cache[node]) then

               if (string.find(output_str,"}",output_str:len())) then
                   output_str = output_str .. ",\n"
               elseif not (string.find(output_str,"\n",output_str:len())) then
                   output_str = output_str .. "\n"
               end

               -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
               table.insert(output,output_str)
               output_str = ""

               local key
               if (type(k) == "number" or type(k) == "boolean") then
                   key = "["..tostring(k).."]"
               else
                   key = "['"..tostring(k).."']"
               end

               if (type(v) == "number" or type(v) == "boolean") then
                   output_str = output_str .. string.rep('\t',depth) .. key .. " = "..tostring(v)
               elseif (type(v) == "table") then
                   output_str = output_str .. string.rep('\t',depth) .. key .. " = {\n"
                   table.insert(stack,node)
                   table.insert(stack,v)
                   cache[node] = cur_index+1
                   break
               else
                   output_str = output_str .. string.rep('\t',depth) .. key .. " = '"..tostring(v).."'"
               end

               if (cur_index == size) then
                   output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
               else
                   output_str = output_str .. ","
               end
           else
               -- close the table
               if (cur_index == size) then
                   output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
               end
           end

           cur_index = cur_index + 1
       end

       if (size == 0) then
           output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
       end

       if (#stack > 0) then
           node = stack[#stack]
           stack[#stack] = nil
           depth = cache[node] == nil and depth + 1 or depth - 1
       else
           break
       end
   end

   -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
   table.insert(output,output_str)
   output_str = table.concat(output)

   print(output_str)
end

sampev = require 'lib.samp.events'
encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8
imgui = require 'imgui'
keys = require 'vkeys'


local chat = {}

function chat.sendMessage(text)
  sampAddChatMessage(string.format('[SWAT FBI] {ffffff}%s', text), 0x363636);
end

function chat.sendWarning(text)
  sampAddChatMessage(string.format('[SWAT FBI {a11212}Предупреждение{363636}] {ffffff}%s', text), 0x363636);
end

function chat.sendHeader(text)
  sampAddChatMessage(' ' .. text, 0xFF1A8F04)
end

function chat.sendEmployee(id, name, rank, duty, position)
  onDuty = false;
  if not position then
    position = 'Operative Officer'
  end
  if duty == 'На работе' then
    onDuty = true
    return sampAddChatMessage(string.format('# {9C3848}[%s] {ffffff}%s {9C3848}: {ffffff}%s {9C3848}|{ffffff} %s', id, name, rank, position), -1);
  end
  return sampAddChatMessage(string.format('# {9C3848}[%s] {ffffff}%s {9C3848}: {ffffff}%s {9C3848}|{ffffff} %s {ed0713}[!] Прогул', id, name, rank, position), 0x1e90ff);
end

function chat.sendSquadmate(id, name, callsign, rank, organization, position)
  return sampAddChatMessage(string.format('{9C3848}ID: %s {ffffff}%s {9C3848}: {ffffff}%s {9C3848}|{ffffff} %s ', id, name, callsign, organization) .. string.format('{9C3848}|{ffffff} %s {9C3848}|{ffffff} %s', rank, position), -1);
end

function chat.showIRCMessage(user, channel, message, squad_name, ooc)
  if (string.match(message, '(( %. ))')) or ooc then
    return sampAddChatMessage(string.format('{363636}%s {ffffff}| %s: (( %s ))', squad_name, user, message), -1)
  end
  sampAddChatMessage(string.format('{363636}%s {a11212}[Рация] {ffffff}| %s: %s', squad_name, user, message), -1)
end

function chat.sendSpace()
  sampAddChatMessage(' ', -1);
end


-- Autoupdate

function autoupdate(json_url, prefix, url)
  local dlstatus = require('moonloader').download_status
  local json = getWorkingDirectory() .. '\\'..thisScript().name..'-version.json'
  if doesFileExist(json) then os.remove(json) end
  downloadUrlToFile(json_url, json,
    function(id, status, p1, p2)
      if status == dlstatus.STATUSEX_ENDDOWNLOAD then
        if doesFileExist(json) then
          local f = io.open(json, 'r')
          if f then
            local info = decodeJson(f:read('*a'))
            updatelink = info.updateurl
            updateversion = info.latest
            f:close()
            os.remove(json)
            if updateversion ~= thisScript().version then
              lua_thread.create(function(prefix)
                local dlstatus = require('moonloader').download_status
                local color = -1
                chat.sendMessage((prefix..'Обнаружено обновление. Пытаюсь обновиться c '..thisScript().version..' на '..updateversion), color)
                wait(250)
                downloadUrlToFile(updatelink, thisScript().path,
                  function(id3, status1, p13, p23)
                    if status1 == dlstatus.STATUS_DOWNLOADINGDATA then
                      print(string.format('Загружено %d из %d.', p13, p23))
                    elseif status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
                      print('Загрузка обновления завершена.')
                      chat.sendMessage((prefix..'Обновление завершено! Пожалуйста подождите, скрипт перезагрузится через 20с.'), color)
                      goupdatestatus = true
                      lua_thread.create(function() wait(500) thisScript():reload() end)
                    end
                    if status1 == dlstatus.STATUSEX_ENDDOWNLOAD then
                      if goupdatestatus == nil then
                        chat.sendMessage((prefix..'Обновление прошло неудачно. Запускаю устаревшую версию..'), color)
                        update = false
                      end
                    end
                  end
                )
                end, prefix
              )
            else
              update = false
              print('v'..thisScript().version..': Обновление не требуется.')
            end
          end
        else
          print('v'..thisScript().version..': Не могу проверить обновление. Смиритесь или проверьте самостоятельно на '..url)
          update = false
        end
      end
    end
  )
  while update ~= false do wait(100) end
end


-- Autoupdate end


-- Utils

local _table = {}

function _table.getTableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function _table.filterByNickname(filteredMembers)
  local out = {}
  local staffList = _staff[1]
  local leadershipList = _leadership[1]
  for key, employee in pairs(filteredMembers) do
    if staffList:find(employee.nickname) then
      if leadershipList:find(employee.nickname) then
        tmp1 = string.match(leadershipList, employee.nickname .. ' | %a+%.?%a+')
        tmp2 = string.match(tmp1, '| %a+%.?%a+')
        position = string.match(tmp2, '%a+%.?%a+')
        employee['position'] = position
      end
      table.insert(out, employee)
    end
  end
  return out
end

function _table.filterSquad(filteredMembers)
  local out = {}
  local squadList = u8:decode(_squad[1])
  local squadmates = {}
  for s in squadList:gmatch("[^\r\n]+") do
    table.insert(squadmates, s)
  end
  
  for key, employee in pairs(filteredMembers) do
    for key, squadmate in pairs(squadmates) do
      if squadmate:find(employee.nickname) then
        _callsign = string.match(squadmate, '| %[[А-Яа-я]+%]')
        callsign = string.match(_callsign, '[А-Яа-я]+')
        _organization = string.match(squadmate, '| %a%a%a?%a')
        organization = string.match(_organization, '%a%a%a?%a')
        _position = string.match(squadmate, '%([А-Яа-я]+%.?[А-Яа-я]+%)')
        position = string.match(_position, '[А-Яа-я]+%.?[А-Яа-я]+')
        _rank = string.match(squadmate, '| [А-Яа-я]+%.?[А-Яа-я]+')
        rank = string.match(_rank, '[А-Яа-я]+%.?[А-Яа-я]+')
        
        employee['callsign'] = callsign
        employee['organization'] = organization
        employee['rank'] = rank
        employee['position'] = position
        table.insert(out, employee)
      end
    end
  end
  return out
end

local network = {}

function network.get(link)
  local https = require('ssl.https')
  https.TIMEOUT = 10
  local resp = {}
  local body, code, headers = https.request{ url = link, headers = { ['Connection'] = 'close' }, sink = ltn12.sink.table(resp) }   
  if code~=200 then 
    print("Error: ".. (code or '') ) 
    return false
  end
  print("Status:", body and "OK" or "FAILED")
  print("Данные успешно загружены | ", code)
  return resp
end


-- Interface

local commandHandlers = {}
local staff = {}
local sw, sh = getScreenResolution()

-- Variables (Flags)

local is_genRule = false
local is_wtInfo = false
local is_reportRules = false
local is_priorityTasks = false
local is_sfbiAllowedToDo = false

local is_codeFromStaff = false
local is_codeFromSquadmate = false

local is_protocol = false

-- Addons

function imgui.TextColoredRGB(text)
  local style = imgui.GetStyle()
  local colors = style.Colors
  local ImVec4 = imgui.ImVec4

  local explode_argb = function(argb)
      local a = bit.band(bit.rshift(argb, 24), 0xFF)
      local r = bit.band(bit.rshift(argb, 16), 0xFF)
      local g = bit.band(bit.rshift(argb, 8), 0xFF)
      local b = bit.band(argb, 0xFF)
      return a, r, g, b
  end

  local getcolor = function(color)
      if color:sub(1, 6):upper() == 'SSSSSS' then
          local r, g, b = colors[1].x, colors[1].y, colors[1].z
          local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
          return ImVec4(r, g, b, a / 255)
      end
      local color = type(color) == 'string' and tonumber(color, 16) or color
      if type(color) ~= 'number' then return end
      local r, g, b, a = explode_argb(color)
      return imgui.ImColor(r, g, b, a):GetVec4()
  end

  local render_text = function(text_)
      for w in text_:gmatch('[^\r\n]+') do
          local text, colors_, m = {}, {}, 1
          w = w:gsub('{(......)}', '{%1FF}')
          while w:find('{........}') do
              local n, k = w:find('{........}')
              local color = getcolor(w:sub(n + 1, k - 1))
              if color then
                  text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                  colors_[#colors_ + 1] = color
                  m = n
              end
              w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
          end
          if text[0] then
              for i = 0, #text do
                  imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                  imgui.SameLine(nil, 0)
              end
              imgui.NewLine()
          else imgui.Text(u8(w)) end
      end
  end

  render_text(text)
end

function imgui.CenterTextColoredRGB(text)
  local width = imgui.GetWindowWidth()
  local style = imgui.GetStyle()
  local colors = style.Colors
  local ImVec4 = imgui.ImVec4

  local explode_argb = function(argb)
      local a = bit.band(bit.rshift(argb, 24), 0xFF)
      local r = bit.band(bit.rshift(argb, 16), 0xFF)
      local g = bit.band(bit.rshift(argb, 8), 0xFF)
      local b = bit.band(argb, 0xFF)
      return a, r, g, b
  end

  local getcolor = function(color)
      if color:sub(1, 6):upper() == 'SSSSSS' then
          local r, g, b = colors[1].x, colors[1].y, colors[1].z
          local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
          return ImVec4(r, g, b, a / 255)
      end
      local color = type(color) == 'string' and tonumber(color, 16) or color
      if type(color) ~= 'number' then return end
      local r, g, b, a = explode_argb(color)
      return imgui.ImColor(r, g, b, a):GetVec4()
  end

  local render_text = function(text_)
      for w in text_:gmatch('[^\r\n]+') do
          local textsize = w:gsub('{.-}', '')
          local text_width = imgui.CalcTextSize(u8(textsize))
          imgui.SetCursorPosX( width / 2 - text_width .x / 2 )
          local text, colors_, m = {}, {}, 1
          w = w:gsub('{(......)}', '{%1FF}')
          while w:find('{........}') do
              local n, k = w:find('{........}')
              local color = getcolor(w:sub(n + 1, k - 1))
              if color then
                  text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                  colors_[#colors_ + 1] = color
                  m = n
              end
              w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
          end
          if text[0] then
              for i = 0, #text do
                  imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                  imgui.SameLine(nil, 0)
              end
              imgui.NewLine()
          else
              imgui.Text(u8(w))
          end
      end
  end
  render_text(text)
end

-- Addons end


-- Custom imgui

function apply_custom_style()
  imgui.SwitchContext()
  local style = imgui.GetStyle()
  style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
end
apply_custom_style()

function imgui.ButtonHex(lable, rgb, size)
  local r = bit.band(bit.rshift(rgb, 16), 0xFF) / 255
  local g = bit.band(bit.rshift(rgb, 8), 0xFF) / 255
  local b = bit.band(rgb, 0xFF) / 255

  imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(r, g, b, 0.6))
  imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(r, g, b, 0.8))
  imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(r, g, b, 1.0))
  local button = imgui.Button(lable, size)
  imgui.PopStyleColor(3) 
  return button
end


-- Custom imgui end

function commandHandlers.copyDataToImgui(_staff)
  staff = _staff
end

function imgui.OnDrawFrame()
  if not main_window_state.v and not members_window_state.v then
    imgui.Process = false
  end

  if members_window_state.v then
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(800, 400), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'[S-FBI] Список сотрудников | Всего в сети: ' .. #staff, members_window_state, imgui.WindowFlags.NoResize)
    imgui.Columns(6, 'Squadmates info', true)
    imgui.TextColoredRGB('{20d400}ID')
    for key, squadmate in pairs(staff) do 
      imgui.TextColoredRGB('{1b7507}' .. squadmate.id)
    end
    imgui.NextColumn()
    imgui.TextColoredRGB('{B81E56}Никнейм')
    for key, squadmate in pairs(staff) do
      if squadmate.nickname == 'William_Raines' then
      imgui.TextColoredRGB('{342dfa}' .. squadmate.nickname .. '{fa2d3e} +')
      else
        imgui.Text(u8(squadmate.nickname))
      end
    end
    imgui.NextColumn()
    imgui.TextColoredRGB('{de0012}Позывной')
    for key, squadmate in pairs(staff) do 
      imgui.Text(u8(squadmate.callsign))
    end
    imgui.NextColumn()
    imgui.TextColoredRGB('{e4f500}Организация')
    for key, squadmate in pairs(staff) do 
      if squadmate.organization:find('PD') then
        imgui.TextColoredRGB('{0400ff}' .. squadmate.organization)
      elseif squadmate.organization == 'FBI' then
        imgui.TextColoredRGB('{2b2b2b}' .. squadmate.organization)
      else
        imgui.TextColoredRGB('{376110}' .. squadmate.organization)
      end
    end
    imgui.NextColumn()
    imgui.TextColoredRGB('{e4f500}Звание')
    for key, squadmate in pairs(staff) do 
      imgui.Text(u8(squadmate.rank))
    end
    imgui.NextColumn()
    imgui.TextColoredRGB('{ff4b19}Должность')
    imgui.Separator()
    for key, squadmate in pairs(staff) do 
      imgui.Text(u8(squadmate.position))
    end
    imgui.End()
  end

  if main_window_state.v then
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(300, 300), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'SWAT FBI | Главное меню | Версия: 0.0.1', main_window_state, imgui.WindowFlags.NoResize)
    if imgui.ButtonHex(u8'Команды скрипта', 0x6468e8, imgui.ImVec2(285, 0)) then
      commandHandlers.renderS_C()
    end
    if imgui.ButtonHex(u8'Информация для стажёров', 0x6468e8, imgui.ImVec2(285, 0)) then
      commandHandlers.renderIFT()
    end
    if imgui.ButtonHex(u8'Тен-коды', 0x6468e8, imgui.ImVec2(285, 0)) then
      commandHandlers.renderCodes()
    end
    if imgui.ButtonHex(u8'Отыгровки', 0x6468e8, imgui.ImVec2(285, 0)) then
      commandHandlers.renderActings()
    end
    if imgui.ButtonHex(u8'Протокол', 0x6468e8, imgui.ImVec2(285, 0)) then
      commandHandlers.renderProtocol()
    end
    imgui.CenterTextColoredRGB('{ff0000}[!]{ffffff} Тестовый режим')
    imgui.CenterTextColoredRGB('{ff0000}[!]{ffffff} Если нашли баг: {4C75A3}vk.com/w.raines')
    imgui.CenterTextColoredRGB('{ff0000}[+]{ffffff} Автор скрипта: William_Raines')
    imgui.End()
  end

  if s_c_window_state.v then
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(350, 200), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'SWAT FBI | Команды скрипта | Версия: 0.0.1', s_c_window_state, imgui.WindowFlags.NoResize)
    imgui.CenterTextColoredRGB('{ff0000}/cv{ffffff} - Говорить в шифрованный канал')
    imgui.CenterTextColoredRGB('{ff0000}/cb{ffffff} - OOC шифр.канал')
    imgui.CenterTextColoredRGB('{ff0000}/getsquad{ffffff} - Список игроков онлайн')
    imgui.CenterTextColoredRGB('{ff0000}/sfbi{ffffff} - Вызвать меню скрипта')
    imgui.CenterTextColoredRGB('{ff0000}Клавиша «U»{ffffff} - Вызвать меню скрипта')
    imgui.End()
  end

  if ift_window_state.v then
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(1150, 500), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'SWAT FBI | Информация для стажёров | Версия: 0.0.1', ift_window_state, imgui.WindowFlags.NoResize)
    imgui.BeginChild('Selectors', imgui.ImVec2(230, 450), true)
      if imgui.Selectable(u8'Общее положение', is_genRule) then
        is_genRule = true
        is_wtInfo = false
        is_reportRules = false
        is_priorityTasks = false
        is_sfbiAllowedToDo = false
      end
      if imgui.Selectable(u8'Информация о шифр.канале', is_wtInfo) then
        is_genRule = false
        is_wtInfo = true
        is_reportRules = false
        is_priorityTasks = false
        is_sfbiAllowedToDo = false
      end
      if imgui.Selectable(u8'Правила докладов в шифр.канал', is_reportRules) then
        is_genRule = false
        is_wtInfo = false
        is_reportRules = true
        is_priorityTasks = false
        is_sfbiAllowedToDo = false
      end
      if imgui.Selectable(u8'Приоритеты для бойцов', is_priorityTasks) then
        is_genRule = false
        is_wtInfo = false
        is_reportRules = false
        is_priorityTasks = true
        is_sfbiAllowedToDo = false
      end
      if imgui.Selectable(u8'Бойцам S-FBI разрешено', is_sfbiAllowedToDo) then
        is_genRule = false
        is_wtInfo = false
        is_reportRules = false
        is_priorityTasks = false
        is_sfbiAllowedToDo = true
      end
    imgui.EndChild()
    
    imgui.SameLine()
    
    imgui.BeginChild('Texts', imgui.ImVec2(900, 450), true)
      if is_genRule then
        imgui.Text(regulations[1])
      end
      if is_wtInfo then
        imgui.Text(wt_info[1])
      end
      if is_reportRules then
        imgui.Text(wt_report_rules[1])
      end
      if is_priorityTasks then
        imgui.Text(wt_priority_tasks[1])
      end
      if is_sfbiAllowedToDo then
        imgui.Text(sfbi_allowed_toDo[1])
      end
    imgui.EndChild()
    
    imgui.End()
  end

  if codes_window_state.v then
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(1150, 500), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'SWAT FBI | Тен коды | Версия: 0.0.1', codes_window_state, imgui.WindowFlags.NoResize)
    imgui.BeginChild('Selectors2', imgui.ImVec2(230, 450), true)
      if imgui.Selectable(u8'Коды руководства', is_codeFromStaff) then
        is_codeFromStaff = true
        is_codeFromSquadmate = false
      end
      if imgui.Selectable(u8'Коды патрулей', is_codeFromSquadmate) then
        is_codeFromStaff = false
        is_codeFromSquadmate = true
      end
    imgui.EndChild()
    
    imgui.SameLine()
    
    imgui.BeginChild('Texts2', imgui.ImVec2(900, 450), true)
      if is_codeFromStaff then
        imgui.Text(staff_codes[1])
      end
      if is_codeFromSquadmate then
        imgui.Text(squad_codes[1])
      end
    imgui.EndChild()
    
    imgui.End()
  end

  if protocol_window_state.v then
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(1150, 500), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'SWAT FBI | Тен коды | Версия: 0.0.1', protocol_window_state, imgui.WindowFlags.NoResize)
    imgui.BeginChild('Selectors2', imgui.ImVec2(230, 450), true)
      if imgui.Selectable(u8'Протокол отряда', is_protocol) then
        is_protocol = true
      end
    imgui.EndChild()
    
    imgui.SameLine()
    
    imgui.BeginChild('Texts2', imgui.ImVec2(900, 450), true)
      if is_protocol then
        imgui.Text(protocol[1])
      end
    imgui.EndChild()
    
    imgui.End()
  end

  if actings_window_state.v then
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(300, 300), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'SWAT FBI | Отыгровки | Версия: 0.0.1', actings_window_state, imgui.WindowFlags.NoResize)
    if imgui.ButtonHex(u8'Замаскировать себя', 0x6468e8, imgui.ImVec2(285, 0)) then
      lua_thread.create(
        function ()
          sampSendChat('/me сорвал с формы шевроны и знаки отличий, затем бросил их на землю')
          wait(7000)
          sampSendChat('/do Неизвестный одет в камуфляж тёмно-зелёного цвета.')
          wait(7000)
          sampSendChat('/do На туловище висит бронежилет V класса защиты.')
          wait(7000)
          sampSendChat('/do На голове каска «OPS-CORE FAST» и доп.приборы связи.')
          wait(7000)
          sampSendChat('/do Опознавательных знаков или шевронов на форме не имеется.')
          wait(7000)
          sampSendChat('/do Лицо закрывает балаклава и очки. Личность не распознать.')
        end
      )
    end
    if imgui.ButtonHex(u8'Надеть противогаз', 0x6468e8, imgui.ImVec2(285, 0)) then
      lua_thread.create(function ()
        sampSendChat('/do На бедре левой ноги висит подсумок с противогазом ГП-21.')
        wait(7000)
        sampSendChat('/me задержав дыхание, достал противогаз и ловким движением надел его')
      end
      )
    end
    if imgui.ButtonHex(u8'Бросить СШГ с вертолёта', 0x6468e8, imgui.ImVec2(285, 0)) then
      lua_thread.create(function ()
        sampSendChat('/me достал из под сиденья прибор для определения координат')
        wait(3600)
        sampSendChat('/do Прибор определил координаты похитителей: 2736.1374.1749.9563.')
        wait(3600)
        r_service.sendIC('Координаты похитителей: 2736.1374.1749.9563. Готовлюсь работать СШГ.')
        wait(3600)
        sampSendChat('/me достал из-за пояса маленькие грузики, после чего прикрепил их к светошумовой гранате')
        wait(3600)
        sampSendChat('/me слегка приоткрыл задвижную дверь вертолета')
        wait(3600)
        r_service.sendIC('Бросаю СШГ.')
        wait(3600)
        sampSendChat('/me кидает светошумовую гранату вниз')
        wait(3600)
        sampSendChat('/cv Сбросил СШГ, 8 секунд')
        wait(3600)
        sampSendChat('/do В уши бойца вставлены М-звуокоподавляющие беруши, глушащие звук при 180+ дБ.')
        wait(3600)
        sampSendChat('/do На бойце надеты спец.очки, подавляющие яркие вспышки света от 7 до 30 млн. кД.')
        wait(3600)
        sampSendChat('/do СШГ упали с вертолетов возле переговорщика и похитителей, и У-Д принципом действия взорвались.')
      end)
    end
    imgui.End()
  end

end

function commandHandlers.renderMembers()
  members_window_state.v = not members_window_state.v
  imgui.Process = members_window_state.v
end

function commandHandlers.renderActings()
  actings_window_state.v = not actings_window_state.v
  imgui.Process = actings_window_state.v
end

function commandHandlers.renderProtocol()
  protocol_window_state.v = not protocol_window_state.v
  imgui.Process = protocol_window_state.v
end

function commandHandlers.renderCodes()
  codes_window_state.v = not codes_window_state.v
  imgui.Process = codes_window_state.v
end

function commandHandlers.renderIFT()
  ift_window_state.v = not ift_window_state.v
  imgui.Process = ift_window_state.v
end

function commandHandlers.renderS_C()
  s_c_window_state.v = not s_c_window_state.v
  imgui.Process = s_c_window_state.v
end

function commandHandlers.renderMM()
  main_window_state.v = not main_window_state.v
  imgui.Process = main_window_state.v
end

members_window_state = imgui.ImBool(false)
main_window_state = imgui.ImBool(false)
s_c_window_state = imgui.ImBool(false) -- s_c - Scirpt Commands
ift_window_state = imgui.ImBool(false) -- Info for Trainee
codes_window_state = imgui.ImBool(false)
protocol_window_state = imgui.ImBool(false)
actings_window_state = imgui.ImBool(false)




-- Interface end

-- Commands
local completed = false
local members = {}

function waitForId()
  local result, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
  local myNick = sampGetPlayerNickname(myId)
  chat.sendMessage('Происходит подгрузка данных сотрудников. Пожалуйста подождите.')
  local squadmates = getEachSquadmate(_squad[1])
  table.insert(members, { id = myId, nickname = myNick })
  for key, nickname in pairs(squadmates) do
    for i = 0, 1000 do
      if sampIsPlayerConnected(i) then
        local currentNickname = sampGetPlayerNickname(i)
        if currentNickname == nickname then
          local extracted = {
            id = i,
            nickname = nickname
          }
          if extracted.id and extracted.nickname then 
            if string.match(extracted.nickname, '%a+_%a+') then
              table.insert(members, extracted)
            end
          end
        end
    end
  end
end
  local staff = _table.filterSquad(members)
  commandHandlers.copyDataToImgui(staff)
  commandHandlers.renderMembers()
  members = {}
end

function getsquad(text)
  id_thread:run()
end


function getEachSquadmate (data)
  local squadmates = {}
  for nick in string.gmatch(data, '%a+_%a+') do
    table.insert(squadmates, nick)
  end
  return squadmates
end

function checkEachSquadmate()
  lua_thread.create(
    function ()
      local squadmates = getEachSquadmate(_squad[1])
      for key, nickname in pairs(squadmates) do
        sampSendChat(string.format('/id %s', nickname))
        wait(1000)
      end
    end
  )
end

-- Test functions
script_properties('work-in-pause')
require 'lib.sfbiextra.irc.luairc'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Utils

local connected = false
local connecting = false

local ROOM_ID = '#QLyCJGgtnJPcUGmWyXYV'
local SQUAD_NAME = 'S-FBI'

r_service = {}

function onIRCMessage(user, channel, message)
  if user then
    chat.showIRCMessage(user.nick, channel, u8:decode(message), SQUAD_NAME)
  else
    chat.sendWarning('Не удалось извлечь данные.')
  end
end

function onIRCDisconnect(message, error)
  if error then
    print(error)
    if connected then
      connected = false
      user:disconnect()
      chat.sendWarning('Вы были отключены от чата за долгий АФК. Пробуем переподключиться к рации.')
      chat.sendWarning('Экран подвиснет на 5-10 секунд из-за загрузки данных. Пожалуйста подождите.')
    end
  end
end

function r_service.connect()
  if not connected and not connecting then
    local _, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local playerNick = sampGetPlayerNickname(playerId)
    connecting = true
    user = irc.new{ nick = playerNick }
    user:connect('irc.esper.net')
    user:join(ROOM_ID)
    user:hook('OnChat', onIRCMessage)
    user:hook('OnDisconnect', onIRCDisconnect)
    connected = true
    connecting = false
  end
end

function r_service.sendIC(params)
  if connected and not connecting then
    if #params > 0 then
      _, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)
      playerNick = sampGetPlayerNickname(playerId)
      chat.showIRCMessage(playerNick, channel, params, SQUAD_NAME)
      user:sendChat(ROOM_ID, u8(params))
    end
  else
    chat.sendWarning(string.format('Не удалось подключиться к рации %s. Пробуем переподключиться', SQUAD_NAME))
    r_service.connect()
  end
end

function r_service.sendOOC(params)
  if connected and not connecting then
    if #params > 0 then
      _, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)
      playerNick = sampGetPlayerNickname(playerId)
      chat.showIRCMessage(playerNick, channel, params, SQUAD_NAME, true)
      user:sendChat(ROOM_ID, u8(string.format( "(( %s ))", params)))
    end
  else
    chat.sendWarning(string.format('Не удалось подключиться к рации %s. Пробуем переподключиться', SQUAD_NAME))
    r_service.connect()
  end
end

function r_service.main()
  while true do
    if connected and not connecting then
      user:think()
      wait(600)
    else
      chat.sendWarning(string.format('Подключение к рации %s выполнено.', SQUAD_NAME))
      r_service.connect()
    end
  end
end


function main()
  if not isSampLoaded() or not isSampfuncsLoaded() then return end
  while not isSampAvailable() do wait(0) end
  wait(20000)
  autoupdate('https://raw.githubusercontent.com/iaiiai/sfbi/main/version.json', '', 'vk.com/w.raines')
  local _, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)
  local playerNick = sampGetPlayerNickname(playerId)
  -- Requests
  _staff = network.get('https://pastebin.com/raw/5Xg9KmGP')
  _leadership = network.get('https://pastebin.com/raw/sHfZviLz')
  _squad = network.get('https://pastebin.com/raw/DYtDYfZ9')
  if string.find(_squad[1], playerNick) then
    print('')
  else
    return
  end
  -- Requests: Texts for regulations
  regulations = network.get('https://pastebin.com/raw/JLYq8T4h')
  wt_info = network.get('https://pastebin.com/raw/x781GHz5')
  wt_report_rules = network.get('https://pastebin.com/raw/YZFB2iNy')
  wt_priority_tasks = network.get('https://pastebin.com/raw/n67kX2BB')
  sfbi_allowed_toDo = network.get('https://pastebin.com/raw/raczCYZL')
  squad_codes = network.get('https://pastebin.com/raw/upvKZcax')
  staff_codes = network.get('https://pastebin.com/raw/hn75WSzE')
  protocol = network.get('https://pastebin.com/raw/7b2vPfaY')
  if not regulations and not wt_info and not wt_report_rules and not wt_priority_tasks and not sfbi_allowed_toDo and not squad_codes 
  and not staff_codes and not protocol then
    regulations = { [1] = 'Ошибка загрузки.' }
    wt_info = { [1] = 'Ошибка загрузки.' }
    wt_report_rules = { [1] = 'Ошибка загрузки.' }
    wt_priority_tasks = { [1] = 'Ошибка загрузки.' }
    sfbi_allowed_toDo = { [1] = 'Ошибка загрузки.' }
    squad_codes = { [1] = 'Ошибка загрузки.' }
    staff_codes = { [1] = 'Ошибка загрузки.' }
    protocol = { [1] = 'Ошибка загрузки' }
    chat.sendWarning('Не удалось загрузить важную информацию. Обратитесь к разработчику.')
  end
  members_thread = lua_thread.create_suspended(waitForMembers)
  id_thread = lua_thread.create_suspended(waitForId)
  r_service.connect()
  sampRegisterChatCommand('getsquad', getsquad)
  sampRegisterChatCommand('cv', r_service.sendIC)
  sampRegisterChatCommand('cb', r_service.sendOOC)
  sampRegisterChatCommand('sfbi', commandHandlers.renderMM)
  imgui.Process = false
  chat.sendMessage('Разработчик:{ab0519} William Raines{ffffff}.')
  chat.sendMessage('Отдельная благодарность {ab0519}Donny Provenzano{ffffff}, {ab0519}Gabriel Marques{ffffff} и {ab0519}Kevin Norberg{ffffff}.')
  chat.sendMessage('{ab0519}Версия скрипта: {ffffff}0.0.1')
  chat.sendMessage('Скрипт загружен.')
  chat.sendMessage('Для вызова меню скрипта используйте клавишу {f5001d}«U»{ffffff}.')
  lua_thread.create(r_service.main)
  while true do
    wait(0)
    if not sampIsChatInputActive() then
      if isKeyJustPressed(keys.VK_U) then
        commandHandlers.renderMM()
      end
    end
  end
end
