-- ========================================================================
-- AUTO TYPE V30
-- ========================================================================
-- [FIX] Icon tombol Close/Minimize/Book (tidak lagi render sebagai kotak)
-- [+]   PrefixCount index: hitung kelangkaan awalan kata secara REAL dari DB
-- [+]   Smart Endgame: pilih kata berdasarkan data nyata, bukan tabel statis
-- [+]   Opponent Pattern Reader: deteksi pola 1/2/3 huruf lawan per match
-- [+]   Auto-Join v2: join dari jarak mana saja, pindah meja jika sendirian
-- [+]   LeaveTable support + scan ulang otomatis jika meja lebih baik tersedia
-- [+]   Complete Index + Anti-repeat cross-match (dari V29)
-- [+]   Bankword dedup: kata valid lawan otomatis masuk DB tanpa duplikat
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

-- Forward declaration: updateStatus dipakai sebelum UI didefinisikan
-- Implementasi sebenarnya di-override setelah UI dibuat
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
        -- Cross-match anti-repeat
        CrossMatchEndingCount={}, CrossMatchWordCount={}, MatchCount=0,
        -- Complete Index
        IndexUsed={},
        -- Opponent pattern detection
        -- Rekam panjang ServerLetter per giliran lawan: {1,1,2,2,3,2,...}
        OppPatternHistory = {},
        OppPatternCurrent = 1,   -- perkiraan pola saat ini (panjang prefix lawan)
        -- Auto-join table tracking
        CurrentTableName  = nil, -- nama meja yang kita duduki sekarang
    },
    DB = {
        Dictionary={}, KnownWords={}, PrefixMap={},
        -- PrefixCount[p] = jumlah kata di DB yang DIMULAI dengan prefix p
        -- Digunakan untuk mengukur kelangkaan akhiran kata secara real
        PrefixCount={},
        WordsStartingWith={}, TotalWords=0, NewWordsQueue={},
    },
    Profiles = {},
}

-- ========================================================================
-- [3] FILESYSTEM & CLOUD SYSTEM
-- ========================================================================
local FOLDER    = "WORD"
local BANK_F    = FOLDER.."/BANKWORD.txt"
local BLACK_F   = FOLDER.."/BLACKLIST.txt"
local PROF_F    = FOLDER.."/SUFFIX_PROFILES.json"
local META_F    = FOLDER.."/META.json"
local INDEX_F   = FOLDER.."/INDEX_USED.txt"   -- riwayat kata yang pernah dipakai akun
local DB_URL    = "https://raw.githubusercontent.com/Biasaemail/SAMBUNG-KATA/refs/heads/main/wordlistCLEAN.txt"

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
    local data=table.concat(App.DB.NewWordsQueue,"\n").."\n"
    if appendfile then pcall(appendfile,BANK_F,data)
    elseif writefile and readfile then pcall(function()
        local ex=(isfile and isfile(BANK_F)) and readfile(BANK_F) or ""; writefile(BANK_F,ex..data)
    end) end
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
        -- PrefixCount: real kelangkaan awalan dari seluruh DB
        App.DB.PrefixCount[p]=(App.DB.PrefixCount[p] or 0)+1
    end
    App.DB.WordsStartingWith[sub(lw,1,1)]=(App.DB.WordsStartingWith[sub(lw,1,1)] or 0)+1
    if save then table.insert(App.DB.NewWordsQueue,lw) end
    return true
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
-- [4] AUTO-JOIN V2 — Jarak bebas, prioritas optimal, pindah meja otomatis
-- ========================================================================
-- Nama meja: Table_2P_1..7, Table_4P_1..3, Table_8P
-- Jumlah: 7x 2P, 3x 4P, 1x 8P (total 11 meja di workspace.Tables)

local TABLES_FOLDER = Workspace:WaitForChild("Tables", 5) or Workspace

local function countSeats(model)
    local n = 0
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("Seat") and d.Occupant then n = n + 1 end
    end
    return n
end

local function isTableInGame(model)
    local ig = model:FindFirstChild("InGame")
    return ig and ig.Value == true or false
end

local function getMaxPlayers(name)
    if name:match("2P") then return 2
    elseif name:match("4P") then return 4
    else return 8 end
end

-- Hitung skor prioritas meja (makin tinggi = makin bagus untuk di-join)
-- Prioritas 1: 2P ada 1 pemain (3) → Prioritas 2: 4P ada ≥2 (2) → Prioritas 3: 8P ada ≥4 (1)
local function getTablePriority(model)
    if isTableInGame(model) then return -1 end  -- sedang bermain, jangan join
    local plrs   = countSeats(model)
    local maxP   = getMaxPlayers(model.Name)
    if plrs == 0 or plrs >= maxP then return -1 end  -- kosong atau penuh
    if maxP == 2 and plrs == 1 then return 3 end
    if maxP == 4 and plrs >= 2 then return 2 end
    if maxP == 8 and plrs >= 4 then return 1 end
    return -1
end

local function findBestTable()
    local best, bestPrio = nil, -1
    for _, child in ipairs(TABLES_FOLDER:GetChildren()) do
        if child:IsA("Model") and child.Name:match("^Table_") then
            local prio = getTablePriority(child)
            if prio > bestPrio then
                bestPrio = prio
                best = child.Name
            end
        end
    end
    return best, bestPrio
end

local function doJoin(tableName)
    if remotes:FindFirstChild("JoinTable") then
        remotes.JoinTable:FireServer(tableName)
        App.State.CurrentTableName = tableName
    end
end

local function doLeave()
    -- Remote confirmed via RemoteSpy: "LeaveTable"
    if remotes:FindFirstChild("LeaveTable") then
        remotes.LeaveTable:FireServer()
    end
    App.State.CurrentTableName = nil
end

local function scanAndJoin()
    if not App.Config.AutoJoin then return end

    -- Cek apakah kita sendirian di meja → pindah ke meja yang lebih siap
    if App.State.CurrentTableName and not App.State.MatchActive then
        local curModel = TABLES_FOLDER:FindFirstChild(App.State.CurrentTableName)
        if curModel then
            local plrs = countSeats(curModel)
            if plrs <= 1 then
                local best, prio = findBestTable()
                if best and best ~= App.State.CurrentTableName and prio > 0 then
                    -- updateStatus dipanggil dengan pcall agar tidak crash jika belum init
                    pcall(updateStatus, "Pindah meja: "..best, Color3.fromRGB(255,200,80))
                    doLeave()
                    task.wait(0.5)
                    doJoin(best)
                    return
                end
            end
        end
    end

    if App.State.MatchActive then return end
    if App.State.CurrentTableName then return end

    local best = findBestTable()
    if best then doJoin(best) end
end

-- ChildAdded: instan detect meja baru
TABLES_FOLDER.ChildAdded:Connect(function(child)
    task.wait(0.1)
    if not App.Config.AutoJoin or App.State.MatchActive then return end
    if child:IsA("Model") and child.Name:match("^Table_") then
        local prio = getTablePriority(child)
        if prio > 0 then doJoin(child.Name) end
    end
end)

