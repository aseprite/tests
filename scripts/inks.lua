-- Copyright (C) 2020-2022  Igara Studio S.A.
--
-- This file is released under the terms of the MIT license.
-- Read LICENSE.txt for more information.

dofile('./test_utils.lua')

local colorModes = { ColorMode.RGB,
                     ColorMode.GRAY,
                     ColorMode.INDEXED }

local pencil = "pencil"
local pc = app.pixelColor

local function gray(g)
  return pc.graya(g, 255)
end

function test_inks(colorMode)
  -- Test ink over a transparent sprite
  local s = Sprite(3, 3, colorMode)
  local p, a, b, c, d
  if colorMode == ColorMode.GRAY then
    p = s.palettes[1]
    a, b, c, d = gray(0), gray(64), gray(128), gray(255)
  else
    p = Palette()
    p:resize(4)
    p:setColor(0, Color(0, 0, 0))
    p:setColor(1, Color(64, 64, 64))
    p:setColor(2, Color(128, 128, 128))
    p:setColor(3, Color(255, 255, 255))
    s:setPalette(p)

    a, b, c, d = 0, 1, 2, 3
    if colorMode == ColorMode.RGB then
      a = p:getColor(a).rgbaPixel
      b = p:getColor(b).rgbaPixel
      c = p:getColor(c).rgbaPixel
      d = p:getColor(d).rgbaPixel
    end
  end

  -- With simple ink opacity doesn't have affect (always the color)
  local opacities = { 0, 128, 255 }
  for i = 1,#opacities do
    expect_img(app.activeImage,
               { 0, 0, 0,
                 0, 0, 0,
                 0, 0, 0 })
    app.useTool{ tool=pencil, color=d, points={ Point(0, 0), Point(2, 2) },
                 ink=Ink.SIMPLE, opacity=opacities[i] }
    expect_img(app.activeImage,
               { d, 0, 0,
                 0, d, 0,
                 0, 0, d })
    if i < #opacities then app.undo() end
  end

  -- Check that painting with transparent index (color) on a
  -- transparent layer (using any value of opacity) with alpha
  -- compositing doesn't modify pixels
  for i = 1,#opacities do
    app.useTool{ tool=pencil, color=0, points={ Point(1, 1) },
                 ink=Ink.ALPHA_COMPOSITING, opacity=opacities[i] }
    expect_img(app.activeImage,
               { d, 0, 0,
                 0, d, 0,
                 0, 0, d })
  end

  -- Convert to background layer
  app.bgColor = Color{ index=0 }
  app.command.BackgroundFromLayer()

  app.useTool{ tool=pencil, color=d, points={ Point(0, 1), Point(2, 1) },
               ink=Ink.ALPHA_COMPOSITING, opacity=64 }
  expect_img(app.activeImage,
             { d, a, a,
               b, d, b,
               a, a, d })

  app.useTool{ tool=pencil, color=d, points={ Point(0, 1) },
               ink=Ink.ALPHA_COMPOSITING, opacity=86 }
  expect_img(app.activeImage,
             { d, a, a,
               c, d, b,
               a, a, d })

  ----------------------------------------------------------------------
  -- Inks with custom brushes

  function test_custom_brush_inks(brushColorMode)
    -- Colors in the brush image (ba, bb, bc, bd)
    local ba, bb, bc, bd
    if brushColorMode == ColorMode.RGB then
      ba = Color(0, 0, 0)
      bb = Color(64, 64, 64)
      bc = Color(128, 128, 128)
      bd = Color(255, 255, 255)
    elseif brushColorMode == ColorMode.GRAY then
      ba, bb, bc, bd = gray(0), gray(64), gray(128), gray(255)
    else
      ba, bb, bc, bd = 0, 1, 2, 3
    end

    local brushImage = Image(2, 2, brushColorMode)
    array_to_pixels({ 0, bd,
                      bc, 0 }, brushImage)
    local brush = Brush(brushImage)

    -- da, db, dc, dd are the final result after painting the custom
    -- brush in the sprite
    local ra, rb, rc, rd
    if s.colorMode ~= ColorMode.INDEXED and
       brushColorMode == ColorMode.INDEXED then
      -- For indexed images we take the index of the brush and use the
      -- sprite palette, we are not sure if this in the future might
      -- change, e.g. having the original palette that was used to
      -- create the brush integrated to the brush itself, in that case
      -- we should convert the brush index using the same brush
      -- palette (instead of the sprite palette).
      --
      -- TODO check BrushInkProcessingBase comment for more information
      if s.colorMode == ColorMode.RGB then
        ra, rb, rc, rd =
          p:getColor(ba).rgbaPixel,
          p:getColor(bb).rgbaPixel,
          p:getColor(bc).rgbaPixel,
          p:getColor(bd).rgbaPixel
      else
        ra, rb, rc, rd =
          p:getColor(ba).grayPixel,
          p:getColor(bb).grayPixel,
          p:getColor(bc).grayPixel,
          p:getColor(bd).grayPixel
      end
    else
      ra, rb, rc, rd = a, b, c, d
    end

    array_to_pixels({ a, a, a,
                      a, a, a,
                      a, a, a }, app.activeImage)

    -- Simple
    expect_img(app.activeImage,
               { a, a, a,
                 a, a, a,
                 a, a, a })
    app.useTool{ tool=pencil, brush=brush, points={ Point(2, 2) },
                 ink=Ink.SIMPLE }
    expect_img(app.activeImage,
               { a, a,  a,
                 a, a,  rd,
                 a, rc, a })

    -- Alpha Compositing
    app.useTool{ tool=pencil, brush=brush, points={ Point(1, 1) },
                 ink=Ink.ALPHA_COMPOSITING, opacity=255 }
    expect_img(app.activeImage,
               {  a, rd,  a,
                 rc,  a, rd,
                  a, rc,  a })

    local qc, qd
    if s.colorMode == ColorMode.GRAY and
       brushColorMode == ColorMode.INDEXED then
      qc = gray(pc.grayaV(rc)/2)
      qd = gray(pc.grayaV(rd)/2)
    else
      qc, qd = rb, rc
    end

    app.useTool{ tool=pencil, brush=brush, points={ Point(1, 2) },
                 ink=Ink.ALPHA_COMPOSITING, opacity=128 }
    expect_img(app.activeImage,
               {  a, rd,  a,
                 rc, qd, rd,
                 qc, rc,  a })

    -- TODO test Lock Alpha, Copy Color+Alpha, Shading...
  end

  for j = 1,#colorModes do
    test_custom_brush_inks(colorModes[j])
  end
