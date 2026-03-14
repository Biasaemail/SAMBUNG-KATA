-- ========================================================================
-- AUTO TYPE V33 — LOGIC
-- ========================================================================
-- Berisi: DB, filesystem, scoring engine, typing engine, auto-join,
--         cloud sync, dan remote handlers.
-- TIDAK ADA kode UI di sini (tidak ada Instance.new Frame/Button/dll).
--
-- Fungsi yang diexport ke getgenv() untuk dipakai UI.lua:
--   getgenv()._addWord(word, save)   → tambah kata ke DB
--   getgenv()._flushWords()          → flush antrian kata ke file
--   getgenv()._typeWord(word, btn)   → ketik kata ke game
--   getgenv()._optionCount(prefix)   → hitung opsi dari prefix
--   getgenv()._startInit()           → jalankan init (dipanggil Loader)
--
-- Fungsi dari UI.lua yang dipanggil via getgenv() bridge:
--   getgenv()._updateStatus(msg, col)
--   getgenv()._renderProfiles()
--   getgenv()._refreshChips()
--   getgenv()._genTurn(prefix)
--   getgenv()._hideAllBtns()
--   getgenv()._setCWTotal(text)
-- ========================================================================

-- ========================================================================
-- [1] SERVICES
-- ========================================================================
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local remotes     = ReplicatedStorage:WaitForChild("Remotes", 5)
local LocalPlayer = Players.LocalPlayer
local lower, sub, random = string.lower, string.sub, math.random

-- ========================================================================
-- [2] CONFIG & STATE (dibagikan ke UI via getgenv)
-- ========================================================================
local App = {
    Config = {
        TypingDelayMS   = 250,
        AutoPlay        = true,
        Humanize        = true,
        AutoJoin        = false,
        Playstyle       = "Smart Endgame",
        Styles          = {"Smart Endgame","Menang Cepat","Longest","Shortest","Normal","Complete Index"},
        TargetSuffixRaw = "",
        TargetSuffixes  = {},
    },
    State = {
        MatchActive=false, IsMyTurn=false, ServerLetter="",
        UsedWords={}, TriedThisTurn={}, PermanentBlacklist={},
        IsTyping=false, BotExecuting=false, ValidationResult=nil,
        FailCount=0, StyleIndex=1,
        LastUsedEndings={}, RoundCount=0, SessionSeed=math.random(1,99999),
        CrossMatchEndingCount={}, CrossMatchWordCount={}, MatchCount=0,
        IndexUsed={},
        OppPatternHistory={}, OppPatternCurrent=1,
        CurrentTableName=nil,
    },
    DB = {
        Dictionary={}, KnownWords={}, PrefixMap={},
        PrefixCount={},
        WordsStartingWith={}, TotalWords=0, NewWordsQueue={},
    },
    Profiles = {},
}

-- Daftarkan App ke getgenv agar UI.lua bisa akses
getgenv().App = App

-- ========================================================================
-- [2.5] BRIDGE — fungsi UI yang belum ada saat LOGIC load
-- Semua dipanggil via getgenv() agar tidak error sebelum UI siap.
-- ========================================================================
local function updateStatus(msg, col)
    if getgenv()._updateStatus then getgenv()._updateStatus(msg, col) end
end
local function hideAllBtns()
    if getgenv()._hideAllBtns then getgenv()._hideAllBtns() end
end
local function genTurn(prefix)
    if getgenv()._genTurn then getgenv()._genTurn(prefix) end
end

-- ========================================================================
-- [3] FILESYSTEM & CLOUD SYSTEM
-- ========================================================================
local FOLDER  = "WORD"
local BANK_F  = FOLDER.."/BANKWORD.txt"
local BLACK_F = FOLDER.."/BLACKLIST.txt"
local PROF_F  = FOLDER.."/SUFFIX_PROFILES.json"
local META_F  = FOLDER.."/META.json"
local INDEX_F = FOLDER.."/INDEX_USED.txt"
local DB_URL  = "https://raw.githubusercontent.com/Biasaemail/SAMBUNG-KATA/refs/heads/main/wordlistCLEAN.txt"

local function ensureDir()
    if isfolder and not isfolder(FOLDER) then pcall(makefolder, FOLDER) end
end
ensureDir()