-- Polling loop — lebih reliable di mobile vs GetPropertyChangedSignal("Occupant")
-- Jalankan setiap 1.5s; cukup cepat untuk detect perubahan meja
task.spawn(function() while true do task.wait(0.5); pcall(scanAndJoin) end end)

-- ========================================================================
-- [5] SCORING ENGINE — Real PrefixCount rarity + Opponent Pattern + Anti-repeat
-- ========================================================================

-- Stage detection
local function stage()
    local sl = #App.State.ServerLetter
    return sl >= 3 and "late" or sl == 2 and "mid"
        or App.State.RoundCount > 12 and "mid" or "early"
end

-- PrefixCount lookup: berapa kata di DB bisa mulai dari prefix ini (data REAL)
local function optionCount(prefix)
    if not prefix or prefix == "" then return 9999 end
    return App.DB.PrefixCount[lower(prefix)] or 0
end

-- HARD_SUFFIX: akhiran yang DIPASTIKAN langka berdasarkan analisis KBBI
-- Digunakan sebagai booster awal sebelum PrefixCount terisi dari DB
-- Format: [suffix] = skor (1-10, makin tinggi = makin mematikan)
local HARD_SUFFIX = {
    -- Konsonan ganda / kluster tidak mungkin jadi awalan Indo
    ["tt"]=10,["rr"]=10,["nn"]=10,["ll"]=10,["mm"]=10,
    ["pp"]=10,["bb"]=10,["dd"]=10,["gg"]=10,["kk"]=10,
    -- Kluster konsonan akhir yang tidak bisa dilanjut
    ["rt"]=9,["lt"]=9,["st"]=9,["nt"]=9,["kt"]=9,["ft"]=9,["pt"]=9,
    ["rks"]=10,["lks"]=10,["nks"]=10,["rpt"]=10,["mpt"]=10,["rps"]=10,
    ["rf"]=9,["lf"]=9,["nf"]=8,["rb"]=9,["lb"]=9,["rq"]=10,["lq"]=10,
    ["rl"]=9,["lk"]=9,["rk"]=9,["sk"]=8,["nk"]=7,
    -- Huruf asing yang tidak lazim jadi awalan
    ["q"]=8,["x"]=8,["xz"]=10,["gx"]=10,
    -- Kluster vokal/konsonan langka
    ["au"]=6,["oo"]=8,["ea"]=7,["oa"]=7,["ae"]=8,["ue"]=7,
    -- Akhiran kata serapan yang sulit dilanjut
    ["ex"]=9,["dex"]=9,["lex"]=9,["tex"]=9,
    ["ks"]=8,["ps"]=8,["pt"]=8,
    ["ly"]=8,["cy"]=9,["ry"]=7,["sy"]=7,["ty"]=7,
    ["psy"]=10,["psy"]=10,
    -- Akhiran 3 huruf yang sangat langka sebagai awalan
    ["lea"]=9,["tid"]=9,["rah"]=8,["hoi"]=9,["die"]=9,
    ["agi"]=8,["pao"]=9,["dex"]=9,
    -- Berakhir konsonan + h (tidak ada kata Indo berawalan "rh","lh" dll)
    ["rh"]=9,["lh"]=9,["nh"]=9,["sh"]=7,["th"]=7,
    -- Akhiran vokal +h
    ["ah"]=6,["oh"]=8,["ih"]=7,["uh"]=8,
}

-- Hitung skor hard suffix sebagai pelengkap PrefixCount
-- Dipakai saat DB belum terisi penuh atau sebagai fallback
local function hardSuffixScore(word)
    if #word < 1 then return 0 end
    local s3 = #word >= 3 and sub(word,-3) or nil
    local s2 = #word >= 2 and sub(word,-2) or nil
    local s1 = sub(word,-1)
    local best = 0
    if s3 then best = math.max(best, (HARD_SUFFIX[s3] or 0) * 20000) end
    if s2 then best = math.max(best, (HARD_SUFFIX[s2] or 0) * 15000) end
    best = math.max(best, (HARD_SUFFIX[s1] or 0) * 8000)
    return best
end

-- Trap score: hybrid PrefixCount (real data) + HARD_SUFFIX (KBBI analysis)
-- Early: last1 | Mid: last2 | Late: last2 + bonus last3
local function trapScore(word)
    if #word < 1 then return 0 end
    local s     = stage()
    local last1 = sub(word, -1)
    local opts1 = optionCount(last1)
    local hss   = hardSuffixScore(word)  -- KBBI-based static bonus

    if s == "early" then
        local dbScore = opts1 == 0 and 800000
            or math.max(500000 - opts1 * 400, 0)
        return math.max(dbScore, hss)
    end

    local last2 = #word >= 2 and sub(word, -2) or last1
    local opts2 = optionCount(last2)
    local base  = 0

    if opts2 == 0 then
        base = 1500000
    elseif opts2 <= 3 then
        base = 900000 + (3 - opts2) * 150000
    elseif opts2 <= 10 then
        base = 400000 + (10 - opts2) * 40000
    else
        if opts1 == 0 then base = 600000
        elseif opts1 <= 3 then base = 200000 + (3 - opts1) * 50000
        else base = math.max(100000 - opts1 * 500, 0) end
    end

    if s == "late" and #word >= 3 then
        local opts3 = optionCount(sub(word, -3))
        if opts3 == 0 then base = base + 500000
        elseif opts3 <= 2 then base = base + 200000 end
    end

    -- Ambil yang lebih tinggi: DB real atau KBBI static
    return math.max(base, hss)
end

