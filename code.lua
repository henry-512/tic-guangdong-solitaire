-- title:   guangdong_solitaire
-- author:  henry,zachtronics
-- desc:    clone of shenzhen solitaire
-- site:    https://github.com/henry-512/tic-guangdong-solitaire
-- license: MIT License
-- version: 1
-- script:  lua
-- input:   gamepad
-- menu:    New Game

--
-- LIBRARY FUNCTIONS
--

-- pops X elements off the end
function Popx(ar, x)
  local popped = {}
  for _ = 1, x do
    table.insert(popped, 1, table.remove(ar))
  end
  return popped
end

-- pushes `push` onto the end of `ar`
function Pushx(ar, push)
  for _, p in ipairs(push) do
    table.insert(ar, p)
  end
end

--
-- DEBUG FUNCTIONS
--

-- ends the game
function DebugEnd()
  G.deal = 41
  G.slots = { 0, 10, 20 }
  G.home = { 9, 9, 9 }
  G.flower = true
  G.drag = { 4, 4, 4 }
  G.state = 3
end

function DebugGetSeed()
  local s = ''
  for i, c in ipairs(G.deck) do
    if c < 10 then
      s = s .. '0' .. c
    else
      s = s .. c
    end
  end
  trace(s)
end

function DebugSetSeed(s)
  for i = 1, 80, 2 do
    local card = s:sub(i, i + 1)
    G.deck[i // 2] = tonumber(card)
  end
end

--
-- GAME LOGIC FUNCTIONS
--

--0:dragon
--1-9:#s
G = {}
function NewGame()
  G.deck = { 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 20, 20, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 }
  --shuffler
  for i = 40, 2, -1 do
    local j = math.random(i)
    G.deck[i], G.deck[j] = G.deck[j], G.deck[i]
  end
  --debugGetSeed()
  --debugSetSeed('')
  --board
  G.deal = 1
  G.board = { {}, {}, {}, {}, {}, {}, {}, {} }
  --other init
  --pmem(1,pmem(1)+1)
  G.slots = { -1, -1, -1 }
  G.home = { 0, 0, 0 }
  G.flower = false
  G.drag = { 0, 0, 0 }
  G.anim = {}
  G.shake = {}
  G.state = 0
  --CURSOR
  --true if cursor on board
  G.cb = true
  G.cx = 4
  G.cy = 5
  G.cs = 1
  --HAND
  G.hx = 0
  G.hs = 0
  G.hand = nil
  --CONTROLS
  G.reset = 1
end

function CacheMin()
  G.bmin = {}
  for i, col in ipairs(G.board) do
    if #col < 2 then
      G.bmin[i] = #col
    else
      G.bmin[i] = 1
      for row = #col, 2, -1 do
        local t = col[row]
        local b = col[row - 1]
        if not CanStack(b, t) then
          G.bmin[i] = row
          break
        end
      end
    end
  end
end

function IsLocked(slot)
  local card = G.slots[slot]
  return card % 10 == 0 and G.drag[card // 10 + 1] == 4
end

function CanStack(bot, top)
  local bnum = bot % 10
  local tnum = top % 10
  --dragons never stack
  if bnum == 0 or tnum == 0 then
    return false
  end
  --numbers must be sequential
  if tnum ~= bnum - 1 then
    return false
  end
  local bcol = bot // 10
  local tcol = top // 10
  --colors must be different
  if bcol == tcol then
    return false
  end
  return true
end

function TrySendHome(card, board_x, slot, plr)
  --flower can always be homed
  if card == 30 then
    if board_x == 0 then
      G.slots[slot] = -1
    else
      table.remove(G.board[board_x])
    end
    FlyHome(card, board_x, slot, function() G.flower = true end)
    return
  end
  local num = card % 10
  local suit = card // 10 + 1
  --number card
  if num ~= 0 then
    if G.home[suit] == num - 1 then
      if board_x == 0 then
        G.slots[slot] = -1
      else
        table.remove(G.board[board_x])
      end
      FlyHome(card, board_x, slot, function() G.home[suit] = num end)
      return
    end
    --check if this is an automated move
    if not plr then return end
    --find and shake card
    local toFind = G.home[suit] - 9 + 10 * suit
    for x, col in ipairs(G.board) do
      for y, board_card in ipairs(col) do
        if board_card == toFind then
          AddShake(x, y, 0, 2)
          return
        end
      end
    end
    for s, slot_card in ipairs(G.slots) do
      if slot_card == toFind then
        AddShake(0, 0, s, 2)
        return
      end
    end
    --card is already in transit
    return
  end
  --dragon, check for others
  local drags = {}
  local total = 0
  local empty = 0
  for i = 3, 1, -1 do
    if G.slots[i] == card then
      table.insert(drags, { 0, 0, i })
      total = total + 1
      empty = i
    elseif G.slots[i] == -1 then
      empty = i
    end
  end
  for x, col in ipairs(G.board) do
    for y, rc in ipairs(col) do
      if rc == card then
        table.insert(drags, { x, y, 0 })
        if y == #col then
          total = total + 1
        end
      end
    end
  end
  --not all 4 found or no empty slot
  if total ~= 4 then
    for _, d in ipairs(drags) do
      if d[3] == 0 and d[2] ~= #G.board[d[1]] then
        AddShake(d[1], d[2], 0, 2)
      end
    end
    return
  end
  if empty == 0 then
    AddShake(0, 0, math.random(1, 3), 2)
    return
  end
  --remove all dragons, start animation
  local x2, y2 = TransSlot(empty)
  local cb = function()
    G.drag[suit] = 4
    G.slots[empty] = card
  end
  for _, d in ipairs(drags) do
    local x, y, s = table.unpack(d)
    if s == 0 then
      table.remove(G.board[x])
      local x1, y1 = TransBoard(x, y)
      table.insert(G.anim, { card, x1, y1, x2, y2, 1, 20, cb })
      cb = function() end
    else
      G.slots[s] = -1
      local x1, y1 = TransSlot(s)
      table.insert(G.anim, { card, x1, y1, x2, y2, 1, 20, cb })
      cb = function() end
    end
  end
end

function HasWon()
  for i = 1, 3 do
    if G.home[i] ~= 9 or G.drag[i] == 0 then
      return false
    end
  end
  return true
end

function GetCardUnderCursor()
  local card = -1
  if G.cb then
    local col = G.board[G.cx]
    if #col ~= 0 then
      card = col[G.cy]
    end
  else
    card = G.slots[G.cs]
  end
  return card == nil and -1 or card
end

--
-- ANIMATION FUNCTIONS
--

function FlyHome(card, b, s, cb)
  local x2, y2 = TransHome(card // 10 + 1)
  local x1, y1 = 0, 0
  if b == 0 then
    x1, y1 = TransSlot(s)
  else
    x1, y1 = TransBoard(b, #G.board[b] + 1)
  end
  table.insert(G.anim, {
    card,
    x1, y1, x2, y2,
    1, 20, cb
  })
end

function AnimFrameSplit(period, steps)
  return Frame % period // (period / steps)
end

function AnimCircle()
  local circlex = { 0, -1, -1, -1, 0, 1, 1, 1 }
  local circley = { 1, 1, 0, -1, -1, -1, 0, 1 }
  local adjFrame = AnimFrameSplit(60, 8) + 1
  return circlex[adjFrame], circley[adjFrame]
end

--dealer animation
function DealAnim(c)
  local x1, y1 = TransDeck(G.deal)
  local bx = (c - 1) % 8 + 1
  local by = (c - 1) // 8 + 1
  local x2, y2 = TransBoard(bx, by)
  local card = G.deck[c]
  table.insert(G.anim, {
    card,
    x1, y1, x2, y2, 1, 20,
    function()
      G.board[bx][by] = card
      if c == 40 then G.state = 2 end
    end
  })
end

--restart reshuffle
function ReshuffleAnim()
  G.anim = {}
  for x, col in ipairs(G.board) do
    for y, card in ipairs(col) do
      local x1, y1 = TransBoard(x, y)
      local x2, y2 = TransDeck(math.random(1, 41))
      table.insert(G.anim, {
        card, x1, y1, x2, y2, 1, 20, function() end
      })
    end
  end
  G.board = { {}, {}, {}, {}, {}, {}, {}, {} }
  for s, card in ipairs(G.slots) do
    if card ~= -1 then
      local x1, y1 = TransSlot(s)
      local x2, y2 = TransDeck(math.random(1, 41))
      table.insert(G.anim, {
        card, x1, y1, x2, y2, 1, 20, function() end
      })
    end
  end
  G.slots = { -1, -1, -1 }
  G.drag = { 0, 0, 0 }
  for h, card in ipairs(G.home) do
    if card ~= 0 then
      local x1, y1 = TransHome(h)
      local x2, y2 = TransDeck(math.random(1, 41))
      table.insert(G.anim, {
        card + h * 10 - 10, x1, y1, x2, y2, 1, 20, function() end
      })
    end
  end
  G.home = { 0, 0, 0 }
  if G.flower then
    local x1, y1 = TransHome(4)
    local x2, y2 = TransDeck(math.random(1, 41))
    table.insert(G.anim, {
      30, x1, y1, x2, y2, 1, 20, function() end
    })
  end
  G.flower = false
  table.insert(G.anim, { 0, 0, -30, 0, -30, 1, 20, function()
    NewGame()
  end })
end

--endgame reshuffle
function EndingAnim()
  local x2, y2 = TransDeck(G.deal)
  local rcard = math.random(#G.deck)
  local card = G.deck[rcard]
  local suit = card // 10 + 1
  local num = card % 10
  local x1, y1

  --dragon
  if num == 0 then
    --flower
    if suit == 4 then
      x1, y1 = TransHome(4)
      G.flower = false
    else
      --find dragon slot
      local s = 0
      for i = 1, 3 do
        if card == G.slots[i] then
          s = i
        end
      end
      --coords
      x1, y1 = TransSlot(s)
      --remove from slot
      G.drag[suit] = G.drag[suit] - 1
      if G.drag[suit] == 0 then
        G.slots[s] = -1
      end
    end
    --number
  else
    card = G.home[suit] + suit * 10 - 10
    x1, y1 = TransHome(suit)
    --remove from home
    G.home[suit] = G.home[suit] - 1
  end
  table.insert(G.anim, {
    card,
    x1, y1, x2, y2, 1, 40,
    function() G.deal = G.deal - 1 end
  })
  table.remove(G.deck, rcard)
end

--table.insert({card,x1,y1,x2,y2,cf,mf,call})
function RunAnimations()
  for k, anim in pairs(G.anim) do
    local card, x1, y1, x2, y2, cf, mf, call = table.unpack(anim)
    --lerp :)
    local x = x1 + (x2 - x1) * cf // mf
    local y = y1 + (y2 - y1) * cf // mf
    --local y=y1+(x-x1)*(y2-y1)/(x2-x1)
    --inc
    anim[6] = cf + 1
    DrawCard(card, x, y)
    if cf == mf then
      table.remove(G.anim, k)
      --run callback
      call()
    end
  end
  --card shaking
  --{x,y,s,cf,mf}
  for k, anim in pairs(G.shake) do
    anim[5] = anim[5] + 1
    if anim[5] > anim[6] then
      table.remove(G.shake, k)
    end
  end
end

function AddShake(x, y, s, i)
  table.insert(G.shake, { x, y, s, i, 1, 10, math.random(1, 10) })
end

--intensity,frame,delta
function RawShake(x, y, i, f, d)
  return x + math.sin((f + d) / 2) * i, y
end

function Shake(x, y, s, sx, sy)
  for _, shake in pairs(G.shake) do
    if shake[1] == x and shake[2] == y and shake[3] == s then
      return RawShake(sx, sy, shake[4], shake[5], shake[7])
    end
  end
  return sx, sy
end

--
-- RENDERING FUNCTIONS
--

function DrawDeck(c)
  local x, yB = TransDeck(41)
  local _, yT = TransDeck(c)

  line(x + 1, yT, x + 14, yT, 14)
  line(x + 1, yB + 23, x + 14, yB + 23, 14)
  line(x, yT + 1, x, yB + 22, 14)
  line(x + 15, yT + 1, x + 15, yB + 22, 14)
  rect(x + 1, yT + 1, 14, yB - yT + 22, 15)
  --card lines
  for y = yT + 23, yB + 22, 2 do
    line(x + 1, y, x + 14, y, 14)
  end
end

function DrawBlank(x, y)
  line(x + 1, y, x + 14, y, 14)
  line(x + 1, y + 23, x + 14, y + 23, 14)
  line(x, y + 1, x, y + 22, 14)
  line(x + 15, y + 1, x + 15, y + 22, 14)
end

function DrawCard(c, x, y)
  if G.reset > 20 then
    x, y = RawShake(x, y, (G.reset - 20) // 15, G.reset, math.random(0, 10))
  end

  local ctext = { 3, 5, 10, 3 }
  local cart = { 2, 6, 9, 3 }
  local cline = { 2, 6, 9, 3 }
  local cback = { 1, 7, 8, 4 }
  local num = c % 10
  local suit = c // 10 + 1

  local color = cline[suit]
  line(x + 1, y, x + 14, y, color)
  line(x + 1, y + 23, x + 14, y + 23, color)
  line(x, y + 1, x, y + 22, color)
  line(x + 15, y + 1, x + 15, y + 22, color)
  rect(x + 1, y + 1, 14, 22, cback[suit])

  --pallet swap
  poke4(0x3FF0 * 2 + 12, ctext[suit])
  spr(177 + num + 16 * suit, x + 2, y + 2, 0)
  poke4(0x3FF0 * 2 + 12, cart[suit])
  spr(176 + 16 * suit, x + 9, y + 6, 0)
  spr(177 + num, x + 9, y + 2, 0)
  spr(241 + suit, x + 5, y + 17, 0, 1, 1)
  spr(241 + suit, x + 3, y + 17, 0, 1, 0)
  poke4(0x3FF0 * 2 + 12, 12)
end

function DrawCursor(x, y)
  local dx, dy = AnimCircle()
  spr(174, x + 4 + dx, y + 8 + dy, 0)
end

function TransGuide() return 25, 85 end

function TransScore() return 212, 128 end

function TransDeck(c) return 3, 109 - 41 + c end

--translates boardspace to screenspace
function TransBoard(x, y)
  --return x*21+y*3,y*11
  return x * 22 - 19 + y * 3, y * 11 - 8
end

function TransSlot(s)
  --return 5,s*30
  return 200, s * 29 - 26
end

function TransHome(h)
  --return 220,h*30-15
  return 221, h * 29 - 26
end

--
-- TIC80 FUNCTIONS
--

function MENU(index)
  if index == 0 then
    NewGame()
  end
end

function BOOT()
  NewGame()
  Frame = 0
end

function TIC()
  --reset
  if G.state ~= 0 and btn(5) and G.hand == nil then
    G.reset = G.reset + 1
    if G.reset > 120 then
      G.reset = -1000
      ReshuffleAnim()
      G.state = 4
    end
  else
    G.reset = 0
  end

  --statecheck
  if G.state == 0 then
    --awaiting
    for i = 0, 7 do
      if btnp(i) then
        G.state = 1
      end
    end
  end
  if G.state == 1 then
    --dealer
    if Frame % 5 == 0 and G.deal <= 40 then
      DealAnim(G.deal)
      G.deal = G.deal + 1
    end
  elseif G.state == 2 then
    --mainstate
    if HasWon() then
      --pmem(0,pmem(0)+1)
      G.state = 3
    end
  elseif G.state == 3 then
    --shuffle back in
    if Frame % 30 == 0 and #G.deck ~= 0 then
      EndingAnim()
    end
    -- end of shuffler
    if #G.deck == 0 and #G.anim == 0 then
      NewGame()
    end
  end

  --autohome
  if G.state == 2 and G.hand == nil and Frame % 30 == 0 then
    --cache home
    local chome = {}
    local lowest = 9
    for i = 1, 3 do
      lowest = math.min(lowest, G.home[i])
    end
    for i, card in ipairs(G.home) do
      if card <= lowest + 1 and card < 9 then
        chome[card + 1 + i * 10 - 10] = true
      end
    end
    if not G.flower then
      chome[30] = true
    end
    local found = false
    for x, col in ipairs(G.board) do
      local last = col[#col]
      if chome[last] then
        TrySendHome(last, x, 0, false)
        found = true
        break
      end
    end
    if not found then
      for i, card in ipairs(G.slots) do
        if chome[card] then
          TrySendHome(card, 0, i, false)
          break
        end
      end
    end
  end

  --a/z:pickup/drop
  --b/x:reset
  --x/a:switch
  --y/s:home

  --swap cursor
  if btnp(7) then
    --can't swap if hand is large
    if G.hand == nil or #G.hand == 1 then
      G.cb = not G.cb
    end
  end
  --send home
  if btnp(6) and G.hand == nil and G.state == 2 then
    if G.cb then
      local col = G.board[G.cx]
      if G.cy == #col then
        if G.cy ~= 0 then
          TrySendHome(col[G.cy], G.cx, 0, true)
        end
      else
        for y = G.cy + 1, #col do
          AddShake(G.cx, y, 0, 2)
        end
      end
    else
      if G.slots[G.cs] ~= -1 then
        TrySendHome(G.slots[G.cs], 0, G.cs, true)
      end
    end
  end

  CacheMin()

  --move cursor
  if G.cb then
    --xmove, cyclical
    if btnp(2) then G.cx = G.cx < 2 and 8 or G.cx - 1 end
    if btnp(3) then G.cx = G.cx > 7 and 1 or G.cx + 1 end
    if btnp(0) then G.cy = G.cy - 1 end
    if btnp(1) then G.cy = G.cy + 1 end
    G.cy = math.max(math.min(G.cy, #G.board[G.cx]), G.bmin[G.cx])
  else
    if btnp(0) or btnp(2) then
      G.cs = G.cs < 2 and 3 or G.cs - 1
    end
    if btnp(1) or btnp(3) then
      G.cs = G.cs > 2 and 1 or G.cs + 1
    end
  end

  --A: selection, only if no animations
  if btnp(4) and #G.anim == 0 and G.state == 2 then
    --nothing held, pickup card(s)
    if G.hand == nil then
      if G.cb then
        --check for pickup empty space
        if G.cy ~= 0 then
          G.hx = G.cx
          local col = G.board[G.cx]
          --popped
          G.hand = Popx(col, #col - G.cy + 1)
        end
      else
        --pickup from empty space, if not locked
        if G.slots[G.cs] ~= -1 then
          if IsLocked(G.cs) then
            AddShake(0, 0, G.cs, 2)
          else
            G.hand = { G.slots[G.cs] }
            G.slots[G.cs] = -1
            G.hs = G.cs
          end
        end
      end
      --something held
    else
      if G.cb then
        local col = G.board[G.cx]
        if #col == 0 then
          G.board[G.cx] = G.hand
          G.hand = nil
          G.hx = 0
          G.hs = 0
        elseif CanStack(col[#col], G.hand[1]) then
          Pushx(col, G.hand)
          G.hand = nil
          G.hx = 0
          G.hs = 0
        else
          AddShake(G.cx, G.cy, 0, 2)
        end
      else
        --can only put single cards in empty slots
        if #G.hand == 1 and G.slots[G.cs] == -1 then
          G.hs = G.cs
          G.slots[G.cs] = G.hand[1]
          G.hand = nil
          G.hx = 0
          G.hs = 0
        else
          AddShake(0, 0, G.cs, 2)
        end
      end
    end
  end

  --DROP
  if btnp(5) and G.hand ~= nil and G.state == 2 then
    if G.hs ~= 0 then
      AddShake(0, 0, G.hs, 2)
      G.slots[G.hs] = G.hand[1]
      G.hand = nil
      G.hx = 0
      G.hs = 0
    else
      AddShake(G.hx, #G.board[G.hx] + 1, 0, 2)
      Pushx(G.board[G.hx], G.hand)
      G.hand = nil
      G.hx = 0
      G.hs = 0
    end
  end

  cls(0)

  -- any key to deal sprite
  if G.state == 0 then
    spr(32, 34, 40, -1, 1, 0, 0, 16, 4)
  elseif G.state == 3 then
    --hold to reset
    spr(96, 34, 40, -1, 1, 0, 0, 16, 4)
  end

  local card = GetCardUnderCursor()
  local Xmessage = '---'
  if card ~= -1 and G.hand == nil then
    if card % 10 == 0 then
      Xmessage = 'STACK FREE'
    else
      Xmessage = 'STACK HOME'
    end
  end
  local Amessage = '---'
  if G.hand == nil then
    if card ~= -1 then
      Amessage = 'PICK UP'
    end
  else
    Amessage = 'STACK'
  end
  --background
  local messages = {
    'MOVE',
    Amessage,
    G.hand == nil and 'HOLD RESET' or 'DROP',
    Xmessage,
    G.cb and 'MOVE FREE' or 'MOVE BOARD',
  }
  local x, y = TransGuide()
  for i, m in ipairs(messages) do
    local pressed = ((i == 1 and (btn(0) or btn(1) or btn(2)))
      or btn(i + 2)) and 1 or 0
    spr(172 + pressed + i * 16, x, y - 10 + 10 * i, 0)
    print(m, x + 10, y - 9 + 10 * i, 15)
  end
  --spr(0,x+75,y,0,2,0,0,6,2)
  local messages = {
    "Stack each Suit 1-9 in HOME",
    "Stack cards on Board with a\n   different Suit and -1 Value",
    "Each FREE holds any single card",
    "4 Dragons of the same Suit can be\n   Stacked in FREE when exposed",

  }
  print(messages[1], x + 73, y, 15, false, 1, true)
  print(messages[2], x + 73, y + 10, 15, false, 1, true)
  print(messages[3], x + 73, y + 26, 15, false, 1, true)
  print(messages[4], x + 73, y + 36, 15, false, 1, true)

  x, y = TransSlot(4)
  print('FREE', x + 1, y - 4, 15, false, 1, true)
  x, y = TransHome(5)
  print('HOME', x + 1, y - 4, 15, false, 1, true)

  --board
  for by = 1, 12 do
    for bx, col in ipairs(G.board) do
      local sx, sy = TransBoard(bx, by)
      if by == 1 then
        DrawBlank(sx, sy)
      end
      if by <= #col then
        local card = col[by]
        if G.cx == bx and G.cy == by and G.cb and G.hand == nil then
          --card hovered
          -- local x, y = AnimCircle(1, 30, 0)
          local dx, dy = AnimCircle()
          DrawCard(card, sx + dx, sy + dy)
        else
          DrawCard(card, Shake(bx, by, 0, sx, sy))
        end
        --no card in slot
      else
        --drawBlank(sx,sy)
        if by == 1 and G.cb and G.cx == bx and G.hand == nil then
          DrawCursor(sx, sy)
        end
        if G.cb and G.hand ~= nil and G.cx == bx then
          --board hand
          if by - #col <= #G.hand then
            local dx, dy = AnimCircle()
            DrawCard(G.hand[by - #col], sx + dx, sy + dy + 4)
          end
        end
      end
    end
  end

  for i = 1, 3 do
    local sx, sy = TransSlot(i)
    local hx, hy = TransHome(i)
    --slots
    DrawBlank(sx, sy)
    if G.slots[i] == -1 then
      if not G.cb and G.cs == i then
        --cursor
        DrawCursor(sx, sy)
      end
    elseif not G.cb and G.hand == nil and G.cs == i then
      -- local x, y = AnimCircle(1, 30, 0)
      local dx, dy = AnimCircle()
      DrawCard(G.slots[i], sx + dx, sy + dy)
      if IsLocked(i) then
        spr(175, sx + 4 + dx, sy + 9 + dy, 0)
      end
    else
      DrawCard(G.slots[i], Shake(0, 0, i, sx, sy))
      if IsLocked(i) then
        spr(175, sx + 4, sy + 9, 0)
      end
    end
    --slot hand
    if not G.cb and G.hand ~= nil and G.cs == i then
      -- local x, y = AnimCircle(1, 30, 0)
      local dx, dy = AnimCircle()
      DrawCard(G.hand[1], sx + dx, sy + 4 + dy)
    end
    --home
    if G.home[i] == 0 then
      DrawBlank(hx, hy)
      spr(187 + i * 16, hx + 9, hy + 6, 0)
    else
      DrawCard(G.home[i] + i * 10 - 10, hx, hy)
    end
  end
  --flower
  x, y = TransHome(4)
  if G.flower then
    DrawCard(30, x, y)
  else
    DrawBlank(x, y)
    spr(251, x + 9, y + 6, 0)
  end

  --deck
  if G.deal ~= 41 then
    DrawDeck(G.deal)
  else
    DrawBlank(TransDeck(41))
  end

  RunAnimations()

  --game count
  --local x,y=transScore()
  --print(pmem(0)..'/'..pmem(1)-1,x,y,15,false,1,true)

  Frame = Frame + 1
end
