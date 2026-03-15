-- ========================================================================
-- AUTO TYPE V33
-- ========================================================================
-- [+] HARD_SUFFIX: format baru — pisah koma, gampang tambah akhiran sendiri
-- [+] Panel 2 (Suffix): UI premium, trap meter, rarity live badge per chip
-- [+] Panel 3 (Kata): Custom word add — cek duplikat, notif langsung
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

local updateStatus = function() end

-- ========================================================================
-- [2] CONFIG & STATE
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

-- ================================================================
-- HARD SUFFIX CONFIG — ✏ Tinggal tambah akhiran pakai koma!
-- Skor 10 = paling mematikan, skor 6 = lumayan sulit
-- ================================================================
local HS_CONFIG = {
    [10] = "tt,rr,nn,ll,mm,pp,bb,dd,gg,kk,rks,lks,nks,rpt,mpt,rps,rq,lq,xz,gx,psy,fz,vz,wq,bx",
    [9]  = "rt,lt,st,nt,kt,ft,pt,rf,lf,rb,lb,rl,rh,lh,nh,dex,lex,tex,ex,lea,tid,die,hoi,pao,rx,lx,nx",
    [8]  = "oo,ae,q,x,ly,cy,ks,ps,oh,uh,agi,sh,th,ue,ea,oa,aa,ii,uu,ee",
    [7]  = "ry,sy,ty,nk,ih,au,ah,sk,nf,rl,rk,lk",
    [6]  = "au,ah,ox,ax,ix,ux,ts,ds,fs,gs",
    -- ↑ Tambahkan akhiran baru di baris yang sesuai, pisah dengan koma
    -- Contoh: kalau mau tambah "bz" di skor 10, cukup tambahkan ",bz" di baris [10]
}

-- Build lookup table otomatis dari HS_CONFIG (tidak perlu edit bagian ini)
local HARD_SUFFIX = {}
for score, list in pairs(HS_CONFIG) do
    for item in list:gmatch("[^,]+") do
        local s = item:match("^%s*(.-)%s*$")
        if s and s ~= "" then
            -- Kalau satu akhiran muncul di beberapa skor, pakai yang tertinggi
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
            local t=TYPO[ch]; fireSim(typed..t[random(1,#t)]); task.wait(bd*1.9); fireSim(typed); task.wait(bd*1.8)
        end
        typed=typed..ch; fireSim(typed)
        local v=App.Config.Humanize and (random(88,199)/100) or 1
        if App.Config.TypingDelayMS<=40 then RunService.Heartbeat:Wait() else task.wait(bd*v) end
    end
    if App.State.IsMyTurn then
        fireSim(typed); task.wait(0.19)
        if remotes:FindFirstChild("SubmitWord") then remotes.SubmitWord:FireServer(remaining) end
        local t=0
        while App.State.ValidationResult==nil and App.State.IsMyTurn and t<10 do task.wait(0.1); t=t+1 end
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
-- [7] UI — 3 TAB: Config | Suffix | Kata
-- ========================================================================
local uiName="AutoType_V33"
local pGui=(gethui and gethui()) or CoreGui
for _,n in ipairs({uiName,"AutoType_V32","AutoType_V31","AutoType_V30","AutoType_V29","AutoType_V28_Final","AutoType_V28_Tab","AutoType_V28_Ultimate","AutoType_V27_Ultimate"}) do
    if pGui:FindFirstChild(n) then pGui[n]:Destroy() end
end

local SG=Instance.new("ScreenGui")
SG.Name=uiName; SG.ResetOnSpawn=false; SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; SG.Parent=pGui

local W=172; local LP_W=168; local H=230; local TOP_H=26

local MF=Instance.new("Frame")
MF.Name="MainFrame"; MF.AnchorPoint=Vector2.new(1,0)
MF.Size=UDim2.new(0,W,0,H); MF.Position=UDim2.new(0.5,86,0.5,-H/2)
MF.BackgroundColor3=Color3.fromRGB(6,7,12); MF.BackgroundTransparency=0.18
MF.ClipsDescendants=true; MF.Parent=SG
Instance.new("UICorner",MF).CornerRadius=UDim.new(0,12)
local mStk=Instance.new("UIStroke",MF); mStk.Color=Color3.fromRGB(80,120,255); mStk.Transparency=0.72; mStk.Thickness=1

local USc=Instance.new("UIScale",MF); USc.Scale=0.78
TweenService:Create(USc,TweenInfo.new(0.55,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Scale=1}):Play()

-- Gradient background strip di topbar
local TB=Instance.new("Frame"); TB.Size=UDim2.new(1,0,0,TOP_H); TB.BackgroundTransparency=1; TB.Active=true; TB.Parent=MF
local TBbg=Instance.new("Frame"); TBbg.Size=UDim2.new(1,0,1,0)
TBbg.BackgroundColor3=Color3.fromRGB(15,18,40); TBbg.BackgroundTransparency=0.05; TBbg.BorderSizePixel=0; TBbg.Parent=TB
local tbGrad=Instance.new("UIGradient",TBbg)
tbGrad.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(30,50,120)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(10,12,30))
})
tbGrad.Rotation=90

local TitleL=Instance.new("TextLabel"); TitleL.Size=UDim2.new(0,115,1,0); TitleL.Position=UDim2.new(0,8,0,0)
TitleL.BackgroundTransparency=1; TitleL.Text="AUTO TYPE V33"; TitleL.TextColor3=Color3.fromRGB(180,210,255)
TitleL.Font=Enum.Font.GothamBlack; TitleL.TextSize=10; TitleL.TextXAlignment=Enum.TextXAlignment.Left; TitleL.Parent=TB

local drag,dInp,dStart,dPos
TB.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        drag=true; dStart=i.Position; dPos=MF.Position
        i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end)
    end
end)
TB.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then dInp=i end end)
UserInputService.InputChanged:Connect(function(i)
    if i==dInp and drag then local d=i.Position-dStart; MF.Position=UDim2.new(dPos.X.Scale,dPos.X.Offset+d.X,dPos.Y.Scale,dPos.Y.Offset+d.Y) end
end)

local function mkTopBtn(txt,off,col,hov)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(0,20,0,TOP_H); b.Position=UDim2.new(1,off,0,0)
    b.BackgroundTransparency=1; b.Text=txt; b.TextColor3=col; b.Font=Enum.Font.GothamBold
    b.TextSize=10; b.AnchorPoint=Vector2.new(1,0); b.Parent=TB
    b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.15),{TextColor3=hov,TextSize=12}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.15),{TextColor3=col,TextSize=10}):Play() end)
    return b
end
local CloseB=mkTopBtn("x",-4,Color3.fromRGB(255,90,90),Color3.fromRGB(255,30,30))
local MinB  =mkTopBtn("_",-25,Color3.fromRGB(200,200,200),Color3.fromRGB(255,255,255))
local BookB =mkTopBtn("=",-47,Color3.fromRGB(130,195,255),Color3.fromRGB(255,255,255))

-- STATUS BAR
local SL=Instance.new("TextLabel"); SL.Size=UDim2.new(1,-12,0,12); SL.Position=UDim2.new(0,6,0,TOP_H+1)
SL.BackgroundTransparency=1; SL.Text="⏳ Loading..."; SL.TextColor3=Color3.fromRGB(175,215,255)
SL.Font=Enum.Font.GothamSemibold; SL.TextSize=8; SL.TextXAlignment=Enum.TextXAlignment.Left; SL.Parent=MF

