-- Copyright (c) 2014, Enrique García Cota
-- All rights reserved.
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
-- 
-- * Redistributions of source code must retain the above copyright notice, this
--   list of conditions and the following disclaimer.
-- 
-- * Redistributions in binary form must reproduce the above copyright notice,
--   this list of conditions and the following disclaimer in the documentation
--   and/or other materials provided with the distribution.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

local anim8 = {}
anim8.__index = anim8
anim8.VERSION = "v2.1.0"

-- local function getDimensions(image)
--   if type(image.getDimensions) == 'function' then
--     return image:getDimensions()
--   end
--   return image:getWidth(), image:getHeight()
-- end

local function newImage(image)
  if type(image) == "string" then
    return love.graphics.newImage(image)
  end
  return image
end

local Grid = {}
Grid.__index = Grid

function Grid:get(left, top, width, height)
  width = width or self.width
  height = height or self.height
  return love.graphics.newQuad(left - 1, top - 1, width, height, self.image:getDimensions())
end

local a = {}
function a.right(f) return function(x,y,w,h) return f(x+w,y) end end
function a.left (f) return function(x,y,w,h) return f(x-w,y) end end
function a.down (f) return function(x,y,w,h) return f(x,y+h) end end
function a.up   (f) return function(x,y,w,h) return f(x,y-h) end end

local moves = {
  right = function(x,y,w,h) return x+w, y   end,
  left  = function(x,y,w,h) return x-w, y   end,
  down  = function(x,y,w,h) return x,   y+h end,
  up    = function(x,y,w,h) return x,   y-w end
}

local function parseSequence(str)
  local sequence, subseq, f, t, s, a, b, c, d
  sequence = {}
  for f,t,s in str:gmatch("(%d+)%-(%d+)(%.%d+)") do
    table.insert(sequence, {tonumber(f), tonumber(t), tonumber(s)})
  end

  if #sequence > 0 then return sequence end

  for f,t,s in str:gmatch("(%d+)%-(%d+)([%a,]+)") do
    subseq = {}
    for a in s:gmatch("([%a,]+)") do
      if a~=',' then table.insert(subseq, moves[a]) end
    end
    table.insert(sequence, {tonumber(f), tonumber(t), subseq})
  end

  if #sequence > 0 then return sequence end

  for f, t in str:gmatch("(%d+)%-(%d+)") do
    table.insert(sequence, {tonumber(f), tonumber(t)})
  end

  if #sequence > 0 then return sequence end

  for f in str:gmatch("(%d+)") do
    table.insert(sequence, {tonumber(f)})
  end
  return sequence
end

function Grid:getFrames(...)
  local frames, f, t, s, all, seq, x, y, dx, dy, w, h
  frames, all = {}, {...}
  dx, dy = self.left, self.top
  w, h = self.width, self.height

  for i=1,#all do
    seq = parseSequence(all[i])
    for j=1,#seq do
      f,t,s = seq[j][1], seq[j][2], seq[j][3]
      t = t or f
      if s then
        x,y = self:getFramePosition(f)
        for k=f, t do
          table.insert(frames, self:get(x,y,w,h))
          if type(s) == 'number' then
            x,y = x+w*s, y
          else
            for l=1, #s do
              x,y = s[l](x,y,w,h)
            end
          end
        end
      else
        for k=f,t do
          table.insert(frames, self[k])
        end
      end
    end
  end

  return frames
end

function Grid:getFramePosition(frame)
  return self.left + ((frame-1) % self.cols) * self.width,
         self.top  + math.floor((frame-1) / self.cols) * self.height
end

local Animation = {}
Animation.__index = Animation

function Animation:clone()
  local new = setmetatable({
    grid       = self.grid,
    frames     = self.frames,
    durations  = self.durations,
    onLoop     = self.onLoop,
    loops      = 0,
    position   = 1,
    timer      = 0,
    status     = 'playing'
  }, anim8)

  new.totalFrames = #self.frames

  return new
end

function Animation:update(dt)
  if self.status ~= 'playing' then return end

  self.timer = self.timer + dt
  local d = self.durations[self.position] or self.durations[1]

  while self.timer >= d do
    self.timer = self.timer - d

    self.position = self.position + 1
    if self.position > self.totalFrames then
      self.loops = self.loops + 1
      if self.onLoop == 'pause' or (type(self.onLoop) == 'number' and self.loops >= self.onLoop) then
        self.position = self.totalFrames
        self:pause()
      else
        self.position = 1
        if type(self.onLoop) == "function" then
          self.onLoop(self)
        end
      end
    end
    d = self.durations[self.position] or self.durations[1]
  end
end

function Animation:gotoFrame(f)
  self.position = f
end

function Animation:draw(image, x, y, r, sx, sy, ox, oy, kx, ky)
  love.graphics.draw(image, self.frames[self.position], x, y, r, sx, sy, ox, oy, kx, ky)
end

function Animation:pause()
  self.status = 'paused'
end

function Animation:resume()
  self.status = 'playing'
end

function Animation:getDimensions()
  return self.frames[self.position]:getViewport()
end

function Animation:getFrame()
  return self.frames[self.position]
end

function Animation:getDuration()
  local total_duration = 0
  for i=1, #self.durations do
    total_duration = total_duration + self.durations[i]
  end
  return total_duration
end

function anim8.newGrid(frameWidth, frameHeight, imageWidth, imageHeight, left, top)
  left = left or 1
  top = top or 1
  local image = newImage(imageWidth)
  local imageW, imageH
  if type(image) == 'userdata' then
    imageW, imageH = image:getDimensions()
  else
    imageW, imageH = imageWidth, imageHeight
    image = nil
  end

  local g = {
    width  = frameWidth,
    height = frameHeight,
    left   = left,
    top    = top,
    cols   = math.floor((imageW - left + 1) / frameWidth),
    rows   = math.floor((imageH - top  + 1) / frameHeight),
    image  = image
  }
  setmetatable(g, Grid)

  for i=1, g.rows * g.cols do
    local x,y = g:getFramePosition(i)
    g[i] = g:get(x,y)
  end

  return function(...) return g:getFrames(...) end
end

function anim8.newAnimation(frames, durations, onLoop)
  if type(frames) == "function" then
    return function(f, d, o) return anim8.newAnimation(frames(f), d, o) end
  end

  local d, a
  if type(durations) == 'number' then
    d = {}
    for i=1, #frames do
      d[i] = durations
    end
  else
    d = durations or {1}
  end

  a = {
    grid       = frames.grid,
    frames     = frames,
    durations  = d,
    onLoop     = onLoop,
    position   = 1,
    timer      = 0,
    loops      = 0,
    status     = 'playing'
  }

  a.totalFrames = #frames
  setmetatable(a, Animation)
  return a
end

return anim8