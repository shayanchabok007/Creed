package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '1.0'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
  --   mark_read(receiver, ok_cb, false)
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "onservice",
    "inrealm",
    "ingroup",
    "inpm",
    "banhammer",
    "Boobs",
    "",
    "lock_join",
    "antilink",
    "addplug",
    "antitag",
    "stats",
    "auto_leave",
    "block",
    "tagall",
    "feedback",
    "arabic_lock",
    "welcome",
    "google",
    "sms",
    "plugins",
    "owners",
    "Debian_service",
    "sudoers",
    "add_admin",
    "anti_spam",
    "add_bot",
    "lock_chat",
    "owners",
    "set",
    "get",
    "filterorg",
    "bin",
    "version",
    "time",
    "splugin",
    "info",
    "support",
    "calc",
    "text",
    "webshot",
    "cpu",
    "echo",
    "bot_on_off",
    "chatbot",
    "botphoto",
    "setrank",
    "broadcast",
    "download_media",
    "invite",
    "all",
    "leave_ban"
    },
    sudo_users = {181742153},--Sudo users
    disabled_channels = {},
    moderation = {data = 'data/moderation.json'},
    about_text = [[Creed bot 2.3
    
     Hello my Good friends 
     
    ‼️ this bot is made by : @creed_is_dead
   〰〰〰〰〰〰〰〰
   ߔࠀ   our admins are : 
   ߔࠀ   @sorblack_creed
   ߔࠀ   @amircc_creed
   ߔࠀ   @aria_creed
   〰〰〰〰〰〰〰〰
  ♻️ You can send your Ideas and messages to Us By sending them into bots account by this command :
   تمامی درخواست ها و همه ی انتقادات و حرفاتونو با دستور زیر بفرستین به ما
   !feedback (your ideas and messages)
]],
    help_text_realm = [[
Realm Commands:

!creategroup [Name]
Create a group
گروه جدیدی بسازید

!createrealm [Name]
Create a realm
گروه مادر جدیدی بسازید

!setname [Name]
Set realm name
اسم گروه مادر را تغییر بدهید

!setabout [GroupID] [Text]
Set a group's about text
در مورد  آن گروه توضیحاتی را بنویسید (ای دی گروه را بدهید )

!setrules [GroupID] [Text]
Set a group's rules
در مورد آن گروه قوانینی تعیین کنید ( ای دی گروه را بدهید )

!lock [GroupID] [setting]
Lock a group's setting
تنظیکات گروهی را قفل بکنید

!unlock [GroupID] [setting]
Unock a group's setting
تنظیمات گروهی را از قفل در بیاورید 

!wholist
Get a list of members in group/realm
لیست تمامی اعضای گروه رو با ای دی شون نشون میده

!who
Get a file of members in group/realm
لیست تمامی اعضای گروه را با ای دی در فایل متنی دریافت کنید

!type
Get group type
در مورد نقش گروه بگیرید

!kill chat [GroupID]
Kick all memebers and delete group 
️تمامی اعضای گروه را حذف میکند 

!kill realm [RealmID]
Kick all members and delete realm
تمامی اعضای گروه مارد را حذف میکند

!addadmin [id|username]
Promote an admin by id OR username *Sudo only
ادمینی را اضافه بکنید


!removeadmin [id|username]
Demote an admin by id OR username *Sudo only
️ادمینی را با این دستور صلب مقام میکنید 

!list groups
Get a list of all groups
لیست تمامی گروه هارو میده

!list realms
Get a list of all realms
لیست گروه های مادر را میدهد


!log
Get a logfile of current group or realm
تمامی عملیات گروه را میدهد

!broadcast [text]
Send text to all groups ✉️
✉️ با این دستور به تمامی گروه ها متنی را همزمان میفرستید  .

!br [group_id] [text]
This command will send text to [group_id]✉️
با این دستور میتونید به گروه توسط ربات متنی را بفرستید 

You Can user both "!" & "/" for them
میتوانید از هردوی کاراکتر های ! و / برای دستورات استفاده کنید


]],
    help_text = [[
➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖
⛔️دستورات اداره ی گروه⛔️
➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖
🔰  نصب مقام ( مقام ) : 
🔹 برای تعلق دادن مقام مورد نظر به شخص مورد نظر با ریپلی
------------------------------------------------------------------------------------------------------------
🔰 اطلاعات ( ای دی/نام کاربری) : 
🔹  برای مشاهده ی اطلاعات شخص مورد نظر ( با ریپلی هم میشه )
------------------------------------------------------------------------------------------------------------
🔰  لیست مسدودان : 
🔹  برای مشاهده ی لیست افراد مسدود شده ی گروه 
------------------------------------------------------------------------------------------------------------
🔰  صلب مسدود : 
🔹 برای دراوردن شخص از مسدودیت گروه
------------------------------------------------------------------------------------------------------------
🔰 !support
🔰  دعوت سازنده ربات به گروه
🔰  (در صورت وجود مشکل)
------------------------------------------------------------------------------------------------------------
🔰 بگو <متن> : تکرار متن
------------------------------------------------------------------------------------------------------------
🔰  ورژن
🔰  ورژن ربات
------------------------------------------------------------------------------------------------------------
🔰 !setbotphoto
🔰 ایجاد عکس برای پروفایل بات
🔰 (مخصوص ادمین بات)
------------------------------------------------------------------------------------------------------------
🔰  !setrank
🔰  ایجاد مقام برای فرد مورد نظر
🔰  (با ریپلای هم میشه)
------------------------------------------------------------------------------------------------------------
🔰  !filter + کلمه 
🔰  فیلتر کلمه
------------------
🔰  !listft
🔰  لیست فیلتر شده ها
------------------------------------------------------------------------------------------------------------
🔰 !boobs
🔰 عکس سکسی
------------------------------------------------------------------------------------------------------------
🔰 (زمان (منطقه
🔰 ساعت کشور مورد نظر
------------------------------------------------------------------------------------------------------------
🔰  !sms [ ]
🔰  اس ام اس
------------------------------------------------------------------------------------------------------------
🔰 !block [username]
🔰  بلاک کردن
------------------------------------------------------------------------------------------------------------
🔰 !webshot [سایت مورد نظر]
🔰 عکس از صفحه گوگل
------------------------------------------------------------------------------------------------------------
!tagall
صدا کردن افراد گروه
------------------------------------------------------------------------------------------------------------
!text [متن]
تبدیل متن به عکس
------------------------------------------------------------------------------------------------------------
🔰  !google [مطلب جهت سرچ]
🔰  سرچ از گوگل
------------------------------------------------------------------------------------------------------------
🔰  !feedback [نظر]
🔰  ارسال نظر خود
------------------------------------------------------------------------------------------------------------
🔰  !send [plugin_name]
🔰  ارسال پلاگین مورد نظر
🔰  (مخصوص ادمین بات)
------------------------------------------------------------------------------------------------------------
🔰  مسدود : 
🔹 برای مسدود کردن شخص از گروه تا دیگه نتونه بیاد
------------------------------------------------------------------------------------------------------------
🔰  اخراج : 
🔹 برای اخراج کردن شخص از گروه استفاده میشود ( با ریپلی هم میشه ) 
------------------------------------------------------------------------------------------------------------
🔰  (نصب/صلب) : 
🔹  برای (اضافه/حذف) کردن گروه (به/از) گروه های ربات.
------------------------------------------------------------------------------------------------------------
🔰  (نصب/صلب) ریلم : 
🔹  برای (اضافه/حذف) کردن ریلم (به/از) ریلم های ربات.
------------------------------------------------------------------------------------------------------------
🔰  (قوانین/توضیحات) : 
🔹  برای دیدن (قوانین/توضیحات) گروه استفاده میشود.
------------------------------------------------------------------------------------------------------------
🔰  نصب (عکس/اسم) :
🔹  برای تعویض یا گذاشتن (عکس/اسم) گروه استفاده میشود.
------------------------------------------------------------------------------------------------------------
🔰  ارتقا : 
🔹  برای ارتقا دادن شخصی به عنوان مدیر ( با ریپلی هم میشه ) 
------------------------------------------------------------------------------------------------------------
🔰  پاک کردن (قوانین/لیست مدیران/توضیحات) : 
🔹  برای پاک کردن (قوانین/لیست مدیران/توضیحات)  گروهتان استفاده میشود.
------------------------------------------------------------------------------------------------------------
🔰  حذف مدیر : 
🔹  برای حذف کردن مدیریت یکی از مدیران ( با ریپلی هم میشه ) 
------------------------------------------------------------------------------------------------------------
🔰  تنظیم (قوانین/توضیحات) : 
🔹  برای تنظیم کردن (قوانین/توضیحات)  برای گروه .
------------------------------------------------------------------------------------------------------------
🔰  (قفل/باز کردن) [همه/استیکر/اسم/ورود/عکس/اسپم/فارسی/تبلیغ/انگلیسی/فحش/تگ/خروج/ربات]
🔹  برای بازکردن یا قفل  [همه/استیکر/اسم/ورود/عکس/اسپم/فارسی/تبلیغ/انگلیسی/فحش/تگ/خروج/ربات] در گروه استفاده میشود . 
------------------------------------------------------------------------------------------------------------
🔰  نصب مالک :
🔹  برای ارقای شخصی به عنوان مالک (سازنده) گروه استفاده میشود.
------------------------------------------------------------------------------------------------------------
🔰  در مورد (نام کاربری) :
🔹  برای دادن ای دی  و اسم شخص استفاده میشود.
------------------------------------------------------------------------------------------------------------
🔰  حساسیت (عدد) : 
🔹  برای تنظیم حساسیت ربات به اسپم به تعدادی که میدهیم.
------------------------------------------------------------------------------------------------------------
🔰  تنظیمات :
🔹  برای مشاهده ی تنظیمات گروه .
------------------------------------------------------------------------------------------------------------
🔰  لیست مدیران : 
🔹  برای دیدن لیست مدیران استفاده میشود.
------------------------------------------------------------------------------------------------------------
🔰  لینک : 
🔹  برای دریافت لینک گروه استفاده میشود.
------------------------------------------------------------------------------------------------------------
🔰  لینک جدید : 
🔹 برای دریافت لینک جدید گروه استفاده میشود.
------------------------------------------------------------------------------------------------------------
🔰 اخراج غیر فعال :
🔹 برای اخراج کردن غیر فعال ها استفاده میشود . 
------------------------------------------------------------------------------------------------------------
🔰 ای دی :
🔹 فقط با ریپلی میتوانید از این دستور برای ای دی گرفتن شخصی استفاده کنید
------------------------------------------------------------------------------------------------------------
 نکته !!!! :   با دستور *اخراجم کن* میتوانید از گروه بروید . 
------------------------------------------------------------------------------------------------------------
کانال ما : @iranpower_ch
ادمین بات : @shayan31323
  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