local function updateStatus(msg,col)
    if msg then SL.Text=msg; SL.TextColor3=col or Color3.fromRGB(255,255,255); return end
    if App.State.IsMyTurn then SL.Text="Awalan: "..App.State.ServerLetter:upper(); SL.TextColor3=Color3.fromRGB(128,255,168)
    else SL.Text="Menunggu giliran..."; SL.TextColor3=Color3.fromRGB(175,175,175) end
end

local CTRL_Y=TOP_H+14; local CTRL_H=H-CTRL_Y-5

local RP=Instance.new("Frame")
RP.Size=UDim2.new(0,W,0,CTRL_H); RP.Position=UDim2.new(1,-W,0,CTRL_Y)
RP.BackgroundTransparency=1; RP.Parent=MF

-- TAB BAR — 3 Tab
local TabBar=Instance.new("Frame"); TabBar.Size=UDim2.new(1,-8,0,22); TabBar.Position=UDim2.new(0,4,0,0)
TabBar.BackgroundColor3=Color3.fromRGB(12,14,28); TabBar.BackgroundTransparency=0.25; TabBar.Parent=RP
Instance.new("UICorner",TabBar).CornerRadius=UDim.new(0,7)
local tbStk=Instance.new("UIStroke",TabBar); tbStk.Color=Color3.fromRGB(60,80,200); tbStk.Transparency=0.7; tbStk.Thickness=0.8

local TABS={"⚙ CFG","🎯 SFX","✏ KATA"}
local tabBtns={}; local tabPanels={}; local activeTab=1

for i,name in ipairs(TABS) do
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1/#TABS,-3,1,-5)
    btn.Position=UDim2.new((i-1)/#TABS,i==1 and 3 or 2,0,2)
    btn.BackgroundColor3=i==1 and Color3.fromRGB(55,100,255) or Color3.fromRGB(255,255,255)
    btn.BackgroundTransparency=i==1 and 0.55 or 0.96
    btn.Text=name; btn.TextColor3=i==1 and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,130,170)
    btn.Font=Enum.Font.GothamBold; btn.TextSize=8; btn.AutoButtonColor=false
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,5); btn.Parent=TabBar; tabBtns[i]=btn
end

local PANEL_Y=26; local PANEL_H=CTRL_H-PANEL_Y-2

local function mkPanel()
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,-8,0,PANEL_H); f.Position=UDim2.new(0,4,0,PANEL_Y)
    f.BackgroundTransparency=1; f.Visible=false; f.Parent=RP; return f
end
local P1=mkPanel(); P1.Visible=true
local P2=mkPanel()
local P3=mkPanel()
tabPanels={P1,P2,P3}
local P1L=Instance.new("UIListLayout"); P1L.SortOrder=Enum.SortOrder.LayoutOrder; P1L.Padding=UDim.new(0,5); P1L.Parent=P1
local P2L=Instance.new("UIListLayout"); P2L.SortOrder=Enum.SortOrder.LayoutOrder; P2L.Padding=UDim.new(0,4); P2L.Parent=P2
local P3L=Instance.new("UIListLayout"); P3L.SortOrder=Enum.SortOrder.LayoutOrder; P3L.Padding=UDim.new(0,6); P3L.Parent=P3

local TAB_COLORS={
    Color3.fromRGB(55,100,255),  -- cfg: biru
    Color3.fromRGB(255,130,40),  -- sfx: oranye
    Color3.fromRGB(80,210,130),  -- kata: hijau
}

local function switchTab(idx)
    activeTab=idx
    for i,p in ipairs(tabPanels) do
        p.Visible=(i==idx)
        TweenService:Create(tabBtns[i],TweenInfo.new(0.2,Enum.EasingStyle.Quart),{
            BackgroundTransparency=i==idx and 0.55 or 0.96,
            BackgroundColor3=i==idx and TAB_COLORS[i] or Color3.fromRGB(255,255,255),
            TextColor3=i==idx and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,130,170)
        }):Play()
    end
end
for i,b in ipairs(tabBtns) do b.MouseButton1Click:Connect(function() switchTab(i) end) end

-- ================================================================
-- PANEL 1: CONFIG
-- ================================================================
local function mkToggle(par,text,def,cb)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,18); f.BackgroundTransparency=1; f.Parent=par
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.72,0,1,0); lbl.BackgroundTransparency=1
    lbl.Text=text; lbl.TextColor3=Color3.fromRGB(220,225,255); lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=9; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=f
    local bg=Instance.new("TextButton"); bg.Size=UDim2.new(0,30,0,15); bg.Position=UDim2.new(1,-30,0.5,-7)
    bg.BackgroundColor3=def and Color3.fromRGB(55,200,115) or Color3.fromRGB(50,52,80)
    bg.BackgroundTransparency=0; bg.Text=""; bg.AutoButtonColor=false
    Instance.new("UICorner",bg).CornerRadius=UDim.new(1,0); bg.Parent=f
    if not def then Instance.new("UIStroke",bg).Color=Color3.fromRGB(80,85,130) end
    local kn=Instance.new("Frame"); kn.Size=UDim2.new(0,11,0,11)
    kn.Position=def and UDim2.new(1,-13,0.5,-5) or UDim2.new(0,2,0.5,-5)
    kn.BackgroundColor3=Color3.fromRGB(255,255,255); Instance.new("UICorner",kn).CornerRadius=UDim.new(1,0); kn.Parent=bg
    local knStk=Instance.new("UIStroke",kn); knStk.Color=Color3.fromRGB(0,0,0); knStk.Transparency=0.8; knStk.Thickness=0.5
    local st=def
    bg.MouseButton1Click:Connect(function()
        st=not st; cb(st)
        TweenService:Create(kn,TweenInfo.new(0.25,Enum.EasingStyle.Quart),{Position=st and UDim2.new(1,-13,0.5,-5) or UDim2.new(0,2,0.5,-5)}):Play()
        TweenService:Create(bg,TweenInfo.new(0.25),{BackgroundColor3=st and Color3.fromRGB(55,200,115) or Color3.fromRGB(50,52,80)}):Play()
    end)
end

local function mkSlider(par,text,mn,mx,def,cb)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,28); f.BackgroundTransparency=1; f.Active=true; f.Parent=par
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,12); lbl.BackgroundTransparency=1
    lbl.Text=text..": "..def.."ms"; lbl.TextColor3=Color3.fromRGB(220,225,255)
    lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=8; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=f
    local trBg=Instance.new("Frame"); trBg.Size=UDim2.new(1,0,0,5); trBg.Position=UDim2.new(0,0,0,16)
    trBg.BackgroundColor3=Color3.fromRGB(30,32,55); Instance.new("UICorner",trBg).CornerRadius=UDim.new(1,0); trBg.Parent=f
    local fi=Instance.new("Frame"); fi.Size=UDim2.new((def-mn)/(mx-mn),0,1,0)
    fi.BackgroundColor3=Color3.fromRGB(55,130,255); Instance.new("UICorner",fi).CornerRadius=UDim.new(1,0); fi.Parent=trBg
    local fiGrad=Instance.new("UIGradient",fi); fiGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(80,160,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(40,90,200))})
    local kn=Instance.new("Frame"); kn.Size=UDim2.new(0,11,0,11); kn.Position=UDim2.new(1,-6,0.5,-6)
    kn.BackgroundColor3=Color3.fromRGB(255,255,255); Instance.new("UICorner",kn).CornerRadius=UDim.new(1,0); kn.Parent=fi
    Instance.new("UIStroke",kn).Color=Color3.fromRGB(55,130,255)
    local isd=false
    local function upd(i)
        local p=math.clamp((i.Position.X-trBg.AbsolutePosition.X)/trBg.AbsoluteSize.X,0,1)
        local v=math.floor(mn+((mx-mn)*p)); fi.Size=UDim2.new(p,0,1,0); lbl.Text=text..": "..v.."ms"; cb(v)
    end
    f.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then isd=true; upd(i) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then isd=false end end)
    UserInputService.InputChanged:Connect(function(i) if isd and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then upd(i) end end)