-- Opponent Pattern Reader: deteksi pola 1/2/3 huruf lawan
local function recordOpponentPattern(serverLetter)
    local len = #serverLetter
    if len < 1 then return end
    table.insert(App.State.OppPatternHistory, len)
    if #App.State.OppPatternHistory > 20 then
        table.remove(App.State.OppPatternHistory, 1)
    end
    local count = {}
    for i = math.max(1, #App.State.OppPatternHistory - 4), #App.State.OppPatternHistory do
        local v = App.State.OppPatternHistory[i]
        count[v] = (count[v] or 0) + 1
    end
    local best, bestN = 1, 0
    for v, n in pairs(count) do if n > bestN then bestN = n; best = v end end
    App.State.OppPatternCurrent = best
end

-- Anti-repeat: record + penalti per-match & cross-match
local function recordEnding(word)
    if #word < 1 then return end
    local e2 = #word >= 2 and sub(word, -2) or sub(word, -1)
    table.insert(App.State.LastUsedEndings, e2)
    if #App.State.LastUsedEndings > 8 then table.remove(App.State.LastUsedEndings, 1) end
    App.State.CrossMatchEndingCount[e2] = (App.State.CrossMatchEndingCount[e2] or 0) + 1
    App.State.CrossMatchWordCount[word]  = (App.State.CrossMatchWordCount[word]  or 0) + 1
end

local function repeatPenalty(word)
    if #word < 1 then return 0 end
    local e2  = #word >= 2 and sub(word, -2) or sub(word, -1)
    local pen = 0
    for _, v in ipairs(App.State.LastUsedEndings) do
        if v == e2 then pen = pen + 8000 end
    end
    pen = pen + (App.State.CrossMatchWordCount[word]  or 0) * 12000
    pen = pen + math.min((App.State.CrossMatchEndingCount[e2] or 0) * 3000, 60000)
    return pen
end

-- Suffix target bonus
local function sfxBonus(word)
    if #App.Config.TargetSuffixes == 0 then return 0 end
    local b = stage() == "late" and 750000 or stage() == "mid" and 600000 or 500000
    for _, sfx in ipairs(App.Config.TargetSuffixes) do
        if sfx ~= "" and #word >= #sfx and sub(word, -#sfx) == sfx then return b end
    end
    return 0
end

-- Master scoring
local function scoreWord(word, mode)
    local last    = sub(word, -1)
    local oppOpts = optionCount(last)
    local wl      = #word
    local sb      = sfxBonus(word)
    local pen     = repeatPenalty(word)
    local s       = stage()
    local noiseMax = s == "early" and 8000 or s == "mid" and 3000 or 1000
    local ns      = random(1, noiseMax)

    if mode == "Smart Endgame" then
        if oppOpts == 0 then return 9999999 - pen end
        local trap = trapScore(word)
        local base = trap + sb + ns - pen
        base = base + (wl >= 8 and 20000 or wl >= 6 and 10000 or 0)
        return math.max(base, 1)

    elseif mode == "Menang Cepat" then
        if oppOpts == 0 then return 9500000 - pen end
        local rareBonus = oppOpts <= 2 and 350000 or oppOpts <= 5 and 180000
            or oppOpts <= 10 and 70000 or 0
        local shortBonus = math.max(0, (8 - wl)) * 10000
        return math.max(shortBonus + rareBonus + trapScore(word)*0.35 + sb - pen + ns, 1)

    elseif mode == "Longest" then
        local aliveBonus = oppOpts >= 10 and 5000 or oppOpts >= 5 and 2000 or 0
        return math.max(wl * 4200 + aliveBonus + sb - pen + ns, 1)

    elseif mode == "Shortest" then
        if oppOpts == 0 then return 9999999 - pen end
        local shortBonus = wl <= 2 and 80000 or wl <= 3 and 50000 or wl <= 5 and 20000 or 0
        return math.max((20 - wl) * 2500 + shortBonus + sb - pen + ns, 1)

    elseif mode == "Complete Index" then
        local newBonus   = App.State.IndexUsed[word] and 0 or 5000000
        local freshBonus = math.max(0, 100000 - (App.State.CrossMatchWordCount[word] or 0) * 20000)
        return math.max(newBonus + freshBonus + sb + ns, 1)

    else -- Normal: pseudo-random bervariasi tiap match
        local h = 0
        for i = 1, #word do h = (h * 31 + string.byte(word, i)) % 100000 end
        local score = (h + App.State.SessionSeed + App.State.RoundCount*17 + App.State.MatchCount*3331) % 60000
        return math.max(score + sb - pen + ns, 1)
    end
end

-- ========================================================================
-- [6] TYPING ENGINE — FIXED
-- ========================================================================
local function fireSim(str)
    for _,n in ipairs({"UpdateCurrentWord","WordUpdate","BillboardUpdate","UpdateBillboard"}) do
        if remotes:FindFirstChild(n) then remotes[n]:FireServer(str) end
    end
    if remotes:FindFirstChild("TypeSound") then remotes.TypeSound:FireServer() end
end

local TYPO={a={"q","s"},b={"v","n"},c={"x","v"},d={"s","f"},e={"w","r"},f={"d","g"},g={"f","h"},h={"g","j"},i={"u","o"},j={"h","k"},k={"j","l"},l={"k","p"},m={"n","k"},n={"b","m"},o={"i","p"},p={"o","l"},q={"a","w"},r={"e","t"},s={"a","d"},t={"r","y"},u={"y","i"},v={"c","b"},w={"q","e"},x={"z","c"},y={"t","u"},z={"a","x"}}

local function typeWord(word, uiButton)
    if not App.State.IsMyTurn then return false end
    App.State.IsTyping=true; App.State.ValidationResult=nil; App.State.TriedThisTurn[word]=true

    -- ✅ FIX DOUBLE HURUF (FINAL):
    -- fireSim = SET text, bukan append.
    -- Game sudah prepend ServerLetter otomatis di display.
    -- Jadi kalau ServerLetter="b" dan kita fireSim("be") → game tampilkan "b"+"be"="bbe" ✗
    --
    -- Yang benar:
    --   typed mulai dari "" (kosong)
    --   remaining = sub(word, #ServerLetter+1)  → skip prefix
    --   fireSim kirim HANYA bagian setelah prefix
    --   Misal: word="bekuku", ServerLetter="b" → remaining="ekuku"
    --   fireSim("e") → game: "b"+"e"="be" ✓
    --   fireSim("ek") → game: "b"+"ek"="bek" ✓
    local prefixLen = #App.State.ServerLetter
    local remaining = sub(word, prefixLen + 1)
    local typed     = ""   -- ini hanya tracking lokal untuk humanizer typo
    local bd        = App.Config.TypingDelayMS / 1000

    for i = 1, #remaining do
        if not App.State.IsMyTurn then break end
        local ch = sub(remaining, i, i)
        -- Humanizer: typo sementara lalu koreksi
        if App.Config.Humanize and random(1,100)<=15 and TYPO[ch] then
            local t=TYPO[ch]
            fireSim(typed..t[random(1,#t)])   -- kirim typo (tanpa prefix)
            task.wait(bd*1.8)
            fireSim(typed)                    -- hapus typo (kembali ke sebelumnya)
            task.wait(bd*1.8)
        end
        typed = typed..ch
        fireSim(typed)   -- kirim "e", "ek", "eku", dst — game prepend "b" sendiri
        local v = App.Config.Humanize and (random(70,190)/100) or 1
        if App.Config.TypingDelayMS<=10 then RunService.Heartbeat:Wait() else task.wait(bd*v) end
    end

    if App.State.IsMyTurn then
        -- game prepend ServerLetter otomatis → kita cukup kirim suffix
        -- fireSim(typed) = suffix lengkap (misal "ekuku"), game tampil "b"+"ekuku"="bekuku" ✓
        -- SubmitWord juga cukup suffix — game gabungkan sendiri di server
        fireSim(typed)
        task.wait(0.09)
        if remotes:FindFirstChild("SubmitWord") then remotes.SubmitWord:FireServer(remaining) end
        local t=0
        while App.State.ValidationResult==nil and App.State.IsMyTurn and t<15 do task.wait(0.1); t=t+1 end
        if App.State.ValidationResult==nil then App.State.ValidationResult="INVALID" end
        if App.State.ValidationResult=="SUCCESS" then
            App.State.UsedWords[word]=true; App.State.FailCount=0
            App.State.IsTyping=false; recordEnding(word)
            -- Complete Index: catat kata ini sebagai sudah pernah dipakai akun
            if not App.State.IndexUsed[word] then
                App.State.IndexUsed[word] = true
                if appendfile then pcall(appendfile, INDEX_F, word.."\n") end
            end
            return true
        elseif App.State.ValidationResult=="INVALID" then
            App.State.PermanentBlacklist[word]=true
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
-- [7] UI — COMPACT TAB, BOOK PANEL FIXED
-- ========================================================================
--  Layout (dalam MF, AnchorPoint kanan):
--
--  [Normal: width=W]          [Book open: width=W+LP_W]
--  ┌──────────────┐           ┌──────────────────────────────┐
--  │  TOPBAR      │           │  TOPBAR                      │
--  │  status      │           │  status                      │
--  │  TabBar      │           │ [WordList] │  TabBar         │
--  │  P1/P2       │           │ [Buttons ] │  P1/P2          │
--  └──────────────┘           └──────────────────────────────┘
--
-- RightPanel posisi dari KANAN: UDim2(1,-W, 0, TOP_H)
--   → saat MF=W:    x = W-W = 0 (isi penuh)
--   → saat MF=W+LP: x = W+LP-W = LP (di kanan, tidak overlap dengan LP)
-- LeftPanel posisi: UDim2(1,-W-LP_W+4, 0, TOP_H)  
--   → saat MF=W:    x = W-W-LP+4 = 4-LP (tersembunyi, clipped)
--   → saat MF=W+LP: x = W+LP-W-LP+4 = 4 (muncul di kiri)

local uiName = "AutoType_V31"
local pGui = (gethui and gethui()) or CoreGui
for _,n in ipairs({uiName,"AutoType_V30","AutoType_V29","AutoType_V28_Final","AutoType_V28_Tab","AutoType_V28_Ultimate","AutoType_V27_Ultimate"}) do
    if pGui:FindFirstChild(n) then pGui[n]:Destroy() end
end

local SG = Instance.new("ScreenGui")
SG.Name=uiName; SG.ResetOnSpawn=false
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; SG.Parent=pGui

local W    = 172   -- lebar panel utama (kanan)
local LP_W = 168   -- lebar panel kata (kiri/book)
local H    = 215   -- tinggi normal
local TOP_H = 26   -- tinggi topbar

local MF = Instance.new("Frame")
MF.Name="MainFrame"
MF.AnchorPoint=Vector2.new(1,0)
MF.Size=UDim2.new(0,W,0,H)
MF.Position=UDim2.new(0.5,86,0.5,-H/2)
MF.BackgroundColor3=Color3.fromRGB(6,7,12)
MF.BackgroundTransparency=0.22
MF.ClipsDescendants=true; MF.Parent=SG
Instance.new("UICorner",MF).CornerRadius=UDim.new(0,10)
local mStk=Instance.new("UIStroke",MF); mStk.Color=Color3.fromRGB(255,255,255); mStk.Transparency=0.88; mStk.Thickness=0.8

local USc=Instance.new("UIScale",MF); USc.Scale=0.78
TweenService:Create(USc,TweenInfo.new(0.55,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Scale=1}):Play()

-- ── TOP BAR ──────────────────────────────────────────────────────────────
local TB=Instance.new("Frame"); TB.Size=UDim2.new(1,0,0,TOP_H); TB.BackgroundTransparency=1; TB.Active=true; TB.Parent=MF
local TBbg=Instance.new("Frame"); TBbg.Size=UDim2.new(1,0,1,0); TBbg.BackgroundColor3=Color3.fromRGB(255,255,255); TBbg.BackgroundTransparency=0.95; TBbg.BorderSizePixel=0; TBbg.Parent=TB
local TitleL=Instance.new("TextLabel"); TitleL.Size=UDim2.new(0,108,1,0); TitleL.Position=UDim2.new(0,8,0,0)
TitleL.BackgroundTransparency=1; TitleL.Text="AUTO TYPE V31"; TitleL.TextColor3=Color3.fromRGB(255,255,255)
TitleL.Font=Enum.Font.GothamBlack; TitleL.TextSize=10; TitleL.TextXAlignment=Enum.TextXAlignment.Left; TitleL.Parent=TB

-- Drag
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
-- Gunakan karakter ASCII plain agar pasti render di semua font Roblox
-- "x" = close, "_" = minimize, "=" = book (triple bar tidak selalu render)
local CloseB = mkTopBtn("x", -4,  Color3.fromRGB(255,90,90),  Color3.fromRGB(255,30,30))
local MinB   = mkTopBtn("_", -25, Color3.fromRGB(200,200,200),Color3.fromRGB(255,255,255))
local BookB  = mkTopBtn("=", -47, Color3.fromRGB(130,195,255),Color3.fromRGB(255,255,255))

-- ── STATUS BAR ────────────────────────────────────────────────────────────
local SL=Instance.new("TextLabel"); SL.Size=UDim2.new(1,-12,0,12); SL.Position=UDim2.new(0,6,0,TOP_H+1)
SL.BackgroundTransparency=1; SL.Text="⏳ Loading..."; SL.TextColor3=Color3.fromRGB(175,215,255)
SL.Font=Enum.Font.GothamSemibold; SL.TextSize=8; SL.TextXAlignment=Enum.TextXAlignment.Left; SL.Parent=MF

local function updateStatus(msg,col)
    if msg then SL.Text=msg; SL.TextColor3=col or Color3.fromRGB(255,255,255); return end
    if App.State.IsMyTurn then SL.Text="Awalan: "..App.State.ServerLetter:upper(); SL.TextColor3=Color3.fromRGB(128,255,168)
    else SL.Text="Menunggu giliran..."; SL.TextColor3=Color3.fromRGB(175,175,175) end
end

-- ── RIGHT PANEL — posisi dari kanan (kunci agar tidak overlap saat book buka) ──
-- Saat MF=W(172):    x = 172-172 = 0  (isi penuh)
-- Saat MF=W+LP(340): x = 340-172 = 168 (geser kanan, LP muncul di kiri)
local CTRL_Y = TOP_H + 14   -- y mulai content (bawah status)
local CTRL_H = H - CTRL_Y - 5

local RP=Instance.new("Frame")
RP.Size=UDim2.new(0,W,0,CTRL_H)
RP.Position=UDim2.new(1,-W,0,CTRL_Y)
RP.BackgroundTransparency=1; RP.Parent=MF

-- Tab bar
local TabBar=Instance.new("Frame"); TabBar.Size=UDim2.new(1,-8,0,22); TabBar.Position=UDim2.new(0,4,0,0)
TabBar.BackgroundColor3=Color3.fromRGB(18,20,34); TabBar.BackgroundTransparency=0.38; TabBar.Parent=RP
Instance.new("UICorner",TabBar).CornerRadius=UDim.new(0,6)

local TABS={"⚙ Config","🎯 Suffix"}
local tabBtns={}; local tabPanels={}; local activeTab=1

for i,name in ipairs(TABS) do
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1/#TABS,-2,1,-4)
    btn.Position=UDim2.new((i-1)/#TABS,i==1 and 2 or 1,0,2)
    btn.BackgroundColor3=Color3.fromRGB(255,255,255)
    btn.BackgroundTransparency=i==1 and 0.74 or 0.95
    btn.Text=name; btn.TextColor3=i==1 and Color3.fromRGB(255,255,255) or Color3.fromRGB(140,145,170)
    btn.Font=Enum.Font.GothamBold; btn.TextSize=8; btn.AutoButtonColor=false
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,4)
    btn.Parent=TabBar; tabBtns[i]=btn
end

local PANEL_Y = 26
local PANEL_H = CTRL_H - PANEL_Y - 2

local function mkPanel()
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,-8,0,PANEL_H); f.Position=UDim2.new(0,4,0,PANEL_Y)
    f.BackgroundTransparency=1; f.Visible=false; f.Parent=RP; return f
end
local P1=mkPanel(); P1.Visible=true
local P2=mkPanel()
tabPanels={P1,P2}
local P1L=Instance.new("UIListLayout"); P1L.SortOrder=Enum.SortOrder.LayoutOrder; P1L.Padding=UDim.new(0,5); P1L.Parent=P1
local P2L=Instance.new("UIListLayout"); P2L.SortOrder=Enum.SortOrder.LayoutOrder; P2L.Padding=UDim.new(0,4); P2L.Parent=P2

local function switchTab(idx)
    activeTab=idx
    for i,p in ipairs(tabPanels) do
        p.Visible=(i==idx)
        TweenService:Create(tabBtns[i],TweenInfo.new(0.18),{
            BackgroundTransparency=i==idx and 0.74 or 0.95,
            TextColor3=i==idx and Color3.fromRGB(255,255,255) or Color3.fromRGB(140,145,170)
        }):Play()
    end
end
for i,b in ipairs(tabBtns) do b.MouseButton1Click:Connect(function() switchTab(i) end) end

-- ── PANEL 1: CONFIG ────────────────────────────────────────────────────────
local function mkToggle(par,text,def,cb)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,18); f.BackgroundTransparency=1; f.Parent=par
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.72,0,1,0); lbl.BackgroundTransparency=1
    lbl.Text=text; lbl.TextColor3=Color3.fromRGB(228,228,228); lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=9; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=f
    local bg=Instance.new("TextButton"); bg.Size=UDim2.new(0,28,0,14); bg.Position=UDim2.new(1,-28,0.5,-7)
    bg.BackgroundColor3=def and Color3.fromRGB(65,200,115) or Color3.fromRGB(255,255,255)
    bg.BackgroundTransparency=def and 0 or 0.82; bg.Text=""; bg.AutoButtonColor=false
    Instance.new("UICorner",bg).CornerRadius=UDim.new(1,0); bg.Parent=f
    local kn=Instance.new("Frame"); kn.Size=UDim2.new(0,10,0,10)
    kn.Position=def and UDim2.new(1,-12,0.5,-5) or UDim2.new(0,2,0.5,-5)
    kn.BackgroundColor3=Color3.fromRGB(255,255,255); Instance.new("UICorner",kn).CornerRadius=UDim.new(1,0); kn.Parent=bg
    local st=def
    bg.MouseButton1Click:Connect(function()
        st=not st; cb(st)
        TweenService:Create(kn,TweenInfo.new(0.28,Enum.EasingStyle.Quart),{Position=st and UDim2.new(1,-12,0.5,-5) or UDim2.new(0,2,0.5,-5)}):Play()
        TweenService:Create(bg,TweenInfo.new(0.28),{BackgroundTransparency=st and 0 or 0.82,BackgroundColor3=st and Color3.fromRGB(65,200,115) or Color3.fromRGB(255,255,255)}):Play()
    end)
end

local function mkSlider(par,text,mn,mx,def,cb)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,26); f.BackgroundTransparency=1; f.Active=true; f.Parent=par
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,11); lbl.BackgroundTransparency=1
    lbl.Text=text..": "..def.."ms"; lbl.TextColor3=Color3.fromRGB(228,228,228)
    lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=8; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=f
    local tr=Instance.new("Frame"); tr.Size=UDim2.new(1,0,0,4); tr.Position=UDim2.new(0,0,0,14)
    tr.BackgroundColor3=Color3.fromRGB(28,30,48); Instance.new("UICorner",tr).CornerRadius=UDim.new(1,0); tr.Parent=f
    local fi=Instance.new("Frame"); fi.Size=UDim2.new((def-mn)/(mx-mn),0,1,0); fi.BackgroundColor3=Color3.fromRGB(65,200,115)
    Instance.new("UICorner",fi).CornerRadius=UDim.new(1,0); fi.Parent=tr
    local kn=Instance.new("Frame"); kn.Size=UDim2.new(0,10,0,10); kn.Position=UDim2.new(1,-5,0.5,-5)
    kn.BackgroundColor3=Color3.fromRGB(255,255,255); Instance.new("UICorner",kn).CornerRadius=UDim.new(1,0); kn.Parent=fi
    local isd=false
    local function upd(i)
        local p=math.clamp((i.Position.X-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1)
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

local ModeB=Instance.new("TextButton"); ModeB.Size=UDim2.new(1,0,0,21)
ModeB.BackgroundColor3=Color3.fromRGB(255,255,255); ModeB.BackgroundTransparency=0.91
ModeB.Text="Mode: "..App.Config.Playstyle; ModeB.TextColor3=Color3.fromRGB(255,255,255)
ModeB.Font=Enum.Font.GothamBold; ModeB.TextSize=9
Instance.new("UICorner",ModeB).CornerRadius=UDim.new(0,5)
local ms2=Instance.new("UIStroke",ModeB); ms2.Color=Color3.fromRGB(255,255,255); ms2.Transparency=0.85; ms2.Thickness=0.7
ModeB.Parent=P1
ModeB.MouseButton1Click:Connect(function()
    App.State.StyleIndex=(App.State.StyleIndex%#App.Config.Styles)+1
    App.Config.Playstyle=App.Config.Styles[App.State.StyleIndex]; ModeB.Text="Mode: "..App.Config.Playstyle
    TweenService:Create(ModeB,TweenInfo.new(0.09),{Size=UDim2.new(0.94,0,0,19)}):Play()
    task.wait(0.09); TweenService:Create(ModeB,TweenInfo.new(0.09),{Size=UDim2.new(1,0,0,21)}):Play()
end)

-- ── PANEL 2: SUFFIX ─────────────────────────────────────────────────────
-- Layout: [header bar] [chip scroll] [input box] [trap info label] [save row] [profiles]

local TAG_C={Color3.fromRGB(55,140,255),Color3.fromRGB(75,200,120),Color3.fromRGB(255,140,40),Color3.fromRGB(195,75,255),Color3.fromRGB(255,75,110),Color3.fromRGB(40,190,200)}

-- Section header: "TARGET AKHIRAN"
local SfxHdr=Instance.new("Frame"); SfxHdr.Size=UDim2.new(1,0,0,14); SfxHdr.BackgroundTransparency=1; SfxHdr.Parent=P2
local SfxHdrL=Instance.new("TextLabel"); SfxHdrL.Size=UDim2.new(0.7,0,1,0); SfxHdrL.BackgroundTransparency=1
SfxHdrL.Text="TARGET AKHIRAN"; SfxHdrL.TextColor3=Color3.fromRGB(100,160,255)
SfxHdrL.Font=Enum.Font.GothamBold; SfxHdrL.TextSize=7; SfxHdrL.TextXAlignment=Enum.TextXAlignment.Left; SfxHdrL.Parent=SfxHdr
-- Chip info count kanan header
local SfxCntL=Instance.new("TextLabel"); SfxCntL.Size=UDim2.new(0.3,0,1,0); SfxCntL.Position=UDim2.new(0.7,0,0,0)
SfxCntL.BackgroundTransparency=1; SfxCntL.Text="0 aktif"
SfxCntL.TextColor3=Color3.fromRGB(100,120,160); SfxCntL.Font=Enum.Font.Gotham
SfxCntL.TextSize=7; SfxCntL.TextXAlignment=Enum.TextXAlignment.Right; SfxCntL.Parent=SfxHdr

-- Chip scroll
local ChipSF=Instance.new("ScrollingFrame"); ChipSF.Size=UDim2.new(1,0,0,20)
ChipSF.BackgroundColor3=Color3.fromRGB(10,12,22); ChipSF.BackgroundTransparency=0.25
ChipSF.ScrollBarThickness=0; ChipSF.CanvasSize=UDim2.new(0,0,0,0); ChipSF.ScrollingDirection=Enum.ScrollingDirection.X
Instance.new("UICorner",ChipSF).CornerRadius=UDim.new(0,5)
local csK=Instance.new("UIStroke",ChipSF); csK.Color=Color3.fromRGB(85,165,255); csK.Transparency=0.6; csK.Thickness=0.7; ChipSF.Parent=P2
local ChipL=Instance.new("UIListLayout"); ChipL.FillDirection=Enum.FillDirection.Horizontal; ChipL.SortOrder=Enum.SortOrder.LayoutOrder
ChipL.Padding=UDim.new(0,3); ChipL.VerticalAlignment=Enum.VerticalAlignment.Center; ChipL.Parent=ChipSF
local cPad=Instance.new("UIPadding",ChipSF); cPad.PaddingLeft=UDim.new(0,4); cPad.PaddingRight=UDim.new(0,4); cPad.PaddingTop=UDim.new(0,3); cPad.PaddingBottom=UDim.new(0,3)

-- Input row: textbox + clear button
local SfxInputRow=Instance.new("Frame"); SfxInputRow.Size=UDim2.new(1,0,0,20); SfxInputRow.BackgroundTransparency=1; SfxInputRow.Parent=P2
local SfxIn=Instance.new("TextBox"); SfxIn.Size=UDim2.new(0.78,-2,1,0)
SfxIn.BackgroundColor3=Color3.fromRGB(13,15,28); SfxIn.BackgroundTransparency=0.15
SfxIn.Text=App.Config.TargetSuffixRaw; SfxIn.PlaceholderText="Akhiran: tt,ly,cy,ex,rt..."
SfxIn.TextColor3=Color3.fromRGB(230,235,255); SfxIn.PlaceholderColor3=Color3.fromRGB(70,75,105)
SfxIn.Font=Enum.Font.GothamBold; SfxIn.TextSize=8; SfxIn.ClearTextOnFocus=false
Instance.new("UICorner",SfxIn).CornerRadius=UDim.new(0,5)
local sIs=Instance.new("UIStroke",SfxIn); sIs.Color=Color3.fromRGB(85,165,255); sIs.Transparency=0.48; sIs.Thickness=0.7; SfxIn.Parent=SfxInputRow
local SfxClr=Instance.new("TextButton"); SfxClr.Size=UDim2.new(0.21,0,1,0); SfxClr.Position=UDim2.new(0.79,2,0,0)
SfxClr.BackgroundColor3=Color3.fromRGB(200,60,60); SfxClr.BackgroundTransparency=0.3
SfxClr.Text="CLR"; SfxClr.TextColor3=Color3.fromRGB(255,255,255); SfxClr.Font=Enum.Font.GothamBold; SfxClr.TextSize=7
Instance.new("UICorner",SfxClr).CornerRadius=UDim.new(0,5); SfxClr.Parent=SfxInputRow

-- Trap info: tampilkan kelangkaan suffix yang dipilih (real-time setelah DB load)
local TrapInfoL=Instance.new("TextLabel"); TrapInfoL.Size=UDim2.new(1,0,0,10); TrapInfoL.BackgroundTransparency=1
TrapInfoL.Text=""; TrapInfoL.TextColor3=Color3.fromRGB(255,180,80)
TrapInfoL.Font=Enum.Font.Gotham; TrapInfoL.TextSize=7; TrapInfoL.TextXAlignment=Enum.TextXAlignment.Left; TrapInfoL.Parent=P2

local chipObjs={}
local function refreshChips()
    for _,o in ipairs(chipObjs) do o:Destroy() end; chipObjs={}
    local sfxCount = #App.Config.TargetSuffixes
    SfxCntL.Text = sfxCount > 0 and (sfxCount.." aktif") or "0 aktif"
    SfxCntL.TextColor3 = sfxCount > 0 and Color3.fromRGB(100,220,140) or Color3.fromRGB(100,120,160)
    if sfxCount == 0 then
        local ph=Instance.new("TextLabel"); ph.Size=UDim2.new(0,130,1,0); ph.BackgroundTransparency=1
        ph.Text="Ketik akhiran di bawah"; ph.TextColor3=Color3.fromRGB(70,75,105); ph.Font=Enum.Font.Gotham; ph.TextSize=7; ph.Parent=ChipSF
        table.insert(chipObjs,ph); ChipSF.CanvasSize=UDim2.new(0,0,0,0)
        TrapInfoL.Text=""; return
    end
    local tw=8
    for i,sfx in ipairs(App.Config.TargetSuffixes) do
        local col=TAG_C[((i-1)%#TAG_C)+1]; local cw=math.max(20,#sfx*7+12)
        local chip=Instance.new("Frame"); chip.Size=UDim2.new(0,cw,0,14); chip.BackgroundColor3=col; chip.BackgroundTransparency=0.45
        Instance.new("UICorner",chip).CornerRadius=UDim.new(0,4); chip.Parent=ChipSF
        local cl=Instance.new("TextLabel"); cl.Size=UDim2.new(1,0,1,0); cl.BackgroundTransparency=1
        cl.Text=sfx:upper(); cl.TextColor3=Color3.fromRGB(255,255,255); cl.Font=Enum.Font.GothamBold; cl.TextSize=8; cl.Parent=chip
        table.insert(chipObjs,chip); tw=tw+cw+3
    end
    ChipSF.CanvasSize=UDim2.new(0,tw,0,0)
    -- Hitung info kelangkaan untuk suffix pertama
    local sfx1 = App.Config.TargetSuffixes[1]
    if sfx1 then
        local cnt = optionCount(sfx1)
        if cnt == 0 then
            TrapInfoL.Text = sfx1:upper()..": 0 opsi — PASTI MENANG!"
            TrapInfoL.TextColor3 = Color3.fromRGB(80,255,130)
        elseif cnt <= 3 then
            TrapInfoL.Text = sfx1:upper()..": "..cnt.." opsi — Sangat sulit"
            TrapInfoL.TextColor3 = Color3.fromRGB(255,200,50)
        elseif cnt <= 15 then
            TrapInfoL.Text = sfx1:upper()..": "..cnt.." opsi — Agak sulit"
            TrapInfoL.TextColor3 = Color3.fromRGB(255,140,40)
        else
            TrapInfoL.Text = sfx1:upper()..": "..cnt.." opsi"
            TrapInfoL.TextColor3 = Color3.fromRGB(180,180,180)
        end
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

-- Divider
local Div=Instance.new("Frame"); Div.Size=UDim2.new(1,0,0,1); Div.BackgroundColor3=Color3.fromRGB(255,255,255); Div.BackgroundTransparency=0.88; Div.BorderSizePixel=0; Div.Parent=P2

-- Save row
local SaveRow=Instance.new("Frame"); SaveRow.Size=UDim2.new(1,0,0,19); SaveRow.BackgroundTransparency=1; SaveRow.Parent=P2
local PNIn=Instance.new("TextBox"); PNIn.Size=UDim2.new(0.6,-2,1,0)
PNIn.BackgroundColor3=Color3.fromRGB(13,15,27); PNIn.BackgroundTransparency=0.25
PNIn.Text=""; PNIn.PlaceholderText="Nama profil..."; PNIn.TextColor3=Color3.fromRGB(195,205,255)
PNIn.PlaceholderColor3=Color3.fromRGB(70,70,98); PNIn.Font=Enum.Font.Gotham; PNIn.TextSize=7; PNIn.ClearTextOnFocus=false
Instance.new("UICorner",PNIn).CornerRadius=UDim.new(0,4); PNIn.Parent=SaveRow
local SaveB=Instance.new("TextButton"); SaveB.Size=UDim2.new(0.39,0,1,0); SaveB.Position=UDim2.new(0.61,2,0,0)
SaveB.BackgroundColor3=Color3.fromRGB(45,165,90); SaveB.BackgroundTransparency=0.2
SaveB.Text="Simpan"; SaveB.TextColor3=Color3.fromRGB(255,255,255); SaveB.Font=Enum.Font.GothamBold; SaveB.TextSize=7
Instance.new("UICorner",SaveB).CornerRadius=UDim.new(0,4); SaveB.Parent=SaveRow

-- Profiles header
local PHdr=Instance.new("TextLabel"); PHdr.Size=UDim2.new(1,0,0,11); PHdr.BackgroundTransparency=1
PHdr.Text="PROFIL TERSIMPAN"; PHdr.TextColor3=Color3.fromRGB(100,155,230)
PHdr.Font=Enum.Font.GothamBold; PHdr.TextSize=7; PHdr.TextXAlignment=Enum.TextXAlignment.Left; PHdr.Parent=P2

local PSF=Instance.new("ScrollingFrame"); PSF.Size=UDim2.new(1,0,0,52)
PSF.BackgroundColor3=Color3.fromRGB(8,10,18); PSF.BackgroundTransparency=0.42; PSF.ScrollBarThickness=2; PSF.CanvasSize=UDim2.new(0,0,0,0)
Instance.new("UICorner",PSF).CornerRadius=UDim.new(0,5)
local psK=Instance.new("UIStroke",PSF); psK.Color=Color3.fromRGB(255,255,255); psK.Transparency=0.88; psK.Thickness=0.6; PSF.Parent=P2
local PLL=Instance.new("UIListLayout"); PLL.SortOrder=Enum.SortOrder.LayoutOrder; PLL.Padding=UDim.new(0,2); PLL.Parent=PSF
local PPad=Instance.new("UIPadding",PSF); PPad.PaddingTop=UDim.new(0,3); PPad.PaddingLeft=UDim.new(0,3); PPad.PaddingRight=UDim.new(0,3)
PLL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() PSF.CanvasSize=UDim2.new(0,0,0,PLL.AbsoluteContentSize.Y+6) end)

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
        row.BackgroundColor3=Color3.fromRGB(17,21,37); row.BackgroundTransparency=editIdx==i and 0.22 or 0.52
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,4); row.Parent=PSF
        if editIdx==i then local hs=Instance.new("UIStroke",row); hs.Color=Color3.fromRGB(75,168,255); hs.Transparency=0.42; hs.Thickness=0.9 end
        table.insert(profObjs,row)
        local nl=Instance.new("TextButton"); nl.Size=UDim2.new(0.55,0,1,0); nl.BackgroundTransparency=1
        nl.Text=prof.name or ("Profil "..i); nl.TextColor3=Color3.fromRGB(185,205,255)
        nl.Font=Enum.Font.GothamSemibold; nl.TextSize=7; nl.TextXAlignment=Enum.TextXAlignment.Left; nl.TextTruncate=Enum.TextTruncate.AtEnd
        local nlp=Instance.new("UIPadding",nl); nlp.PaddingLeft=UDim.new(0,5); nl.Parent=row
        local eb=Instance.new("TextButton"); eb.Size=UDim2.new(0.24,0,0.8,0); eb.Position=UDim2.new(0.55,2,0.1,0)
        eb.BackgroundColor3=Color3.fromRGB(42,108,200); eb.BackgroundTransparency=0.3; eb.Text="✏"
        eb.TextColor3=Color3.fromRGB(255,255,255); eb.Font=Enum.Font.GothamBold; eb.TextSize=9
        Instance.new("UICorner",eb).CornerRadius=UDim.new(0,3); eb.Parent=row
        local db=Instance.new("TextButton"); db.Size=UDim2.new(0.19,0,0.8,0); db.Position=UDim2.new(0.8,2,0.1,0)
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
        task.wait(0.45); TweenService:Create(SaveB,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(45,165,90)}):Play()
    end)