end

function test_alpha_compositing_on_indexed_with_full_opacity_and_repeated_colors_in_palette()
  local s = Sprite(1, 1, ColorMode.INDEXED)
  local p = Palette()
  p:resize(5)
  p:setColor(0, Color(0, 0, 0))
  p:setColor(1, Color(64, 64, 64))
  p:setColor(2, Color(128, 128, 128))
  p:setColor(3, Color(128, 128, 128))
  p:setColor(4, Color(255, 255, 255))
  s:setPalette(p)

  local inks = { Ink.SIMPLE, Ink.ALPHA_COMPOSITING }

  -- k=1 -> transparent layer
  -- k=2 -> background layer
  for k=1,2 do
    if k == 2 then app.command.BackgroundFromLayer() end
    --  i=1 -> simple ink
    --  i=2 -> alpha compositing ink
    for i = 1,2 do
      -- j=color index
      for j = 0,4 do
        expect_img(app.activeImage, { 0 })
        app.useTool{ tool="pencil", color=j, points={ Point(0, 0) },
                     ink=inks[i], opacity=255 }
        expect_img(app.activeImage, { j })
        app.undo()
      end
    end
  end
end

for i = 1,#colorModes do
  test_inks(colorModes[i])
end
test_alpha_compositing_on_indexed_with_full_opacity_and_repeated_colors_in_palette()

----------------------------------------------------------------------
-- Test painting with transparent color on indexed
----------------------------------------------------------------------

do
  local s = Sprite(2, 2, ColorMode.INDEXED)
  s.transparentColor = 0
  app.bgColor = 0
  app.command.BackgroundFromLayer()
  assert(app.activeLayer.isBackground)
  expect_img(app.activeImage, { 0, 0,
                                0, 0 })

  app.useTool{ tool="pencil", color=Color{r=0,g=0,b=0},
               points={ Point(0, 0) },
               ink=Ink.SIMPLE }
  expect_img(app.activeImage, { 0, 0,
                                0, 0 })

  -- Test that painting in the background layer with transparent color
  -- with alpha compositing and all opacity=255, will use the transparent
  -- index anyway. Reported here: https://github.com/aseprite/aseprite/issues/3047
  app.useTool{ tool="pencil", color=0,
               points={ Point(0, 0) },
               ink=Ink.ALPHA_COMPOSITING,
               opacity=255 }
  expect_img(app.activeImage, { 0, 0,
                                0, 0 })

  -- Other cases should keep working
  local p = s.palettes[1]

  -- palette with only 3 colors: white, gray (50%), black
  p:setColor(0, Color{ r=255, g=255, b=255 })
  p:setColor(1, Color{ r=128, g=128, b=128 })
  p:setColor(2, Color{ r=0, g=0, b=0 })
  app.useTool{ tool="paint_bucket", color=2,
               points={ Point(0, 0) },
               ink=Ink.SIMPLE }
  expect_img(app.activeImage, { 2, 2,
                                2, 2 })

  -- White over black w/opacity=50% => gray
  app.useTool{ tool="pencil", color=0,
               points={ Point(0, 0) },
               ink=Ink.ALPHA_COMPOSITING,
               opacity=128 }
  expect_img(app.activeImage, { 1, 2,
                                2, 2 })

  -- White over gray w/opacity=51% => white
  app.useTool{ tool="pencil", color=0,
               points={ Point(0, 0) },
               ink=Ink.ALPHA_COMPOSITING,
               opacity=129 }
  expect_img(app.activeImage, { 0, 2,
                                2, 2 })

end