end

mkToggle(P1,"🤖 AUTO PLAY",    App.Config.AutoPlay, function(v) App.Config.AutoPlay=v end)
mkToggle(P1,"👤 AI HUMANIZER", App.Config.Humanize, function(v) App.Config.Humanize=v end)
mkToggle(P1,"🪑 AUTO JOIN",   App.Config.AutoJoin,  function(v) App.Config.AutoJoin=v end)
mkSlider(P1,"⚡ KECEPATAN",1,900,App.Config.TypingDelayMS,function(v) App.Config.TypingDelayMS=v end)

local ModeB=Instance.new("TextButton"); ModeB.Size=UDim2.new(1,0,0,22)
ModeB.BackgroundColor3=Color3.fromRGB(30,40,100); ModeB.BackgroundTransparency=0.3
ModeB.Text="▶ "..App.Config.Playstyle; ModeB.TextColor3=Color3.fromRGB(180,210,255)
ModeB.Font=Enum.Font.GothamBold; ModeB.TextSize=9
Instance.new("UICorner",ModeB).CornerRadius=UDim.new(0,6)
Instance.new("UIStroke",ModeB).Color=Color3.fromRGB(60,100,255); ModeB.Parent=P1
ModeB.MouseButton1Click:Connect(function()
    App.State.StyleIndex=(App.State.StyleIndex%#App.Config.Styles)+1
    App.Config.Playstyle=App.Config.Styles[App.State.StyleIndex]
    ModeB.Text="▶ "..App.Config.Playstyle
    TweenService:Create(ModeB,TweenInfo.new(0.09),{Size=UDim2.new(0.93,0,0,20)}):Play()
    task.wait(0.09); TweenService:Create(ModeB,TweenInfo.new(0.09),{Size=UDim2.new(1,0,0,22)}):Play()
end)

-- ================================================================
-- PANEL 2: SUFFIX — PREMIUM UI
-- ================================================================

-- Helper: rarity label dari optionCount
local function rarityLabel(cnt)
    if cnt==0   then return "☠ DEAD END",Color3.fromRGB(80,255,130)
    elseif cnt<=3  then return "🔥 SANGAT LANGKA",Color3.fromRGB(255,200,50)
    elseif cnt<=10 then return "⚠ LANGKA",Color3.fromRGB(255,140,40)
    elseif cnt<=30 then return "~ AGAK SULIT",Color3.fromRGB(180,200,255)
    else            return "· UMUM",Color3.fromRGB(100,110,140) end
end

-- Header Panel 2
local sfxBannerF=Instance.new("Frame"); sfxBannerF.Size=UDim2.new(1,0,0,28); sfxBannerF.BackgroundTransparency=1; sfxBannerF.Parent=P2
local sfxBannerBg=Instance.new("Frame"); sfxBannerBg.Size=UDim2.new(1,0,1,0); sfxBannerBg.BackgroundColor3=Color3.fromRGB(120,70,10); sfxBannerBg.BackgroundTransparency=0.6; sfxBannerBg.Parent=sfxBannerF
Instance.new("UICorner",sfxBannerBg).CornerRadius=UDim.new(0,6)
Instance.new("UIGradient",sfxBannerBg).Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(200,100,20)),ColorSequenceKeypoint.new(1,Color3.fromRGB(90,40,10))})
local sfxBannerL=Instance.new("TextLabel"); sfxBannerL.Size=UDim2.new(0.65,0,1,0); sfxBannerL.Position=UDim2.new(0,8,0,0); sfxBannerL.BackgroundTransparency=1
sfxBannerL.Text="🎯 TARGET AKHIRAN"; sfxBannerL.TextColor3=Color3.fromRGB(255,200,100); sfxBannerL.Font=Enum.Font.GothamBold; sfxBannerL.TextSize=8; sfxBannerL.TextXAlignment=Enum.TextXAlignment.Left; sfxBannerL.Parent=sfxBannerBg
local SfxCntL=Instance.new("TextLabel"); SfxCntL.Size=UDim2.new(0.34,0,1,0); SfxCntL.Position=UDim2.new(0.65,0,0,0); SfxCntL.BackgroundTransparency=1
SfxCntL.Text="0 aktif"; SfxCntL.TextColor3=Color3.fromRGB(180,140,60); SfxCntL.Font=Enum.Font.GothamBold; SfxCntL.TextSize=8; SfxCntL.TextXAlignment=Enum.TextXAlignment.Right; SfxCntL.Parent=sfxBannerBg
local sfxBannerPad=Instance.new("UIPadding",SfxCntL); sfxBannerPad.PaddingRight=UDim.new(0,6)

-- Trap Meter bar (live rarity dari suffix pertama)
local trapMeterF=Instance.new("Frame"); trapMeterF.Size=UDim2.new(1,0,0,18); trapMeterF.BackgroundTransparency=1; trapMeterF.Parent=P2
local trapMeterBg=Instance.new("Frame"); trapMeterBg.Size=UDim2.new(1,0,1,0); trapMeterBg.BackgroundColor3=Color3.fromRGB(15,16,30); trapMeterBg.BackgroundTransparency=0.2; trapMeterBg.Parent=trapMeterF
Instance.new("UICorner",trapMeterBg).CornerRadius=UDim.new(0,5)
local trapMeterFill=Instance.new("Frame"); trapMeterFill.Size=UDim2.new(0,0,1,0); trapMeterFill.BackgroundColor3=Color3.fromRGB(80,255,130); trapMeterFill.BackgroundTransparency=0.3; trapMeterFill.Parent=trapMeterBg
Instance.new("UICorner",trapMeterFill).CornerRadius=UDim.new(0,5)
local trapMeterLabel=Instance.new("TextLabel"); trapMeterLabel.Size=UDim2.new(1,0,1,0); trapMeterLabel.BackgroundTransparency=1
trapMeterLabel.Text="Pilih suffix untuk melihat efektifitas"; trapMeterLabel.TextColor3=Color3.fromRGB(120,130,160); trapMeterLabel.Font=Enum.Font.GothamSemibold; trapMeterLabel.TextSize=7; trapMeterLabel.Parent=trapMeterBg

-- Chip scroll
local TAG_C={Color3.fromRGB(55,140,255),Color3.fromRGB(255,120,40),Color3.fromRGB(195,75,255),Color3.fromRGB(255,70,110),Color3.fromRGB(40,190,200),Color3.fromRGB(75,200,120)}

local ChipSF=Instance.new("ScrollingFrame"); ChipSF.Size=UDim2.new(1,0,0,22)
ChipSF.BackgroundColor3=Color3.fromRGB(12,14,26); ChipSF.BackgroundTransparency=0.2
ChipSF.ScrollBarThickness=0; ChipSF.CanvasSize=UDim2.new(0,0,0,0); ChipSF.ScrollingDirection=Enum.ScrollingDirection.X
Instance.new("UICorner",ChipSF).CornerRadius=UDim.new(0,6)
local csK=Instance.new("UIStroke",ChipSF); csK.Color=Color3.fromRGB(255,130,40); csK.Transparency=0.65; csK.Thickness=0.8; ChipSF.Parent=P2
local ChipL=Instance.new("UIListLayout"); ChipL.FillDirection=Enum.FillDirection.Horizontal; ChipL.SortOrder=Enum.SortOrder.LayoutOrder
ChipL.Padding=UDim.new(0,4); ChipL.VerticalAlignment=Enum.VerticalAlignment.Center; ChipL.Parent=ChipSF
local cPad=Instance.new("UIPadding",ChipSF); cPad.PaddingLeft=UDim.new(0,5); cPad.PaddingRight=UDim.new(0,5); cPad.PaddingTop=UDim.new(0,4); cPad.PaddingBottom=UDim.new(0,4)

