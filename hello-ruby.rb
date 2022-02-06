#!/usr/bin/env ruby

require "curses"
require "matrix"

def onsig(signal)
  Curses.close_screen
  exit signal
end

%w[HUP INT QUIT TERM].each do |sig|
  unless trap(sig, "IGNORE") == "IGNORE"  # previous handler
    trap(sig) {|s| onsig(s) }
  end
end

Curses.init_screen
Curses.nl
Curses.noecho
Curses.curs_set 0

ITERS = 80
EPSILON = 0.001

$palette = nil
$ascii = "·-*#W"

if Curses.has_colors?
  Curses.start_color
  if Curses.colors == 256
    $palette = [88,124,160,196,210,216,229,231]
  end
  if Curses.colors == 16
    $palette = [1,9,11,15]
  end
end

if not $palette == nil 
  $palette.each_with_index do |col, idx|
    Curses.init_pair(idx+1, col, 0)
  end
end

def sdSphere(p, r)
  return p.magnitude - r
end

def vclamp(x, minVal, maxVal)
  if x.respond_to?('map')
    return x.map{ |y| y.clamp(minVal, maxVal)}
  end
  return x.clamp(minVal, maxVal)
end

# https://iquilezles.org/www/articles/distfunctions/distfunctions.htm
def sdOctahedron(p, s)
  pAbs = p.map { |x| x.abs }
  x = pAbs[0]
  y = pAbs[1]
  z = pAbs[2]
  m = x + y + z - s
  if (3.0 * x < m)
    q = Vector[x, y, z]
  elsif (3.0 * y < m)
    q = Vector[y,z,x]
  elsif (3.0 * z < m)
    q = Vector[z,x,y]
  else
    return m * 0.57735027
  end
  
  qx = q[0]
  qy = q[1]
  qz = q[2]
  k = (0.5 * (qz - qy + s)).clamp(0.0, s);
  return Vector[qx,qy-s+k,qz-k].magnitude
end


def scene(p) 
  return sdOctahedron(p, 2)
end

def getCameraRayDir(x,y, camPos, camTarget, fPersp = 2.0)
  camForward = (camTarget - camPos).normalize
  camRight = Vector[0.0, 1.0, 0.0].cross(camForward).normalize
  camUp = camForward.cross(camRight).normalize
  vDir = (x*camRight + y * camUp + fPersp * camForward).normalize 
  return vDir
end

def castRay(rayOrigin, rayDir)
  maxd = 80.0
  t = 0.1
  (ITERS).times do |i|
    h = scene(rayOrigin + rayDir * t)
    break if h < EPSILON * t or t > maxd
    t += h
  end
  return -1.0 if t > maxd
  return t
end

def calcNormal(p)
  c = scene(p)
  eps_x = Vector[EPSILON, 0, 0]
  eps_y = Vector[0, EPSILON, 0]
  eps_z = Vector[0, 0, EPSILON]
  return (Vector[scene(p + eps_x) - c, scene(p + eps_y) - c, scene(p + eps_z) - c]).normalize
end

def getColor(x)
  return 1 + (x.clamp(0.0, 1.0) * ($palette.count - 1)).round
end

def getAsciiChar(x)
  return $ascii[(x.clamp(0.0, 1.0) * ($ascii.length - 1)).round]
end

def draw(camPos, camTarget)
  aspectRatio = Curses.cols / Curses.lines
  zoom = 2
  Curses.lines.times do |y|
    Curses.cols.times do |x|
      x0 = (x - Curses.cols / 2.0) / (Curses.cols / 2.0)
      y0 = (y - Curses.lines / 2.0) / (Curses.lines / 2.0)
      x0 *= 0.6 * zoom * aspectRatio
      y0 *= zoom
      rayDir = getCameraRayDir(x0, y0, camPos, camTarget)
      t = castRay(camPos, rayDir)
      result = 0
      if not t == -1.0
        pos = camPos + rayDir * t
        # Lighting based on the normals
        normal = calcNormal(pos)
        light = Vector[0.5, -2.0, -0.5].normalize
        directionalLight = [normal.dot(light), 0].max
        ambientLight = 0.2

        result = directionalLight + ambientLight
      end

      if not $palette == nil
        Curses.attrset(Curses.color_pair(getColor(result)))
      end
      
      Curses.setpos(y, x)
      Curses.addstr(getAsciiChar(result))
    end
  end
end

# degrees to radiant
def rad(degrees)
  degrees * Math::PI / 180.0
end

$cycle = 0
loop do
  camPos = Vector[Math.sin(rad($cycle * 10.0))*3, -0.5, Math.cos(rad($cycle * 10.0)) * 3]
  camTarget = Vector[0,0,0]
  draw(camPos, camTarget)
  
  $cycle = ($cycle + 1) % 36
  Curses.refresh
  sleep(0.001)
end