end)

-- ── LEFT PANEL (Book - word list) ────────────────────────────────────────
-- Posisi dari kanan: saat MF=W → x=W-W-LP_W+4=4-LP_W (tersembunyi, clipped)
--                   saat MF=W+LP_W → x=4 (muncul di kiri, tidak overlap RP)
local LP=Instance.new("Frame")
LP.Size=UDim2.new(0,LP_W,1,-TOP_H)
LP.Position=UDim2.new(1,-W-LP_W+4,0,TOP_H)
LP.BackgroundTransparency=1; LP.Parent=MF

local WordSF=Instance.new("ScrollingFrame")
WordSF.Size=UDim2.new(1,-10,1,-10); WordSF.Position=UDim2.new(0,5,0,5)
WordSF.BackgroundTransparency=1; WordSF.ScrollBarThickness=2; WordSF.CanvasSize=UDim2.new(0,0,0,0); WordSF.Parent=LP

local GL=Instance.new("UIGridLayout"); GL.CellSize=UDim2.new(0.47,0,0,20); GL.CellPadding=UDim2.new(0.04,0,0,5)
GL.SortOrder=Enum.SortOrder.LayoutOrder; GL.Parent=WordSF
GL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    WordSF.CanvasSize=UDim2.new(0,0,0,GL.AbsoluteContentSize.Y+8)
end)