-- Input row
local SfxInputRow=Instance.new("Frame"); SfxInputRow.Size=UDim2.new(1,0,0,22); SfxInputRow.BackgroundTransparency=1; SfxInputRow.Parent=P2
local SfxIn=Instance.new("TextBox"); SfxIn.Size=UDim2.new(0.76,-2,1,0)
SfxIn.BackgroundColor3=Color3.fromRGB(14,16,32); SfxIn.BackgroundTransparency=0.1
SfxIn.Text=App.Config.TargetSuffixRaw; SfxIn.PlaceholderText="tt,ly,cy,ox,ts,ax..."
SfxIn.TextColor3=Color3.fromRGB(255,200,120); SfxIn.PlaceholderColor3=Color3.fromRGB(80,85,120)
SfxIn.Font=Enum.Font.GothamBold; SfxIn.TextSize=8; SfxIn.ClearTextOnFocus=false
Instance.new("UICorner",SfxIn).CornerRadius=UDim.new(0,6)
local sIs=Instance.new("UIStroke",SfxIn); sIs.Color=Color3.fromRGB(255,130,40); sIs.Transparency=0.45; sIs.Thickness=0.8; SfxIn.Parent=SfxInputRow
local SfxClr=Instance.new("TextButton"); SfxClr.Size=UDim2.new(0.23,0,1,0); SfxClr.Position=UDim2.new(0.77,2,0,0)
SfxClr.BackgroundColor3=Color3.fromRGB(180,50,50); SfxClr.BackgroundTransparency=0.3
SfxClr.Text="CLR"; SfxClr.TextColor3=Color3.fromRGB(255,255,255); SfxClr.Font=Enum.Font.GothamBold; SfxClr.TextSize=8
Instance.new("UICorner",SfxClr).CornerRadius=UDim.new(0,6); SfxClr.Parent=SfxInputRow

-- Info box per suffix (detail rarity)
local TrapInfoBg=Instance.new("Frame"); TrapInfoBg.Size=UDim2.new(1,0,0,14); TrapInfoBg.BackgroundColor3=Color3.fromRGB(20,22,42); TrapInfoBg.BackgroundTransparency=0.3; TrapInfoBg.Parent=P2
Instance.new("UICorner",TrapInfoBg).CornerRadius=UDim.new(0,4)
local TrapInfoL=Instance.new("TextLabel"); TrapInfoL.Size=UDim2.new(1,-8,1,0); TrapInfoL.Position=UDim2.new(0,4,0,0); TrapInfoL.BackgroundTransparency=1
TrapInfoL.Text=""; TrapInfoL.TextColor3=Color3.fromRGB(255,180,80); TrapInfoL.Font=Enum.Font.GothamSemibold; TrapInfoL.TextSize=7
TrapInfoL.TextXAlignment=Enum.TextXAlignment.Left; TrapInfoL.Parent=TrapInfoBg

-- Separator + Save row
local Div2=Instance.new("Frame"); Div2.Size=UDim2.new(1,0,0,1); Div2.BackgroundColor3=Color3.fromRGB(255,255,255); Div2.BackgroundTransparency=0.88; Div2.BorderSizePixel=0; Div2.Parent=P2

local SaveRow=Instance.new("Frame"); SaveRow.Size=UDim2.new(1,0,0,20); SaveRow.BackgroundTransparency=1; SaveRow.Parent=P2
local PNIn=Instance.new("TextBox"); PNIn.Size=UDim2.new(0.6,-2,1,0)
PNIn.BackgroundColor3=Color3.fromRGB(13,15,27); PNIn.BackgroundTransparency=0.25
PNIn.Text=""; PNIn.PlaceholderText="Nama profil..."; PNIn.TextColor3=Color3.fromRGB(195,205,255)
PNIn.PlaceholderColor3=Color3.fromRGB(70,70,98); PNIn.Font=Enum.Font.Gotham; PNIn.TextSize=7; PNIn.ClearTextOnFocus=false
Instance.new("UICorner",PNIn).CornerRadius=UDim.new(0,5); PNIn.Parent=SaveRow
local SaveB=Instance.new("TextButton"); SaveB.Size=UDim2.new(0.39,0,1,0); SaveB.Position=UDim2.new(0.61,2,0,0)
SaveB.BackgroundColor3=Color3.fromRGB(45,165,90); SaveB.BackgroundTransparency=0.2
SaveB.Text="Simpan"; SaveB.TextColor3=Color3.fromRGB(255,255,255); SaveB.Font=Enum.Font.GothamBold; SaveB.TextSize=7
Instance.new("UICorner",SaveB).CornerRadius=UDim.new(0,5); SaveB.Parent=SaveRow

local PHdr2=Instance.new("TextLabel"); PHdr2.Size=UDim2.new(1,0,0,11); PHdr2.BackgroundTransparency=1
PHdr2.Text="PROFIL TERSIMPAN"; PHdr2.TextColor3=Color3.fromRGB(255,130,40)
PHdr2.Font=Enum.Font.GothamBold; PHdr2.TextSize=7; PHdr2.TextXAlignment=Enum.TextXAlignment.Left; PHdr2.Parent=P2

local PSF=Instance.new("ScrollingFrame"); PSF.Size=UDim2.new(1,0,0,44)
PSF.BackgroundColor3=Color3.fromRGB(10,12,22); PSF.BackgroundTransparency=0.4; PSF.ScrollBarThickness=2; PSF.CanvasSize=UDim2.new(0,0,0,0)
Instance.new("UICorner",PSF).CornerRadius=UDim.new(0,6)
local psK2=Instance.new("UIStroke",PSF); psK2.Color=Color3.fromRGB(255,130,40); psK2.Transparency=0.75; psK2.Thickness=0.7; PSF.Parent=P2
local PLL=Instance.new("UIListLayout"); PLL.SortOrder=Enum.SortOrder.LayoutOrder; PLL.Padding=UDim.new(0,2); PLL.Parent=PSF
local PPad=Instance.new("UIPadding",PSF); PPad.PaddingTop=UDim.new(0,3); PPad.PaddingLeft=UDim.new(0,3); PPad.PaddingRight=UDim.new(0,3)
PLL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() PSF.CanvasSize=UDim2.new(0,0,0,PLL.AbsoluteContentSize.Y+6) end)