local function je(t)  local ok,r=pcall(function() return HttpService:JSONEncode(t) end); return ok and r or "{}" end
local function jd(s)  if not s or s=="" then return {} end; local ok,r=pcall(function() return HttpService:JSONDecode(s) end); return (ok and type(r)=="table") and r or {} end
local function loadMeta() if isfile and isfile(META_F) then local ok,r=pcall(readfile,META_F); if ok then return jd(r) end end; return {wordCount=0,lastUpdate=0} end
local function saveMeta(m) if writefile then pcall(writefile,META_F,je(m)) end end
local function saveProfiles() if writefile then pcall(writefile,PROF_F,je(App.Profiles)) end end
local function loadProfiles()
    if isfile and isfile(PROF_F) then local ok,d=pcall(readfile,PROF_F); if ok then App.Profiles=jd(d) end end
    if type(App.Profiles)~="table" then App.Profiles={} end
end

local function flushWords()
    if #App.DB.NewWordsQueue==0 then return end
    local existingInFile={}
    if isfile and isfile(BANK_F) then
        local ok,content=pcall(readfile,BANK_F)
        if ok and content then
            for line in content:gmatch("[^\r\n]+") do
                local w=lower(line:match("^%s*(%a+)%s*$") or "")
                if w~="" then existingInFile[w]=true end
            end
        end
    end
    local toWrite={}
    for _,word in ipairs(App.DB.NewWordsQueue) do
        if not existingInFile[word] then table.insert(toWrite,word); existingInFile[word]=true end
    end
    if #toWrite>0 then
        local data=table.concat(toWrite,"\n").."\n"
        if appendfile then pcall(appendfile,BANK_F,data)
        elseif writefile and readfile then
            pcall(function()
                local ex=(isfile and isfile(BANK_F)) and readfile(BANK_F) or ""
                writefile(BANK_F,ex..data)
            end)
        end
    end
    table.clear(App.DB.NewWordsQueue)
end
task.spawn(function() while true do task.wait(5); flushWords() end end)

