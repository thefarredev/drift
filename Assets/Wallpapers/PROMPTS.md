# Drift wallpaper prompts

Copy-ready prompts for every wallpaper Drift can use. Each prompt is complete on its own: paste one block into your image generator, generate, upscale, export, and save it here with the file name shown above the block.

## 1. Technical spec (every image)

| Item | Requirement |
| --- | --- |
| Aspect ratio | **16:10** landscape (MacBook screens). If your tool has no 16:10, use 3:2 and crop to 16:10 afterwards. |
| Final size | **5120 × 3200 px**. Covers your 16" MacBook Pro screen (3456 × 2234) and 5K displays with room to spare. Absolute minimum: 3456 × 2160. Your screen is slightly narrower than 16:10, so Drift trims about 3 % off the left and right edges: keep nothing important right at the sides. |
| Upscaling | Generators usually output about 1–2K. Upscale 2–4× with an AI upscaler (the generator's own upscaler, Pixelmator Pro, Topaz, etc.) to reach 5120 × 3200, then crop to exactly 16:10. |
| File format | **JPEG**, quality 85–90 %, **sRGB** colour profile. Target 2–6 MB per file so the git repository stays light. No PNG needed. |
| Folder | `~/Projects/Drift/Assets/Wallpapers/` |
| File names | Exactly as written above each prompt, numbered `_01`, `_02`, `_03`. Lowercase, underscores, `.jpg`. |
| How many | 3 variations per file name to start (use the variation lines under each prompt). |

## 2. Composition rules (why the prompts say what they say)

Drift draws things on top of the wallpaper, so the image has to leave room for them.

- **No falling snow or rain in the image.** Drift draws the snowfall and rain live in the foreground. Weather shows only through the sky, light and ground: snow lying on roofs, wet streets, mist.
- **Calm top strip (top ~4 %).** The menu bar sits there. Keep it simple sky.
- **Calm bottom strip (bottom ~12 %).** The Dock and Drift's settled snow pile sit there. Keep it low-detail ground, water or snow.
- **Main subject in the middle.** Keep the important part inside the central 70 % of the width and between 15 % and 75 % of the height. 16:9 external screens crop a little off the top and bottom.
- **Horizon about 30–40 % up from the bottom.**
- **No large pure-white or very bright areas in the upper two thirds.** Drift's snowflakes are white and must stay visible. Snowy and overcast skies should be mid-tone grey-blue, not white.
- **No text, logos, watermarks, signatures, borders, or people as the main subject.** Tiny distant figures are fine.
- **One consistent style** across all images, so switching between them feels like one app. The style sentence is the same in every prompt.

## 3. Tool notes

- **Midjourney:** paste the prompt, then add `--ar 16:10`. You can also move the "Avoid:" list into `--no ...` (comma separated).
- **ChatGPT / DALL·E, Gemini, Ideogram, Firefly and others:** paste the whole block as it is, including the "Avoid:" sentence, and ask for a wide landscape (16:10, or 3:2 and crop).
- Check the licence of the tool you use allows commercial use, since Drift may be sold.

---

## 4. Prompts

### Snow

**`snow_morning_01.jpg`**
```
A small wooden cabin with a smoking chimney in a snowy pine forest at early morning, fresh deep snow lying on the roof, on the pine branches and across a gentle clearing, the air completely still after the snowfall has stopped. Low pale-gold sunrise light from the left, long soft blue shadows on the snow, mid-tone grey-blue sky with a warm glow near the horizon. Cabin slightly right of centre, horizon about one third from the bottom, calm low-detail snowy ground along the bottom edge, simple sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling snow, snowflakes in the air, rain, text, letters, logos, watermark, signature, frame, border, people in the foreground, pure white sky, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` frozen stream in front of the cabin · `_03` view from higher up, cabin smaller among the trees.

**`snow_day_01.jpg`**
```
A quiet alpine valley in midday winter light, snow lying thick on wooden barns, fences and fir trees, a frozen river winding through the middle, distant snowy mountains under a soft overcast sky, the air calm after the snowfall has stopped. Even, diffused daylight, mid-tone grey-blue sky (not white), cool whites and soft blues on the ground with warm brown wood accents. River leads the eye to the centre, horizon about 40 % from the bottom, calm low-detail snow along the bottom edge, simple sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling snow, snowflakes in the air, rain, text, letters, logos, watermark, signature, frame, border, people in the foreground, pure white sky, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a small stone bridge over the frozen river · `_03` a lone red sleigh parked by a barn.

**`snow_dusk_01.jpg`**
```
A small mountain village at dusk, deep snow covering the roofs, streets and low stone walls, warm orange light glowing from many small windows, a church bell tower in the middle distance, pine-covered slopes behind, the air still and clear after the snowfall. Blue-hour sky fading from deep blue at the top to soft violet and a thin peach glow at the horizon, cool blue snow contrasted with warm window light. Village across the centre, horizon about one third from the bottom, calm low-detail snowy foreground along the bottom edge, simple dark sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling snow, snowflakes in the air, rain, text, letters, logos, watermark, signature, frame, border, people in the foreground, pure white sky, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` seen from a hillside path with a wooden fence · `_03` a small frozen pond reflecting the windows.

**`snow_night_01.jpg`**
```
A frozen lake at night surrounded by snow-covered pine trees, three small log cabins on the far shore with softly lit windows, a clear deep-blue night sky with scattered stars and a thin crescent moon, faint reflections on the smooth ice, the air perfectly still. Cool moonlight on the snow, deep navy and teal tones with small warm amber accents from the windows. Cabins slightly left of centre, shoreline about 35 % from the bottom, smooth dark ice as a calm foreground along the bottom edge, simple dark sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling snow, snowflakes in the air, rain, text, letters, logos, watermark, signature, frame, border, people in the foreground, bright full moon in the top area, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` faint green aurora low over the mountains · `_03` a wooden pier reaching onto the ice.

### Rain

**`rain_day_01.jpg`**
```
A narrow European old-town street just after a rain shower, wet cobblestones shining with soft reflections, a small café with a striped awning and a few empty chairs, green trees and window boxes with red geraniums, puddles in the gaps between stones, overcast grey sky. Soft diffused daylight, cool grey and green tones with warm terracotta and cream façades. Street leads from the bottom centre into the distance, buildings framing left and right, calm wet pavement along the bottom edge, simple grey sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, raindrops, rain streaks, water drops on glass, snowflakes, text, letters, shop signs with words, logos, watermark, signature, frame, border, people in the foreground, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a canal with moored boats instead of the café · `_03` a tram stop with a parked vintage tram.

**`rain_dusk_01.jpg`**
```
A quiet harbour town at dusk after rain, wet wooden pier and stone quay reflecting the first lit lanterns, small fishing boats moored on calm water, colourful houses climbing a hill behind, low heavy clouds breaking up with a band of soft orange light at the horizon. Moody blue-grey tones with warm orange lantern and sky accents. Houses and boats across the centre, waterline about 30 % from the bottom, calm dark water along the bottom edge, simple cloudy sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, raindrops, rain streaks, water drops on glass, snowflakes, text, letters, logos, watermark, signature, frame, border, people in the foreground, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` view from the end of the pier back toward the town · `_03` a small lighthouse on the harbour wall.

**`rain_night_01.jpg`**
```
A narrow old-town alley at night after rain, wet cobblestones reflecting warm yellow streetlamps and glowing windows, stone arches and wooden shutters, potted plants by the doors, damp misty air softening the distance. Deep blue night tones with warm gold reflections, gentle contrast. Alley leads from the bottom centre into the misty distance, buildings framing both sides, calm dark wet pavement along the bottom edge, simple dark sky strip along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, raindrops, rain streaks, water drops on glass, snowflakes, text, letters, shop signs with words, logos, watermark, signature, frame, border, people in the foreground, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a small square with a fountain · `_03` a bridge over a river with lamp reflections.

### Storm

**`storm_01.jpg`**
```
A white lighthouse on dark rocky cliffs under a dramatic stormy sky, heavy layered clouds rolling in from the sea, a single distant lightning bolt far on the horizon, rough grey-green waves breaking against the rocks below, the lighthouse lamp glowing warm. Dark slate, teal and charcoal tones with one warm light accent and a pale flash on the horizon. Lighthouse slightly right of centre, sea horizon about 35 % from the bottom, darker calm water along the bottom edge, simple dark clouds along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, raindrops, rain streaks, snowflakes, text, letters, logos, watermark, signature, frame, border, people, ships in distress, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` storm clouds over wide wheat fields and a farmhouse · `_03` storm over a mountain lake with a boathouse.

### Fog

**`fog_01.jpg`**
```
A misty pine and birch forest at dawn, tall trunks fading into thick soft fog, gentle rays of pale light coming through the trees from the upper left, a moss-covered path winding into the mist, ferns at the edges. Soft desaturated greens, greys and pale gold, very gentle contrast. Path starts at the bottom centre and disappears into the fog in the middle, calm low-detail forest floor along the bottom edge, simple misty canopy along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, raindrops, snowflakes, text, letters, logos, watermark, signature, frame, border, people, animals in the foreground, pure white areas, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a foggy lake with a wooden rowing boat · `_03` rolling hills with fog in the valleys and a farmhouse.

### Cloudy

**`cloudy_day_01.jpg`**
```
A calm lake with a long wooden pier under a soft overcast sky, gentle grey clouds with subtle texture, still water reflecting the clouds and a line of autumn-free green trees on the far shore, a small boathouse at the end of the pier. Muted cool greys, sage greens and weathered wood browns. Pier leads from the bottom left toward the centre, far shore about 35 % from the bottom, calm water along the bottom edge, simple cloudy sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, raindrops, snowflakes, text, letters, logos, watermark, signature, frame, border, people in the foreground, pure white sky, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a coastal meadow with a stone cottage · `_03` vineyard rows on gentle hills.

**`cloudy_dusk_01.jpg`**
```
Rolling countryside hills at dusk under a thick layer of soft clouds, a winding country road with a few warmly lit farmhouse windows, a line of poplar trees, the cloud underside catching muted pink and lavender light from the setting sun. Dusky blue-grey, mauve and soft rose tones with warm window accents. Road leads from the bottom right into the centre, horizon about 35 % from the bottom, calm low-detail field along the bottom edge, simple cloudy sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, raindrops, snowflakes, text, letters, logos, watermark, signature, frame, border, people in the foreground, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a windmill on the hill · `_03` a small village church with a lit doorway.

### Clear

**`clear_morning_01.jpg`**
```
Rolling green hills at sunrise with soft mist lying in the valleys, a winding country road, a few stone farmhouses and a row of cypress trees, clear sky warming from pale blue to soft peach at the horizon, the sun just below the hills. Fresh greens, soft blues and warm gold light, gentle long shadows. Road leads from the bottom centre over the hills, horizon about 35 % from the bottom, calm low-detail meadow along the bottom edge, simple clear sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, snowflakes, text, letters, logos, watermark, signature, frame, border, people in the foreground, sun disc in the top area, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a lake with a wooden dock in morning light · `_03` an orchard with blossoming trees.

**`clear_day_01.jpg`**
```
A sunny Mediterranean coastal town on a hillside, white and pastel houses with terracotta roofs, a small harbour with a few wooden boats, calm turquoise sea, olive trees and bougainvillea, clear deep-blue sky with a couple of small soft clouds. Bright but soft midday light, blues, whites, terracotta and green. Town across the centre and right, sea horizon about 40 % from the bottom, calm water along the bottom edge, simple clear sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, snowflakes, text, letters, logos, watermark, signature, frame, border, people in the foreground, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` seen from a terrace with a table and lemons in the corner · `_03` a stone lighthouse on the harbour wall.

**`clear_dusk_01.jpg`**
```
A wide lavender field at sunset, long rows of purple lavender leading to a lone old tree and a stone farmhouse on the horizon, sky glowing from soft orange at the horizon to pink and deep violet above, the sun just touching the hills. Warm purples, magentas and gold with soft violet shadows. Rows lead from the bottom into the centre, horizon about 35 % from the bottom, calm low-detail lavender rows along the bottom edge, simple gradient sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, snowflakes, text, letters, logos, watermark, signature, frame, border, people in the foreground, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` sunset over the sea from a cliff path · `_03` a wheat field with hay bales.

**`clear_night_01.jpg`**
```
A high mountain meadow under a clear starry night sky with the Milky Way arching across, a small tent glowing warm from inside, a little campfire beside it, dark silhouettes of mountains and pine trees, a calm alpine lake reflecting the stars. Deep navy and indigo tones, soft star glow, small warm orange accents. Tent slightly left of centre, horizon about 30 % from the bottom, calm dark meadow along the bottom edge, darker simple sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, snowflakes, text, letters, logos, watermark, signature, frame, border, people, bright moon in the top area, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a quiet seaside village under the stars · `_03` an observatory dome on a hilltop.

### Autumn (used on clear or cloudy days, September to November)

**`autumn_01.jpg`**
```
A quiet park path covered in fallen orange, red and yellow leaves, old oak and maple trees in full autumn colour forming a soft arch, a wooden bench and an old iron lamppost, warm low afternoon sunlight filtering through the leaves, the air calm. Warm amber, rust and gold with soft green-brown shadows. Path leads from the bottom centre into the distance, calm leaf-covered ground along the bottom edge, simple soft sky glimpsed through the canopy along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: leaves falling through the air, falling rain, snowflakes, text, letters, logos, watermark, signature, frame, border, people in the foreground, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a lake with autumn forest reflections · `_03` a country lane with a stone wall and pumpkins.

### Holidays

**`holiday_christmas_01.jpg`**
```
A cozy living room on Christmas Eve, a decorated fir tree with warm white fairy lights and red and gold ornaments, wrapped presents beneath, a crackling fireplace with stockings, a large window showing a snowy garden at night, soft armchair and knitted blanket. Warm golden interior light against cool blue night outside, reds, greens and gold. Tree slightly left of centre, window on the right, calm wooden floor and rug along the bottom edge, simple ceiling area along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic composition for a desktop wallpaper. Avoid: falling snow, snowflakes in the air, text, letters, "Merry Christmas" lettering, logos, watermark, signature, frame, border, people, Santa character, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a snowy village square with a big lit Christmas tree at dusk · `_03` a decorated cabin porch with lanterns at night.

**`holiday_newyear_01.jpg`**
```
A city skyline by a wide river at midnight on New Year's Eve, colourful fireworks blooming high over the river and reflecting in the calm water, old bridges lit with warm lamps, snow lying on the rooftops and riverbanks. Deep blue night with bursts of gold, magenta and teal light. Fireworks in the central sky (below the top strip), river and reflections across the lower third, calm dark water along the bottom edge, simple dark sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling snow, snowflakes in the air, text, numbers, year digits, letters, logos, watermark, signature, frame, border, people in the foreground, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` fireworks over a snowy mountain village · `_03` a balcony view with string lights and fireworks over the city.

**`holiday_valentines_01.jpg`**
```
A small café terrace in early spring at golden hour, cherry trees in soft pink blossom overhead, string lights with warm bulbs, a little round table with two cups and a single red rose in a vase, cobblestone street and pastel houses behind. Soft pinks, cream and warm gold with gentle green accents. Table slightly right of centre, calm cobblestones along the bottom edge, simple pastel sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic composition for a desktop wallpaper. Avoid: petals falling through the air, rain, snowflakes, text, letters, heart-shaped lettering, logos, watermark, signature, frame, border, people, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a riverside bench under blossoming trees at sunset · `_03` a balcony with roses and candles at dusk.

**`holiday_easter_01.jpg`**
```
A spring garden on a sunny morning, blooming tulips, daffodils and hyacinths in neat beds, a few softly painted pastel eggs resting in the fresh grass, a white picket fence and a blossoming apple tree, a small cottage in the background. Fresh pastel colours, soft yellow, lilac, mint and pink under a clear pale-blue sky. Garden beds across the lower middle, cottage slightly right, calm grass along the bottom edge, simple sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling petals, rain, snowflakes, text, letters, logos, watermark, signature, frame, border, people, cartoon bunnies, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a hillside chapel among blossoming orchards · `_03` a farmhouse kitchen window sill with eggs and spring flowers.

**`holiday_ramadan_01.jpg`**
```
A historic old-town street at dusk during Ramadan, rows of glowing lanterns strung between stone and wooden buildings, a mosque minaret and dome in the soft distance, a thin crescent moon low in a deep blue and amber sky, warm light spilling from open doorways and small shops. Deep blue twilight with warm amber and gold lantern glow, calm and peaceful. Street leads from the bottom centre toward the mosque, calm cobblestones along the bottom edge, simple twilight sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, snowflakes, text, Arabic or Latin lettering, calligraphy, letters, logos, watermark, signature, frame, border, people in the foreground, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a riverside view of the old town with lanterns reflected in the water · `_03` a courtyard with a fountain and hanging lanterns.

**`holiday_bajram_01.jpg`** (Ramazanski Bajram / Eid al-Fitr)
```
A festive sunny morning in a historic old-town square, a wooden public fountain with a small roof, pigeons on the cobblestones, flowers in window boxes, decorated shop fronts with small hanging lanterns, a mosque with a slender minaret behind, clear soft-blue sky. Bright, warm and joyful light, soft gold, cream, green and sky-blue. Fountain in the centre, mosque behind it, calm cobblestones along the bottom edge, simple sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, snowflakes, text, Arabic or Latin lettering, calligraphy, letters, logos, watermark, signature, frame, border, people in the foreground, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a table set with baklava, tea and dates by a sunny window overlooking the old town · `_03` the old town seen from a green hillside at morning.

**`holiday_kurbanbajram_01.jpg`** (Kurban Bajram / Eid al-Adha)
```
A peaceful green hillside village on a bright summer morning, white houses with dark wooden roofs, a small mosque with a slender minaret, orchards and grazing meadows, a winding path, soft clouds in a clear blue sky. Fresh summer greens, white, warm wood and sky-blue, gentle and festive. Village and mosque across the centre, horizon about 40 % from the bottom, calm meadow along the bottom edge, simple sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic landscape composition for a desktop wallpaper. Avoid: falling rain, snowflakes, text, Arabic or Latin lettering, calligraphy, letters, logos, watermark, signature, frame, border, people in the foreground, animals in the foreground, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a family courtyard with a long table under a vine pergola · `_03` the village at golden-hour evening.

**`holiday_halloween_01.jpg`**
```
A friendly autumn porch of an old wooden house at night, carved jack-o'-lanterns glowing warm orange on the steps, piles of fallen leaves, a straw bale with small pumpkins, a big soft orange full moon low over bare trees, cozy rather than scary. Deep purple-blue night with warm orange glow. Porch slightly left of centre, moon low on the right (below the top strip), calm leaf-covered ground along the bottom edge, simple dark sky along the top edge. Painterly digital illustration in a cozy, calm storybook style, soft brush textures, gentle gradients, subtle film grain, slightly muted natural colours, soft atmospheric depth, wide cinematic composition for a desktop wallpaper. Avoid: leaves falling through the air, rain, snowflakes, text, letters, logos, watermark, signature, frame, border, people, gore, scary monsters, oversaturated colours, HDR look, lens flare.
```
Variations: `_02` a pumpkin patch at dusk with a scarecrow · `_03` a village street with lanterns and pumpkins in windows.