local chipObjs={}
local function refreshChips()
    for _,o in ipairs(chipObjs) do o:Destroy() end; chipObjs={}
    local sfxCount=#App.Config.TargetSuffixes
    SfxCntL.Text=sfxCount>0 and (sfxCount.." aktif") or "0 aktif"
    SfxCntL.TextColor3=sfxCount>0 and Color3.fromRGB(255,200,80) or Color3.fromRGB(180,140,60)
    if sfxCount==0 then
        local ph=Instance.new("TextLabel"); ph.Size=UDim2.new(0,140,1,0); ph.BackgroundTransparency=1
        ph.Text="Ketik akhiran → pisah koma"; ph.TextColor3=Color3.fromRGB(80,85,120); ph.Font=Enum.Font.Gotham; ph.TextSize=7; ph.Parent=ChipSF
        table.insert(chipObjs,ph); ChipSF.CanvasSize=UDim2.new(0,0,0,0)
        TrapInfoL.Text="Belum ada suffix dipilih"
        TrapInfoL.TextColor3=Color3.fromRGB(80,90,120)
        TweenService:Create(trapMeterFill,TweenInfo.new(0.4,Enum.EasingStyle.Quart),{Size=UDim2.new(0,0,1,0)}):Play()
        trapMeterLabel.Text="Pilih suffix untuk melihat efektifitas"
        trapMeterLabel.TextColor3=Color3.fromRGB(120,130,160)
        return
    end
    local tw=10
    for i,sfx in ipairs(App.Config.TargetSuffixes) do
        local cnt=optionCount(sfx)
        local lbl,lcol=rarityLabel(cnt)
        local col=TAG_C[((i-1)%#TAG_C)+1]; local cw=math.max(24,#sfx*8+18)
        local chip=Instance.new("Frame"); chip.Size=UDim2.new(0,cw,0,15); chip.BackgroundColor3=col; chip.BackgroundTransparency=0.55
        Instance.new("UICorner",chip).CornerRadius=UDim.new(0,5)
        local chipStk=Instance.new("UIStroke",chip); chipStk.Color=col; chipStk.Transparency=0.35; chipStk.Thickness=0.8
        chip.Parent=ChipSF
        local cl=Instance.new("TextLabel"); cl.Size=UDim2.new(1,0,1,0); cl.BackgroundTransparency=1
        cl.Text=sfx:upper(); cl.TextColor3=Color3.fromRGB(255,255,255); cl.Font=Enum.Font.GothamBold; cl.TextSize=8; cl.Parent=chip
        table.insert(chipObjs,chip); tw=tw+cw+4
    end
    ChipSF.CanvasSize=UDim2.new(0,tw,0,0)

    -- Update trap meter & info dari suffix pertama
    local sfx1=App.Config.TargetSuffixes[1]
    if sfx1 then
        local cnt=optionCount(sfx1)
        local lbl,lcol=rarityLabel(cnt)
        TrapInfoL.Text=sfx1:upper().." → "..lbl..(cnt>0 and ("  ("..cnt.." opsi)") or "")
        TrapInfoL.TextColor3=lcol

        -- Isi meter (0=mati=100%, banyak opsi=merah/kosong)
        local fillRatio
        if cnt==0 then fillRatio=1
        elseif cnt<=3 then fillRatio=0.85
        elseif cnt<=10 then fillRatio=0.65
        elseif cnt<=30 then fillRatio=0.4
        else fillRatio=0.15 end

        TweenService:Create(trapMeterFill,TweenInfo.new(0.5,Enum.EasingStyle.Quart),{Size=UDim2.new(fillRatio,0,1,0),BackgroundColor3=lcol}):Play()
        trapMeterLabel.Text=(cnt==0 and "💀 PASTIMENANG!" or lbl)
        trapMeterLabel.TextColor3=lcol
    end
end

local function parseSfx(raw)
    App.Config.TargetSuffixRaw=raw; App.Config.TargetSuffixes={}
    for sfx in raw:gmatch("([^,]+)") do
        local c=lower(sfx:match("^%s*(.-)%s*$") or ""); if c~="" then table.insert(App.Config.TargetSuffixes,c) end
    end
    refreshChips()
end
SfxIn.FocusLost:Connect(function() parseSfx(SfxIn.Text) end)
SfxClr.MouseButton1Click:Connect(function()
    SfxIn.Text=""; parseSfx("")
    TweenService:Create(SfxClr,TweenInfo.new(0.1),{BackgroundTransparency=0}):Play()
    task.wait(0.1); TweenService:Create(SfxClr,TweenInfo.new(0.15),{BackgroundTransparency=0.3}):Play()
end)

local profObjs={}; local editIdx=nil
local function renderProfiles()
    for _,o in ipairs(profObjs) do o:Destroy() end; profObjs={}
    if #App.Profiles==0 then
        local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,18); lbl.BackgroundTransparency=1
        lbl.Text="Belum ada profil tersimpan"; lbl.TextColor3=Color3.fromRGB(82,82,112); lbl.Font=Enum.Font.Gotham; lbl.TextSize=7; lbl.Parent=PSF
        table.insert(profObjs,lbl); return
    end
    for i,prof in ipairs(App.Profiles) do
        local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,17)
        row.BackgroundColor3=Color3.fromRGB(20,22,42); row.BackgroundTransparency=editIdx==i and 0.2 or 0.45
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,4); row.Parent=PSF
        if editIdx==i then local hs=Instance.new("UIStroke",row); hs.Color=Color3.fromRGB(255,150,40); hs.Transparency=0.35; hs.Thickness=0.9 end
        table.insert(profObjs,row)
        local nl=Instance.new("TextButton"); nl.Size=UDim2.new(0.55,0,1,0); nl.BackgroundTransparency=1
        nl.Text=prof.name or ("Profil "..i); nl.TextColor3=Color3.fromRGB(255,200,120)
        nl.Font=Enum.Font.GothamSemibold; nl.TextSize=7; nl.TextXAlignment=Enum.TextXAlignment.Left; nl.TextTruncate=Enum.TextTruncate.AtEnd
        Instance.new("UIPadding",nl).PaddingLeft=UDim.new(0,5); nl.Parent=row
        local eb=Instance.new("TextButton"); eb.Size=UDim2.new(0.22,0,0.78,0); eb.Position=UDim2.new(0.56,1,0.11,0)
        eb.BackgroundColor3=Color3.fromRGB(42,108,200); eb.BackgroundTransparency=0.3; eb.Text="✏"
        eb.TextColor3=Color3.fromRGB(255,255,255); eb.Font=Enum.Font.GothamBold; eb.TextSize=9
        Instance.new("UICorner",eb).CornerRadius=UDim.new(0,3); eb.Parent=row
        local db=Instance.new("TextButton"); db.Size=UDim2.new(0.19,0,0.78,0); db.Position=UDim2.new(0.79,1,0.11,0)
        db.BackgroundColor3=Color3.fromRGB(190,48,48); db.BackgroundTransparency=0.3; db.Text="🗑"
        db.TextColor3=Color3.fromRGB(255,255,255); db.Font=Enum.Font.GothamBold; db.TextSize=9
        Instance.new("UICorner",db).CornerRadius=UDim.new(0,3); db.Parent=row
        nl.MouseButton1Click:Connect(function() SfxIn.Text=prof.suffixes or ""; parseSfx(prof.suffixes or ""); PNIn.Text=prof.name or ""; editIdx=i; renderProfiles() end)
        eb.MouseButton1Click:Connect(function() SfxIn.Text=prof.suffixes or ""; parseSfx(prof.suffixes or ""); PNIn.Text=prof.name or ""; editIdx=i; renderProfiles() end)
        db.MouseButton1Click:Connect(function()
            table.remove(App.Profiles,i)
            if editIdx==i then editIdx=nil elseif editIdx and editIdx>i then editIdx=editIdx-1 end
            saveProfiles(); renderProfiles()
        end)
    end
end

SaveB.MouseButton1Click:Connect(function()
    local raw=SfxIn.Text; if raw=="" then return end; parseSfx(raw)
    local nm=PNIn.Text~="" and PNIn.Text or ("Profil "..(#App.Profiles+1))
    if editIdx and App.Profiles[editIdx] then App.Profiles[editIdx].name=nm; App.Profiles[editIdx].suffixes=raw
    else table.insert(App.Profiles,{name=nm,suffixes=raw}); editIdx=#App.Profiles end
    PNIn.Text=""; saveProfiles(); renderProfiles()
    task.spawn(function()
        TweenService:Create(SaveB,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(20,210,85)}):Play()
        task.wait(0.4); TweenService:Create(SaveB,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(45,165,90)}):Play()
    end)
end)