local function addWord(word, save)
    local lw=lower(word:match("^%s*(%a+)%s*$") or "")
    if not lw or #lw<2 or App.State.PermanentBlacklist[lw] or App.DB.KnownWords[lw] then return false end
    App.DB.KnownWords[lw]=true; App.DB.TotalWords=App.DB.TotalWords+1
    App.DB.Dictionary[App.DB.TotalWords]=lw
    for i=1,math.min(4,#lw) do
        local p=sub(lw,1,i)
        if not App.DB.PrefixMap[p] then App.DB.PrefixMap[p]={} end
        table.insert(App.DB.PrefixMap[p],App.DB.TotalWords)
        App.DB.PrefixCount[p]=(App.DB.PrefixCount[p] or 0)+1
    end
    App.DB.WordsStartingWith[sub(lw,1,1)]=(App.DB.WordsStartingWith[sub(lw,1,1)] or 0)+1
    if save then table.insert(App.DB.NewWordsQueue,lw) end
    return true
end

local function removeWordFromBank(word)
    if not word or not writefile or not isfile then return end
    if not isfile(BANK_F) then return end
    local lw=lower(word:match("^%s*(%a+)%s*$") or "")
    if lw=="" then return end
    local ok,content=pcall(readfile,BANK_F)
    if not ok or not content then return end
    local lines={}; local removed=false
    for line in content:gmatch("[^\r\n]+") do
        local w=lower(line:match("^%s*(%a+)%s*$") or "")
        if w~="" and w~=lw then table.insert(lines,w)
        elseif w==lw then removed=true end
    end
    if removed then pcall(writefile,BANK_F,table.concat(lines,"\n")) end
    for i=#App.DB.NewWordsQueue,1,-1 do
        if App.DB.NewWordsQueue[i]==lw then table.remove(App.DB.NewWordsQueue,i) end
    end
end

local function isBankValid()
    if not(isfile and isfile(BANK_F)) then return false end
    local ok,r=pcall(readfile,BANK_F); return ok and r and r:match("%a+\n%a+")~=nil
end

local function downloadBank()
    local ok,res=pcall(function() return game:HttpGet(DB_URL) end)
    if not ok or not res or #res<100 then return nil,0 end
    local uniq,arr={},{}
    for line in res:gmatch("[^\r\n]+") do
        local w=lower(line:match("^%s*(%a+)%s*$") or "")
        if w and #w>=2 and not uniq[w] then uniq[w]=true; table.insert(arr,w) end
    end
    table.sort(arr)
    local s=table.concat(arr,"\n"); if writefile then pcall(writefile,BANK_F,s) end
    local m=loadMeta(); m.wordCount=#arr; m.lastUpdate=os.clock(); saveMeta(m)
    return s,#arr
end

local function fetchNewWords()
    local n=0; local ok,res=pcall(function() return game:HttpGet(DB_URL) end)
    if ok and res and #res>100 then
        local seen={}
        for line in res:gmatch("[^\r\n]+") do
            local w=lower(line:match("^%s*(%a+)%s*$") or "")
            if w and #w>=2 and not seen[w] and not App.DB.KnownWords[w] and not App.State.PermanentBlacklist[w] then
                seen[w]=true; if addWord(w,true) then n=n+1 end
            end
        end
    end
    if n>0 then flushWords(); local m=loadMeta(); m.wordCount=App.DB.TotalWords; m.lastUpdate=os.clock(); saveMeta(m) end
    return n
end

-- ========================================================================
-- [4] AUTO-JOIN V2
-- ========================================================================
local TABLES_FOLDER = Workspace:WaitForChild("Tables",5) or Workspace

local function countSeats(model)
    local n=0
    for _,d in ipairs(model:GetDescendants()) do if d:IsA("Seat") and d.Occupant then n=n+1 end end
    return n
end
local function isTableInGame(model) local ig=model:FindFirstChild("InGame"); return ig and ig.Value==true or false end
local function getMaxPlayers(name) if name:match("2P") then return 2 elseif name:match("4P") then return 4 else return 8 end end

local function getTablePriority(model)
    if isTableInGame(model) then return -1 end
    local plrs=countSeats(model); local maxP=getMaxPlayers(model.Name)
    if plrs==0 or plrs>=maxP then return -1 end
    if maxP==2 and plrs==1 then return 3 end
    if maxP==4 and plrs>=2 then return 2 end
    if maxP==8 and plrs>=4 then return 1 end
    return -1
end

local function findBestTable()
    local best,bestPrio=nil,-1
    for _,child in ipairs(TABLES_FOLDER:GetChildren()) do
        if child:IsA("Model") and child.Name:match("^Table_") then
            local prio=getTablePriority(child)
            if prio>bestPrio then bestPrio=prio; best=child.Name end
        end
    end
    return best,bestPrio
end

local function doJoin(tableName)
    if remotes:FindFirstChild("JoinTable") then remotes.JoinTable:FireServer(tableName); App.State.CurrentTableName=tableName end
end
local function doLeave()
    if remotes:FindFirstChild("LeaveTable") then remotes.LeaveTable:FireServer() end
    App.State.CurrentTableName=nil
end

local function scanAndJoin()
    if not App.Config.AutoJoin then return end
    if App.State.CurrentTableName and not App.State.MatchActive then
        local curModel=TABLES_FOLDER:FindFirstChild(App.State.CurrentTableName)
        if curModel then
            local plrs=countSeats(curModel)
            if plrs<=1 then
                local best,prio=findBestTable()
                if best and best~=App.State.CurrentTableName and prio>0 then
                    pcall(updateStatus,"Pindah meja: "..best,Color3.fromRGB(255,200,80))
                    doLeave(); task.wait(0.5); doJoin(best); return
                end
            end
        end
    end
    if App.State.MatchActive then return end
    if App.State.CurrentTableName then return end
    local best=findBestTable(); if best then doJoin(best) end
end

TABLES_FOLDER.ChildAdded:Connect(function(child)
    task.wait(0.1)
    if not App.Config.AutoJoin or App.State.MatchActive then return end
    if child:IsA("Model") and child.Name:match("^Table_") then
        local prio=getTablePriority(child); if prio>0 then doJoin(child.Name) end
    end
end)
task.spawn(function() while true do task.wait(0.5); pcall(scanAndJoin) end end)

-- ========================================================================
-- [5] SCORING ENGINE
-- ========================================================================

-- ✏ HARD SUFFIX CONFIG — tambah akhiran pakai koma, pisah per skor
local HS_CONFIG = {
    [10] = "tt,rr,nn,ll,mm,pp,bb,dd,gg,kk,rks,lks,nks,rpt,mpt,rps,rq,lq,xz,gx,psy,fz,vz,wq,bx",
    [9]  = "rt,lt,st,nt,kt,ft,pt,rf,lf,rb,lb,rl,rh,lh,nh,dex,lex,tex,ex,lea,tid,die,hoi,pao,rx,lx,nx",
    [8]  = "oo,ae,q,x,ly,cy,ks,ps,oh,uh,agi,sh,th,ue,ea,oa,aa,ii,uu,ee",
    [7]  = "ry,sy,ty,nk,ih,au,ah,sk,nf,rl,rk,lk",
    [6]  = "au,ah,ox,ax,ix,ux,ts,ds,fs,gs",
}

local HARD_SUFFIX = {}
for score, list in pairs(HS_CONFIG) do
    for item in list:gmatch("[^,]+") do
        local s = item:match("^%s*(.-)%s*$")
        if s and s ~= "" then
            if not HARD_SUFFIX[s] or HARD_SUFFIX[s] < score then
                HARD_SUFFIX[s] = score
            end
        end
    end
end

local function stage()
    local sl=#App.State.ServerLetter
    return sl>=3 and "late" or sl==2 and "mid" or App.State.RoundCount>12 and "mid" or "early"
end

local function optionCount(prefix)
    if not prefix or prefix=="" then return 9999 end
    return App.DB.PrefixCount[lower(prefix)] or 0
end

local function hardSuffixScore(word)
    if #word<1 then return 0 end
    local s3=#word>=3 and sub(word,-3) or nil
    local s2=#word>=2 and sub(word,-2) or nil
    local s1=sub(word,-1)
    local best=0
    if s3 then best=math.max(best,(HARD_SUFFIX[s3] or 0)*20000) end
    if s2 then best=math.max(best,(HARD_SUFFIX[s2] or 0)*15000) end
    best=math.max(best,(HARD_SUFFIX[s1] or 0)*8000)
    return best
end

local function trapScore(word)
    if #word<1 then return 0 end
    local s=stage(); local last1=sub(word,-1); local opts1=optionCount(last1); local hss=hardSuffixScore(word)
    if s=="early" then
        local dbScore=opts1==0 and 800000 or math.max(500000-opts1*400,0)
        return math.max(dbScore,hss)
    end
    local last2=#word>=2 and sub(word,-2) or last1; local opts2=optionCount(last2); local base=0
    if opts2==0 then base=1500000
    elseif opts2<=3 then base=900000+(3-opts2)*150000
    elseif opts2<=10 then base=400000+(10-opts2)*40000
    else
        if opts1==0 then base=600000
        elseif opts1<=3 then base=200000+(3-opts1)*50000
        else base=math.max(100000-opts1*500,0) end
    end
    if s=="late" and #word>=3 then
        local opts3=optionCount(sub(word,-3))
        if opts3==0 then base=base+500000 elseif opts3<=2 then base=base+200000 end
    end
    return math.max(base,hss)
end

local function recordOpponentPattern(serverLetter)
    local len=#serverLetter; if len<1 then return end
    table.insert(App.State.OppPatternHistory,len)
    if #App.State.OppPatternHistory>20 then table.remove(App.State.OppPatternHistory,1) end
    local count={}
    for i=math.max(1,#App.State.OppPatternHistory-4),#App.State.OppPatternHistory do
        local v=App.State.OppPatternHistory[i]; count[v]=(count[v] or 0)+1
    end
    local best,bestN=1,0
    for v,n in pairs(count) do if n>bestN then bestN=n; best=v end end
    App.State.OppPatternCurrent=best
end

local function recordEnding(word)
    if #word<1 then return end
    local e2=#word>=2 and sub(word,-2) or sub(word,-1)
    table.insert(App.State.LastUsedEndings,e2)
    if #App.State.LastUsedEndings>8 then table.remove(App.State.LastUsedEndings,1) end
    App.State.CrossMatchEndingCount[e2]=(App.State.CrossMatchEndingCount[e2] or 0)+1
    App.State.CrossMatchWordCount[word]=(App.State.CrossMatchWordCount[word] or 0)+1
end

local function repeatPenalty(word)
    if #word<1 then return 0 end
    local e2=#word>=2 and sub(word,-2) or sub(word,-1); local pen=0
    for _,v in ipairs(App.State.LastUsedEndings) do if v==e2 then pen=pen+8000 end end
    pen=pen+(App.State.CrossMatchWordCount[word] or 0)*12000
    pen=pen+math.min((App.State.CrossMatchEndingCount[e2] or 0)*3000,60000)
    return pen
end

local function sfxBonus(word)
    if #App.Config.TargetSuffixes==0 then return 0 end
    local b=stage()=="late" and 750000 or stage()=="mid" and 600000 or 500000
    for _,sfx in ipairs(App.Config.TargetSuffixes) do
        if sfx~="" and #word>=#sfx and sub(word,-#sfx)==sfx then return b end
    end
    return 0
end

local function scoreWord(word,mode)
    local last=sub(word,-1); local oppOpts=optionCount(last); local wl=#word
    local sb=sfxBonus(word); local pen=repeatPenalty(word); local s=stage()
    local noiseMax=s=="early" and 8000 or s=="mid" and 3000 or 1000; local ns=random(1,noiseMax)
    if mode=="Smart Endgame" then
        if oppOpts==0 then return 9999999-pen end
        local trap=trapScore(word); local base=trap+sb+ns-pen
        base=base+(wl>=8 and 20000 or wl>=6 and 10000 or 0); return math.max(base,1)
    elseif mode=="Menang Cepat" then
        if oppOpts==0 then return 9500000-pen end
        local rareBonus=oppOpts<=2 and 350000 or oppOpts<=5 and 180000 or oppOpts<=10 and 70000 or 0
        local shortBonus=math.max(0,(8-wl))*10000
        return math.max(shortBonus+rareBonus+trapScore(word)*0.35+sb-pen+ns,1)
    elseif mode=="Longest" then
        local aliveBonus=oppOpts>=10 and 5000 or oppOpts>=5 and 2000 or 0
        return math.max(wl*4200+aliveBonus+sb-pen+ns,1)
    elseif mode=="Shortest" then
        if oppOpts==0 then return 9999999-pen end
        local shortBonus=wl<=2 and 80000 or wl<=3 and 50000 or wl<=5 and 20000 or 0
        return math.max((20-wl)*2500+shortBonus+sb-pen+ns,1)
    elseif mode=="Complete Index" then
        local newBonus=App.State.IndexUsed[word] and 0 or 5000000
        local freshBonus=math.max(0,100000-(App.State.CrossMatchWordCount[word] or 0)*20000)
        return math.max(newBonus+freshBonus+sb+ns,1)
    else
        local h=0
        for i=1,#word do h=(h*31+string.byte(word,i))%100000 end
        local score=(h+App.State.SessionSeed+App.State.RoundCount*17+App.State.MatchCount*3331)%60000
        return math.max(score+sb-pen+ns,1)
    end
end

-- ========================================================================
-- [6] TYPING ENGINE
-- ========================================================================
local function fireSim(str)
    for _,n in ipairs({"UpdateCurrentWord","WordUpdate","BillboardUpdate","UpdateBillboard"}) do
        if remotes:FindFirstChild(n) then remotes[n]:FireServer(str) end
    end
    if remotes:FindFirstChild("TypeSound") then remotes.TypeSound:FireServer() end
end

local TYPO={a={"q","s"},b={"v","n"},c={"x","v"},d={"s","f"},e={"w","r"},f={"d","g"},g={"f","h"},h={"g","j"},i={"u","o"},j={"h","k"},k={"j","l"},l={"k","p"},m={"n","k"},n={"b","m"},o={"i","p"},p={"o","l"},q={"a","w"},r={"e","t"},s={"a","d"},t={"r","y"},u={"y","i"},v={"c","b"},w={"q","e"},x={"z","c"},y={"t","u"},z={"a","x"}}

local function typeWord(word,uiButton)
    if not App.State.IsMyTurn then return false end
    App.State.IsTyping=true; App.State.ValidationResult=nil; App.State.TriedThisTurn[word]=true
    local prefixLen=#App.State.ServerLetter; local remaining=sub(word,prefixLen+1)
    local typed=""; local bd=App.Config.TypingDelayMS/1000
    for i=1,#remaining do
        if not App.State.IsMyTurn then break end
        local ch=sub(remaining,i,i)
        if App.Config.Humanize and random(1,100)<=15 and TYPO[ch] then
            local t=TYPO[ch]; fireSim(typed..t[random(1,#t)]); task.wait(bd*1.8); fireSim(typed); task.wait(bd*1.8)
        end
        typed=typed..ch; fireSim(typed)
        local v=App.Config.Humanize and (random(70,190)/100) or 1
        if App.Config.TypingDelayMS<=10 then RunService.Heartbeat:Wait() else task.wait(bd*v) end
    end
    if App.State.IsMyTurn then
        fireSim(typed); task.wait(0.09)
        if remotes:FindFirstChild("SubmitWord") then remotes.SubmitWord:FireServer(remaining) end
        local t=0
        while App.State.ValidationResult==nil and App.State.IsMyTurn and t<15 do task.wait(0.1); t=t+1 end
        if App.State.ValidationResult==nil then App.State.ValidationResult="INVALID" end
        if App.State.ValidationResult=="SUCCESS" then
            App.State.UsedWords[word]=true; App.State.FailCount=0; App.State.IsTyping=false; recordEnding(word)
            if not App.State.IndexUsed[word] then
                App.State.IndexUsed[word]=true; if appendfile then pcall(appendfile,INDEX_F,word.."\n") end
            end
            return true
        elseif App.State.ValidationResult=="INVALID" then
            App.State.PermanentBlacklist[word]=true
            App.DB.KnownWords[word]=nil
            task.spawn(function() removeWordFromBank(word) end)
            if appendfile then pcall(appendfile,BLACK_F,word.."\n") end
            if uiButton then
                TweenService:Create(uiButton,TweenInfo.new(0.3),{BackgroundColor3=Color3.fromRGB(255,70,70),BackgroundTransparency=0.55}):Play()
                uiButton.Text=word:upper().." ✗"; uiButton.Interactable=false
            end
            App.State.FailCount=App.State.FailCount+1; App.State.IsTyping=false; return false
        end
    end
    App.State.IsTyping=false; return false
end

-- ========================================================================
-- [7] EXPORT — daftarkan fungsi LOGIC ke getgenv agar UI bisa pakai
-- ========================================================================
getgenv()._addWord        = addWord
getgenv()._flushWords     = flushWords
getgenv()._typeWord       = typeWord
getgenv()._optionCount    = optionCount
getgenv()._scoreWord      = scoreWord
getgenv()._stage          = stage
getgenv()._saveProfilesFn = saveProfiles  -- dipanggil dari UI lewat _saveProfiles wrapper

-- ========================================================================
-- [8] CLOUD SYNC
-- ========================================================================
local function bgSync()
    task.wait(5)
    updateStatus("🔄 Cek update...",Color3.fromRGB(150,200,255))
    local n=fetchNewWords()
    if n>0 then
        updateStatus("✅ +"..n.." kata baru!",Color3.fromRGB(128,255,162))
        task.wait(3)
    end
    updateStatus()
end

-- ========================================================================
-- [9] INIT — diekspos sebagai _startInit, dipanggil Loader setelah UI siap
-- ========================================================================
getgenv()._startInit = function()
    loadProfiles()
    -- Panggil UI callbacks (sudah terdaftar karena UI.lua sudah jalan)
    if getgenv()._renderProfiles then getgenv()._renderProfiles() end
    if getgenv()._refreshChips   then getgenv()._refreshChips()   end

    task.spawn(function()
        -- Load blacklist
        if isfile and isfile(BLACK_F) then
            pcall(function()
                for line in readfile(BLACK_F):gmatch("[^\r\n]+") do
                    local lw=lower(line:match("^%s*(%a+)%s*$") or ""); if lw~="" then App.State.PermanentBlacklist[lw]=true end
                end
            end)
        end
        -- Load index
        if isfile and isfile(INDEX_F) then
            pcall(function()
                for line in readfile(INDEX_F):gmatch("[^\r\n]+") do
                    local lw=lower(line:match("^%s*(%a+)%s*$") or ""); if lw~="" then App.State.IndexUsed[lw]=true end
                end
            end)
        end
        -- Load / download bank kata
        local bank=""
        if isBankValid() then
            local ok,r=pcall(readfile,BANK_F)
            if ok and r then bank=r; local m=loadMeta(); updateStatus("📂 Load "..(m.wordCount>0 and m.wordCount or "?").." kata...",Color3.fromRGB(150,200,255)) end
        else
            updateStatus("⬇ Download kosakata...",Color3.fromRGB(150,200,255))
            local dl,cnt=downloadBank()
            if dl then bank=dl; updateStatus("✅ "..cnt.." kata!",Color3.fromRGB(128,255,162))
            else
                task.wait(3); updateStatus("🔁 Retry...",Color3.fromRGB(255,195,70))
                local dl2,cnt2=downloadBank()
                if dl2 then bank=dl2; updateStatus("✅ "..cnt2.." kata!",Color3.fromRGB(128,255,162))
                else updateStatus("⚠ Gagal. Cek koneksi.",Color3.fromRGB(255,110,70)); task.wait(3) end
            end
        end
        -- Masukkan kata ke memory
        if bank~="" then
            local batch=0
            for line in bank:gmatch("[^\r\n]+") do
                local lw=lower(line:match("^%s*(%a+)%s*$") or "")
                if lw~="" and not App.State.PermanentBlacklist[lw] then
                    if addWord(lw,false) then batch=batch+1; if batch>=4000 then batch=0; RunService.Heartbeat:Wait() end end
                end
            end
        end
        -- Update counter di Panel 3 via callback
        if getgenv()._setCWTotal then getgenv()._setCWTotal("DB: "..App.DB.TotalWords.." kata") end
        updateStatus("✅ Siap! "..App.DB.TotalWords.." kata 🔥",Color3.fromRGB(128,255,172))
        task.wait(2); updateStatus()
        -- Refresh suffix chips rarity badge setelah DB siap
        if getgenv()._refreshChips then getgenv()._refreshChips() end
        task.spawn(bgSync)
    end)
end

-- ========================================================================
-- [10] REMOTE HANDLERS
-- ========================================================================
local function markWordUsed(word)
    if not word or type(word)~="string" then return end
    local lw=lower(word:match("^%s*(%a+)%s*$") or "")
    if lw and #lw>=2 then
        App.State.UsedWords[lw]=true
        if not App.DB.KnownWords[lw] and not App.State.PermanentBlacklist[lw] then
            addWord(lw,true)
        end
    end
end

if remotes:FindFirstChild("PlayerCorrect") then
    remotes.PlayerCorrect.OnClientEvent:Connect(function(_,word) markWordUsed(word); App.State.ValidationResult="SUCCESS" end)
end
if remotes:FindFirstChild("WordUpdate") then
    remotes.WordUpdate.OnClientEvent:Connect(function(word) markWordUsed(word) end)
end
if remotes:FindFirstChild("UpdateCurrentWord") then
    remotes.UpdateCurrentWord.OnClientEvent:Connect(function(word) markWordUsed(word) end)
end
if remotes:FindFirstChild("UsedWordWarn") then
    remotes.UsedWordWarn.OnClientEvent:Connect(function(word)
        if word and type(word)=="string" then
            local lw=lower(word:match("^%s*(%a+)%s*$") or "")
            if lw and #lw>=2 then App.State.UsedWords[lw]=true end
        end
    end)
end

if remotes:FindFirstChild("MatchUI") then
    remotes.MatchUI.OnClientEvent:Connect(function(cmd,value)
        if cmd=="ShowMatchUI" then
            App.State.MatchActive=true; App.State.IsMyTurn=false
            App.State.UsedWords={}; App.State.TriedThisTurn={}; App.State.FailCount=0
            App.State.RoundCount=0; App.State.LastUsedEndings={}
            App.State.OppPatternHistory={}; App.State.OppPatternCurrent=1
            App.State.MatchCount=App.State.MatchCount+1; App.State.SessionSeed=random(1,99999)
            hideAllBtns(); updateStatus()
        elseif cmd=="HideMatchUI" then
            App.State.MatchActive=false; App.State.IsMyTurn=false
            App.State.ServerLetter=""; App.State.ValidationResult="SUCCESS"; App.State.CurrentTableName=nil
            hideAllBtns(); updateStatus("Match Selesai",Color3.fromRGB(185,185,185))
        elseif cmd=="StartTurn" then
            App.State.IsMyTurn=true; App.State.TriedThisTurn={}; App.State.BotExecuting=false
            updateStatus(); genTurn(App.State.ServerLetter)
        elseif cmd=="EndTurn" then
            App.State.IsMyTurn=false; App.State.ValidationResult="SUCCESS"; hideAllBtns(); updateStatus()
        elseif cmd=="UpdateServerLetter" then
            local prev=App.State.ServerLetter; App.State.ServerLetter=value or ""; updateStatus()
            if App.State.ServerLetter~=prev then recordOpponentPattern(App.State.ServerLetter) end
        end
    end)
end

print("[AutoType] LOGIC.lua loaded!")