-- ── TOPBAR BUTTONS LOGIC ──────────────────────────────────────────────────
local isMini=false; local isBook=false

CloseB.MouseButton1Click:Connect(function()
    TweenService:Create(USc,TweenInfo.new(0.28,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Scale=0}):Play()
    task.wait(0.3); SG:Destroy()
end)

MinB.MouseButton1Click:Connect(function()
    isMini=not isMini
    -- Collapse ke TOP_H (26px) saja — hanya topbar yg terlihat
    local targetH = isMini and TOP_H or H
    TweenService:Create(MF,TweenInfo.new(0.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
        {Size=UDim2.new(0, isBook and W+LP_W or W, 0, targetH)}):Play()
    MinB.Text = isMini and "□" or "—"
end)

BookB.MouseButton1Click:Connect(function()
    if isMini then return end
    isBook=not isBook
    -- Expand ke kiri: tambah LP_W — RP tetap di kanan, LP muncul di kiri
    TweenService:Create(MF,TweenInfo.new(0.42,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
        {Size=UDim2.new(0, isBook and W+LP_W or W, 0, H)}):Play()
    TweenService:Create(BookB,TweenInfo.new(0.2),
        {TextColor3=isBook and Color3.fromRGB(255,255,255) or Color3.fromRGB(150,200,255)}):Play()
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

    -- Fallback 1: Jika custom suffix menghasilkan 0 kata → cari kata terbaik tanpa suffix filter
    -- Ini mencegah deadlock saat suffix terlalu langka
    if #cands == 0 then
        -- Reset suffix sementara lalu collect ulang
        local savedSfx = App.Config.TargetSuffixes
        App.Config.TargetSuffixes = {}
        collectWords(lp)
        App.Config.TargetSuffixes = savedSfx
    end

    -- Fallback 2: Jika masih 0, relaksasi prefix (cek 1 huruf saja)
    if #cands == 0 and #lp > 1 then
        local sp1 = sub(lp,1,1)
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
-- [10] CLOUD SYNC — Hanya 1x di 5 detik pertama setelah init
-- ========================================================================
local function bgSync()
    task.wait(5)
    updateStatus("🔄 Cek update...", Color3.fromRGB(150, 200, 255))
    local n = fetchNewWords()
    if n > 0 then
        updateStatus("✅ +" .. n .. " kata baru!", Color3.fromRGB(128, 255, 162))
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
    -- Load riwayat kata yang pernah dipakai akun (Complete Index)
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
            if addWord(line,false) then batch=batch+1; if batch>=4000 then batch=0; RunService.Heartbeat:Wait() end end
        end
    end
    updateStatus("✅ Siap! "..App.DB.TotalWords.." kata 🔥", Color3.fromRGB(128,255,172))
    task.wait(2); updateStatus()
    -- Sync 1x di 5 detik pertama — tidak ada periodic loop
    task.spawn(bgSync)
end)

-- ========================================================================
-- [12] REMOTE HANDLERS
-- ========================================================================

-- Helper: catat kata sebagai sudah dipakai dalam match ini
local function markWordUsed(word)
    if not word or type(word) ~= "string" then return end
    local lw = lower(word:match("^%s*(%a+)%s*$") or "")
    if lw and #lw >= 2 then
        App.State.UsedWords[lw] = true
        -- Kalau kata valid dari lawan dan belum di DB → tambahkan ke DB
        if not App.DB.KnownWords[lw] and not App.State.PermanentBlacklist[lw] then
            addWord(lw, true)  -- save=true → masuk antrian tulis ke bankword
        end
    end
end

-- PlayerCorrect: kata DITERIMA (oleh kita atau lawan)
if remotes:FindFirstChild("PlayerCorrect") then
    remotes.PlayerCorrect.OnClientEvent:Connect(function(_, word)
        markWordUsed(word)
        App.State.ValidationResult = "SUCCESS"
    end)
end

-- WordUpdate: game broadcast kata terbaru ke semua client
-- Ini adalah sumber terpercaya untuk kata yang dipakai lawan
if remotes:FindFirstChild("WordUpdate") then
    remotes.WordUpdate.OnClientEvent:Connect(function(word)
        markWordUsed(word)
    end)
end

-- UpdateCurrentWord: update kata saat ini di layar
if remotes:FindFirstChild("UpdateCurrentWord") then
    remotes.UpdateCurrentWord.OnClientEvent:Connect(function(word)
        markWordUsed(word)
    end)
end

-- UsedWordWarn: game mensensor kata (tampil *****) karena sudah pernah dipakai
-- Bukan invalid — cukup tandai sebagai used agar kita tidak pilih kata itu lagi
if remotes:FindFirstChild("UsedWordWarn") then
    remotes.UsedWordWarn.OnClientEvent:Connect(function(word)
        if word and type(word) == "string" then
            local lw = lower(word:match("^%s*(%a+)%s*$") or "")
            if lw and #lw >= 2 then
                App.State.UsedWords[lw] = true
            end
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
            App.State.MatchCount = App.State.MatchCount + 1
            App.State.SessionSeed = random(1, 99999)
            hideAllBtns(); updateStatus()
        elseif cmd=="HideMatchUI" then
            App.State.MatchActive=false; App.State.IsMyTurn=false
            App.State.ServerLetter=""; App.State.ValidationResult="SUCCESS"
            App.State.CurrentTableName=nil
            hideAllBtns(); updateStatus("Match Selesai",Color3.fromRGB(185,185,185))
        elseif cmd=="StartTurn" then
            App.State.IsMyTurn=true; App.State.TriedThisTurn={}; App.State.BotExecuting=false
            updateStatus(); genTurn(App.State.ServerLetter)
        elseif cmd=="EndTurn" then
            App.State.IsMyTurn=false; App.State.ValidationResult="SUCCESS"
            hideAllBtns(); updateStatus()
        elseif cmd=="UpdateServerLetter" then
            local prev = App.State.ServerLetter
            App.State.ServerLetter = value or ""
            updateStatus()
            if App.State.ServerLetter ~= prev then
                recordOpponentPattern(App.State.ServerLetter)
            end
        end
    end)
end

print("AUTO TYPE V31 Loaded!")
print("BugFix: AutoJoin nil-crash | WordUpdate tracking | Fallback suffix | HARD_SUFFIX hybrid")