-- ================================================================
-- PANEL 3: TAMBAH KATA CUSTOM
-- ================================================================

-- Header banner
local cwBannerF=Instance.new("Frame"); cwBannerF.Size=UDim2.new(1,0,0,28); cwBannerF.BackgroundTransparency=1; cwBannerF.Parent=P3
local cwBannerBg=Instance.new("Frame"); cwBannerBg.Size=UDim2.new(1,0,1,0); cwBannerBg.BackgroundColor3=Color3.fromRGB(10,80,40); cwBannerBg.BackgroundTransparency=0.45; cwBannerBg.Parent=cwBannerF
Instance.new("UICorner",cwBannerBg).CornerRadius=UDim.new(0,6)
local cwBannerGrad=Instance.new("UIGradient",cwBannerBg); cwBannerGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(30,160,90)),ColorSequenceKeypoint.new(1,Color3.fromRGB(15,60,35))})
local cwBannerL=Instance.new("TextLabel"); cwBannerL.Size=UDim2.new(1,-8,1,0); cwBannerL.Position=UDim2.new(0,8,0,0); cwBannerL.BackgroundTransparency=1
cwBannerL.Text="✏  TAMBAH KATA MANUAL"; cwBannerL.TextColor3=Color3.fromRGB(150,255,180); cwBannerL.Font=Enum.Font.GothamBold; cwBannerL.TextSize=8; cwBannerL.TextXAlignment=Enum.TextXAlignment.Left; cwBannerL.Parent=cwBannerBg

-- Info sub-header
local cwInfoL=Instance.new("TextLabel"); cwInfoL.Size=UDim2.new(1,0,0,14); cwInfoL.BackgroundTransparency=1
cwInfoL.Text="Tambahkan kata yang mungkin tidak ada di KBBI"; cwInfoL.TextColor3=Color3.fromRGB(100,120,100); cwInfoL.Font=Enum.Font.Gotham; cwInfoL.TextSize=7; cwInfoL.TextXAlignment=Enum.TextXAlignment.Left; cwInfoL.Parent=P3

-- Input row
local cwInputRow=Instance.new("Frame"); cwInputRow.Size=UDim2.new(1,0,0,28); cwInputRow.BackgroundTransparency=1; cwInputRow.Parent=P3
local cwIn=Instance.new("TextBox"); cwIn.Size=UDim2.new(0.72,-2,1,0)
cwIn.BackgroundColor3=Color3.fromRGB(12,18,30); cwIn.BackgroundTransparency=0.1
cwIn.Text=""; cwIn.PlaceholderText="Ketik kata di sini..."
cwIn.TextColor3=Color3.fromRGB(150,255,180); cwIn.PlaceholderColor3=Color3.fromRGB(60,80,70)
cwIn.Font=Enum.Font.GothamBold; cwIn.TextSize=9; cwIn.ClearTextOnFocus=false
Instance.new("UICorner",cwIn).CornerRadius=UDim.new(0,7)
local cwInStk=Instance.new("UIStroke",cwIn); cwInStk.Color=Color3.fromRGB(60,180,100); cwInStk.Transparency=0.5; cwInStk.Thickness=0.9; cwIn.Parent=cwInputRow

local cwAddB=Instance.new("TextButton"); cwAddB.Size=UDim2.new(0.27,0,1,0); cwAddB.Position=UDim2.new(0.73,2,0,0)
cwAddB.BackgroundColor3=Color3.fromRGB(40,180,90); cwAddB.BackgroundTransparency=0.15
cwAddB.Text="+ TAMBAH"; cwAddB.TextColor3=Color3.fromRGB(255,255,255); cwAddB.Font=Enum.Font.GothamBold; cwAddB.TextSize=7
Instance.new("UICorner",cwAddB).CornerRadius=UDim.new(0,7)
local cwAddStk=Instance.new("UIStroke",cwAddB); cwAddStk.Color=Color3.fromRGB(60,220,110); cwAddStk.Transparency=0.5; cwAddStk.Thickness=0.8; cwAddB.Parent=cwInputRow

-- Notif box
local cwNotifF=Instance.new("Frame"); cwNotifF.Size=UDim2.new(1,0,0,26); cwNotifF.BackgroundTransparency=1; cwNotifF.Parent=P3
local cwNotifBg=Instance.new("Frame"); cwNotifBg.Size=UDim2.new(1,0,1,0); cwNotifBg.BackgroundColor3=Color3.fromRGB(20,22,40); cwNotifBg.BackgroundTransparency=0.3; cwNotifBg.Parent=cwNotifF
Instance.new("UICorner",cwNotifBg).CornerRadius=UDim.new(0,6)
local cwNotifIcon=Instance.new("TextLabel"); cwNotifIcon.Size=UDim2.new(0,22,1,0); cwNotifIcon.BackgroundTransparency=1
cwNotifIcon.Text=""; cwNotifIcon.Font=Enum.Font.GothamBold; cwNotifIcon.TextSize=12; cwNotifIcon.Parent=cwNotifBg
local cwNotifL=Instance.new("TextLabel"); cwNotifL.Size=UDim2.new(1,-24,1,0); cwNotifL.Position=UDim2.new(0,22,0,0); cwNotifL.BackgroundTransparency=1
cwNotifL.Text="Belum ada aksi"; cwNotifL.TextColor3=Color3.fromRGB(90,95,120); cwNotifL.Font=Enum.Font.GothamSemibold; cwNotifL.TextSize=8; cwNotifL.TextXAlignment=Enum.TextXAlignment.Left; cwNotifL.Parent=cwNotifBg

-- Counter
local cwCounterRow=Instance.new("Frame"); cwCounterRow.Size=UDim2.new(1,0,0,14); cwCounterRow.BackgroundTransparency=1; cwCounterRow.Parent=P3
local cwTotalL=Instance.new("TextLabel"); cwTotalL.Size=UDim2.new(0.5,0,1,0); cwTotalL.BackgroundTransparency=1
cwTotalL.Text="DB: -"; cwTotalL.TextColor3=Color3.fromRGB(80,90,130); cwTotalL.Font=Enum.Font.Gotham; cwTotalL.TextSize=7; cwTotalL.TextXAlignment=Enum.TextXAlignment.Left; cwTotalL.Parent=cwCounterRow
local cwSessionL=Instance.new("TextLabel"); cwSessionL.Size=UDim2.new(0.5,0,1,0); cwSessionL.Position=UDim2.new(0.5,0,0,0); cwSessionL.BackgroundTransparency=1
cwSessionL.Text="Sesi: 0 kata ditambah"; cwSessionL.TextColor3=Color3.fromRGB(80,120,90); cwSessionL.Font=Enum.Font.Gotham; cwSessionL.TextSize=7; cwSessionL.TextXAlignment=Enum.TextXAlignment.Right; cwSessionL.Parent=cwCounterRow

-- Separator
local cwDiv=Instance.new("Frame"); cwDiv.Size=UDim2.new(1,0,0,1); cwDiv.BackgroundColor3=Color3.fromRGB(60,180,100); cwDiv.BackgroundTransparency=0.8; cwDiv.BorderSizePixel=0; cwDiv.Parent=P3

-- Recent custom words list
local cwRecHdr=Instance.new("TextLabel"); cwRecHdr.Size=UDim2.new(1,0,0,12); cwRecHdr.BackgroundTransparency=1
cwRecHdr.Text="KATA YG BARU DITAMBAHKAN"; cwRecHdr.TextColor3=Color3.fromRGB(80,180,110); cwRecHdr.Font=Enum.Font.GothamBold; cwRecHdr.TextSize=7; cwRecHdr.TextXAlignment=Enum.TextXAlignment.Left; cwRecHdr.Parent=P3

local cwRecentSF=Instance.new("ScrollingFrame"); cwRecentSF.Size=UDim2.new(1,0,0,55)
cwRecentSF.BackgroundColor3=Color3.fromRGB(10,18,14); cwRecentSF.BackgroundTransparency=0.3; cwRecentSF.ScrollBarThickness=2; cwRecentSF.CanvasSize=UDim2.new(0,0,0,0)
Instance.new("UICorner",cwRecentSF).CornerRadius=UDim.new(0,6)
local cwRecStk=Instance.new("UIStroke",cwRecentSF); cwRecStk.Color=Color3.fromRGB(40,160,80); cwRecStk.Transparency=0.7; cwRecStk.Thickness=0.7; cwRecentSF.Parent=P3
local cwRecList=Instance.new("UIListLayout"); cwRecList.SortOrder=Enum.SortOrder.LayoutOrder; cwRecList.Padding=UDim.new(0,1); cwRecList.Parent=cwRecentSF
local cwRecPad=Instance.new("UIPadding",cwRecentSF); cwRecPad.PaddingLeft=UDim.new(0,4); cwRecPad.PaddingTop=UDim.new(0,3)
cwRecList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() cwRecentSF.CanvasSize=UDim2.new(0,0,0,cwRecList.AbsoluteContentSize.Y+6) end)

local cwSessionCount=0
local cwRecentItems={}

local function cwNotif(ok,msg)
    if ok then
        cwNotifIcon.Text="✓"; cwNotifIcon.TextColor3=Color3.fromRGB(80,255,130)
        cwNotifBg.BackgroundColor3=Color3.fromRGB(15,40,20)
        cwNotifL.Text=msg; cwNotifL.TextColor3=Color3.fromRGB(130,255,160)
        TweenService:Create(cwNotifBg,TweenInfo.new(0.15),{BackgroundTransparency=0.05}):Play()
        task.wait(2.5); TweenService:Create(cwNotifBg,TweenInfo.new(0.5),{BackgroundTransparency=0.3,BackgroundColor3=Color3.fromRGB(20,22,40)}):Play()
    else
        cwNotifIcon.Text="✕"; cwNotifIcon.TextColor3=Color3.fromRGB(255,90,90)
        cwNotifBg.BackgroundColor3=Color3.fromRGB(40,15,15)
        cwNotifL.Text=msg; cwNotifL.TextColor3=Color3.fromRGB(255,130,130)
        TweenService:Create(cwNotifBg,TweenInfo.new(0.15),{BackgroundTransparency=0.05}):Play()
        task.wait(2.5); TweenService:Create(cwNotifBg,TweenInfo.new(0.5),{BackgroundTransparency=0.3,BackgroundColor3=Color3.fromRGB(20,22,40)}):Play()
    end
end

local function cwAddRecent(word)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-8,0,15); lbl.BackgroundTransparency=1
    lbl.Text="✓  "..word:upper(); lbl.TextColor3=Color3.fromRGB(100,220,140); lbl.Font=Enum.Font.GothamSemibold; lbl.TextSize=8; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.LayoutOrder=-cwSessionCount
    lbl.Parent=cwRecentSF; table.insert(cwRecentItems,lbl)
    if #cwRecentItems>12 then cwRecentItems[1]:Destroy(); table.remove(cwRecentItems,1) end
end

local cwAddCooldown=false
local function doAddCustomWord()
    if cwAddCooldown then return end
    local raw=cwIn.Text
    local lw=lower(raw:match("^%s*(%a+)%s*$") or "")
    if lw=="" or #lw<2 then
        task.spawn(function()
            cwNotif(false,"Masukkan kata yang valid (huruf saja)")
        end)
        return
    end

    cwAddCooldown=true

    -- Cek apakah kata sudah ada di DB (in-memory = sudah di bankword)
    if App.DB.KnownWords[lw] then
        task.spawn(function()
            -- Flash input merah
            TweenService:Create(cwInStk,TweenInfo.new(0.15),{Color=Color3.fromRGB(255,60,60)}):Play()
            cwNotif(false,'Sudah ada!  "'..lw:upper()..'"  tidak ditambah lagi')
            task.wait(0.5); TweenService:Create(cwInStk,TweenInfo.new(0.3),{Color=Color3.fromRGB(60,180,100)}):Play()
            cwAddCooldown=false
        end)
        return
    end

    -- Cek juga di blacklist
    if App.State.PermanentBlacklist[lw] then
        task.spawn(function()
            TweenService:Create(cwInStk,TweenInfo.new(0.15),{Color=Color3.fromRGB(255,60,60)}):Play()
            cwNotif(false,'"'..lw:upper()..'" ada di blacklist, tidak bisa ditambah')
            task.wait(0.5); TweenService:Create(cwInStk,TweenInfo.new(0.3),{Color=Color3.fromRGB(60,180,100)}):Play()
            cwAddCooldown=false
        end)
        return
    end

    -- Tambahkan ke DB + langsung flush ke file
    local added=addWord(lw,true)
    if added then
        flushWords()  -- langsung tulis, tidak tunggu interval 5 detik
        cwSessionCount=cwSessionCount+1
        cwIn.Text=""
        cwTotalL.Text="DB: "..App.DB.TotalWords.." kata"
        cwSessionL.Text="Sesi: +"..cwSessionCount
        cwAddRecent(lw)
        task.spawn(function()
            TweenService:Create(cwAddB,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(20,230,100)}):Play()
            TweenService:Create(cwInStk,TweenInfo.new(0.15),{Color=Color3.fromRGB(40,255,120)}):Play()
            cwNotif(true,'"'..lw:upper()..'" berhasil ditambahkan ke bankword!')
            task.wait(0.4); TweenService:Create(cwAddB,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(40,180,90)}):Play()
            task.wait(0.3); TweenService:Create(cwInStk,TweenInfo.new(0.4),{Color=Color3.fromRGB(60,180,100)}):Play()
            cwAddCooldown=false
        end)
    else
        task.spawn(function()
            cwNotif(false,"Gagal menambahkan kata (cek format)")
            cwAddCooldown=false
        end)
    end
end

cwAddB.MouseButton1Click:Connect(doAddCustomWord)
cwIn.FocusLost:Connect(function(enterPressed) if enterPressed then doAddCustomWord() end end)

-- ================================================================
-- LEFT PANEL (Book - word list)
-- ================================================================
local LP=Instance.new("Frame")
LP.Size=UDim2.new(0,LP_W,1,-TOP_H); LP.Position=UDim2.new(1,-W-LP_W+4,0,TOP_H)
LP.BackgroundTransparency=1; LP.Parent=MF

local WordSF=Instance.new("ScrollingFrame")
WordSF.Size=UDim2.new(1,-10,1,-10); WordSF.Position=UDim2.new(0,5,0,5)
WordSF.BackgroundTransparency=1; WordSF.ScrollBarThickness=2; WordSF.CanvasSize=UDim2.new(0,0,0,0); WordSF.Parent=LP

local GL=Instance.new("UIGridLayout"); GL.CellSize=UDim2.new(0.47,0,0,20); GL.CellPadding=UDim2.new(0.04,0,0,5)
GL.SortOrder=Enum.SortOrder.LayoutOrder; GL.Parent=WordSF
GL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    WordSF.CanvasSize=UDim2.new(0,0,0,GL.AbsoluteContentSize.Y+8)
end)

-- TOPBAR BUTTONS
local isMini=false; local isBook=false

CloseB.MouseButton1Click:Connect(function()
    TweenService:Create(USc,TweenInfo.new(0.28,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Scale=0}):Play()
    task.wait(0.3); SG:Destroy()
end)
MinB.MouseButton1Click:Connect(function()
    isMini=not isMini
    local targetH=isMini and TOP_H or H
    TweenService:Create(MF,TweenInfo.new(0.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.new(0,isBook and W+LP_W or W,0,targetH)}):Play()
    MinB.Text=isMini and "□" or "—"
end)
BookB.MouseButton1Click:Connect(function()
    if isMini then return end
    isBook=not isBook
    TweenService:Create(MF,TweenInfo.new(0.42,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.new(0,isBook and W+LP_W or W,0,H)}):Play()
    TweenService:Create(BookB,TweenInfo.new(0.2),{TextColor3=isBook and Color3.fromRGB(255,255,255) or Color3.fromRGB(150,200,255)}):Play()
end)

-- ========================================================================
-- [8] WORD BUTTON POOL
-- ========================================================================
local Pool={}
local function getBtn(idx)
    if not Pool[idx] then
        local b=Instance.new("TextButton"); b.BackgroundColor3=Color3.fromRGB(255,255,255); b.BackgroundTransparency=0.9
        b.TextColor3=Color3.fromRGB(255,255,255); b.Font=Enum.Font.GothamMedium; b.TextSize=8
        b.TextTruncate=Enum.TextTruncate.AtEnd; b.AutoButtonColor=false; b.Parent=WordSF
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
        local sk=Instance.new("UIStroke",b); sk.Color=Color3.fromRGB(255,255,255); sk.Transparency=0.85; sk.Thickness=0.7
        b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.18),{BackgroundTransparency=0.68,TextSize=9}):Play() end)
        b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.18),{BackgroundTransparency=0.9,TextSize=8}):Play() end)
        Pool[idx]={b=b,sk=sk,word=""}
        b.MouseButton1Click:Connect(function() if Pool[idx].word~="" then typeWord(Pool[idx].word,b) end end)
    end
    local p=Pool[idx]; p.b.Visible=true; p.b.Interactable=true
    p.b.BackgroundColor3=Color3.fromRGB(255,255,255); p.b.BackgroundTransparency=0.9
    p.b.TextColor3=Color3.fromRGB(255,255,255); p.sk.Color=Color3.fromRGB(255,255,255); p.sk.Transparency=0.85
    return p
end
local function hideAllBtns() for _,p in ipairs(Pool) do p.b.Visible=false; p.word="" end end

-- ========================================================================
-- [9] GENERATION ENGINE
-- ========================================================================
local function genTurn(prefix)
    hideAllBtns()
    local mode=App.Config.Playstyle
    if not prefix or prefix=="" or App.DB.TotalWords==0 then return end
    local lp=lower(prefix); local cands={}; local seen={}

    local function collectWords(pfx)
        for i=#pfx,1,-1 do
            local sp=sub(pfx,1,i)
            for _,di in ipairs(App.DB.PrefixMap[sp] or {}) do
                local w=App.DB.Dictionary[di]
                if w and not seen[w] and not App.State.UsedWords[w]
                   and not App.State.TriedThisTurn[w] and not App.State.PermanentBlacklist[w] then
                    seen[w]=true
                    if sub(w,1,#pfx)==pfx then table.insert(cands,{word=w,score=scoreWord(w,mode)}) end
                end
            end
        end
    end

    collectWords(lp)
    if #cands==0 then
        local savedSfx=App.Config.TargetSuffixes; App.Config.TargetSuffixes={}
        collectWords(lp); App.Config.TargetSuffixes=savedSfx
    end
    if #cands==0 and #lp>1 then
        local sp1=sub(lp,1,1)
        for _,di in ipairs(App.DB.PrefixMap[sp1] or {}) do
            local w=App.DB.Dictionary[di]
            if w and not seen[w] and not App.State.UsedWords[w]
               and not App.State.TriedThisTurn[w] and not App.State.PermanentBlacklist[w] then
                seen[w]=true
                if sub(w,1,1)==sp1 then table.insert(cands,{word=w,score=scoreWord(w,mode)}) end
            end
        end
    end

    table.sort(cands,function(a,b) return a.score>b.score end)
    local uiB={}
    for i=1,math.min(150,#cands) do
        local p=getBtn(i); p.word=cands[i].word; p.b.Text=p.word:upper().." ("..#p.word..")"
        uiB[i]=p.b; p.b.Size=UDim2.new(0.47,0,0,0)
        TweenService:Create(p.b,TweenInfo.new(0.2+(i*0.007),Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.new(0.47,0,0,20)}):Play()
    end
    if App.Config.AutoPlay and #cands>0 and not App.State.BotExecuting then
        App.State.BotExecuting=true
        task.spawn(function()
            local sg=stage(); local mn=sg=="early" and 200 or sg=="mid" and 140 or 90; local mx=sg=="early" and 500 or sg=="mid" and 360 or 250
            task.wait(random(mn,mx)/1000)
            for i=1,math.min(100,#cands) do
                if not App.State.IsMyTurn or not App.Config.AutoPlay then break end
                local tw=cands[i].word; updateStatus(tw:upper(),Color3.fromRGB(200,230,255))
                local ok=typeWord(tw,uiB[i])
                if ok then App.State.RoundCount=App.State.RoundCount+1; break end
                if App.State.IsMyTurn and App.Config.AutoPlay then task.wait(0.1) end
            end
            App.State.BotExecuting=false
        end)
    end
end

-- ========================================================================
-- [10] CLOUD SYNC
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
-- [11] INIT
-- ========================================================================
loadProfiles(); renderProfiles(); refreshChips()

task.spawn(function()
    if isfile and isfile(BLACK_F) then
        pcall(function()
            for line in readfile(BLACK_F):gmatch("[^\r\n]+") do
                local lw=lower(line:match("^%s*(%a+)%s*$") or ""); if lw~="" then App.State.PermanentBlacklist[lw]=true end
            end
        end)
    end
    if isfile and isfile(INDEX_F) then
        pcall(function()
            for line in readfile(INDEX_F):gmatch("[^\r\n]+") do
                local lw=lower(line:match("^%s*(%a+)%s*$") or ""); if lw~="" then App.State.IndexUsed[lw]=true end
            end
        end)
    end
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
    if bank~="" then
        local batch=0
        for line in bank:gmatch("[^\r\n]+") do
            local lw=lower(line:match("^%s*(%a+)%s*$") or "")
            if lw~="" and not App.State.PermanentBlacklist[lw] then
                if addWord(lw,false) then batch=batch+1; if batch>=4000 then batch=0; RunService.Heartbeat:Wait() end end
            end
        end
    end
    -- Update counter di Panel 3 setelah DB load
    cwTotalL.Text="DB: "..App.DB.TotalWords.." kata"
    updateStatus("✅ Siap! "..App.DB.TotalWords.." kata 🔥",Color3.fromRGB(128,255,172))
    task.wait(2); updateStatus()
    -- Refresh suffix chips agar rarity badge akurat post-DB-load
    refreshChips()
    task.spawn(bgSync)
end)

-- ========================================================================
-- [12] REMOTE HANDLERS
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

print("AUTO TYPE V33 Loaded!")
print("HARD_SUFFIX: comma config | Panel 2: Premium Trap Meter | Panel 3: Custom Word Add")
