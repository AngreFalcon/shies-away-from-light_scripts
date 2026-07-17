--[[
  Allows for manipulation of the data loaded from content files while the game is first started.
  Records can be created and deleted using this package as if a content file had done so.
  local content = require('openmw.content')
]]

local type openmw_core = require("openmw.core")
local type openmw_types = require("openmw.types")
local record content
  interface GlobalContent
    --[[
      A mutable list of all global mwscript variables.
      content.globals.records.MyVariable = 42
    ]]
    records: { string: number }
    
  end
  interface LightContent
    --[[
      A mutable list of all @{openmw.types#LightRecord}s.
      content.lights.records.MyLight = { template = content.lights.records['torch'], duration = -1, name = 'Infinite Torch' }
    ]]
    records: { openmw_types.LightRecord }
    
  end
  interface IngredientContent
    --[[
      A mutable list of all @{openmw.types#IngredientRecord}s.
      Note that ingredient effects only have the `id`, `affectedAttribute`, and `affectedSkill` properties.
      content.ingredients.records.MyIngredient = { template = content.ingredients.records['ingred_ectoplasm_01'], name = 'Soylent', effects = { { id = 'vampirism' } } }
    ]]
    records: { openmw_types.IngredientRecord }
    
  end
  interface PotionContent
    --[[
      A mutable list of all @{openmw.types#PotionRecord}s.
      content.potions.records.MyPotion = { template = content.potions.records['p_dispel_s'], name = 'Too Strong', effects = { { id = 'FireDamage', duration = 10, range = content.RANGE.Self, magnitudeMin = 100 } } }
    ]]
    records: { openmw_types.PotionRecord }
    
  end
  interface MagicEffectContent
    --[[
      A mutable list of all @{openmw.core#MagicEffect}s.
      content.magicEffects.records.MyMagicEffect = { template = content.magicEffects.records['summonscamp'], name = 'Summon Nothing' }
    ]]
    records: { openmw_core.MagicEffect }
    
  end
  interface MiscContent
    --[[
      A mutable list of all @{openmw.types#MiscellaneousRecord}s.
      content.miscs.records.MyMisc = { template = content.miscs.records['gold_001'], mwscript = 'BILL_MarksSpiritSummon', weight = 5 }
    ]]
    records: { openmw_types.MiscellaneousRecord }
    
  end
  interface ProbeContent
    --[[
      A mutable list of all @{openmw.types#ProbeRecord}s.
      content.probes.records.MyProbe = { template = content.probes.records['probe_bent'], quality = 5, name = 'Alien Probe' }
    ]]
    records: { openmw_types.ProbeRecord }
    
  end
  interface GMSTContent
    --[[
      Returns a table containing all fallback values defined in `openmw.cfg`.
    ]]
    getFallbacks: function(): table
    
    --[[
      A mutable list of all game settings.
      content.gameSettings.records.fJumpAcrobaticsBase = 1024
    ]]
    records: { string: any }
    
  end
  interface DoorContent
    --[[
      A mutable list of all @{openmw.types#DoorRecord}s.
      content.doors.records.MyDoor = { template = content.doors.records['door_dwrv_double00'], mwscript = 'blockedDoor', name = 'Overly Heavy Dwemer Door' }
    ]]
    records: { openmw_types.DoorRecord }
    
  end
  interface ActivatorContent
    --[[
      A mutable list of all @{openmw.types#ActivatorRecord}s.
      content.activators.records.MyActivator = { mwscript = 'float', model = 'meshes/w/w_chitin_arrow.nif', name = 'Quest marker' }
    ]]
    records: { openmw_types.ActivatorRecord }
    
  end
  interface BookContent
    --[[
      A mutable list of all @{openmw.types#BookRecord}s.
      content.books.records.MyBook = { template = content.books.records['bk_lustyargonianmaid'], text = content.books.records['bk_BoethiahPillowBook'].text }
    ]]
    records: { openmw_types.BookRecord }
    
  end
  interface EnchantmentContent
    --[[
      @{openmw.core#EnchantmentType}: Enchantment types
    ]]
    TYPE: openmw_core.EnchantmentType
    
    --[[
      A mutable list of all @{openmw.core#Enchantment}s.
      content.enchantments.records.MyEnchantment = { type = content.enchantments.TYPE.CastOnUse, charge = 1, cost = 1, effects = { { id = 'FortifySkill', affectedSkill = 'enchant', duration = 5, magnitudeMin = 50, magnitudeMax = 100 } } }
    ]]
    records: { openmw_core.Enchantment }
    
  end
  interface StaticContent
    --[[
      A mutable list of all @{openmw.types#StaticRecord}s.
      content.statics.records.MyStatic = { model = 'meshes/b/B_N_Wood Elf_M_Head_02.nif' }
    ]]
    records: { openmw_types.StaticRecord }
    
  end
  interface SpellContent
    --[[
      @{openmw.core#SpellType}: Spell types
    ]]
    TYPE: openmw_core.SpellType
    
    --[[
      A mutable list of all @{openmw.core#Spell}s.
      content.spells.records.MySpell = { name = 'Enchantment?', type = content.spells.TYPE.Spell, cost = 1000, starterSpellFlag = true, isAutocalc = true, effects = { { id = 'FortifyAttribute', affectedAttribute = 'intelligence', duration = 5, magnitudeMin = 5, magnitudeMax = 10 } } }
    ]]
    records: { openmw_core.Spell }
    
  end
  interface SoundContent
    --[[
      A mutable list of all @{openmw.core#SoundRecord}s.
      content.sounds.records.MySound = { template = content.sounds.records['MournDayAmb'], fileName = 'sound/fx/funny.wav' }
    ]]
    records: { openmw_core.SoundRecord }
    
  end
  --[[
    @{openmw.core#SpellRange}: Magic ranges
  ]]
  RANGE: openmw_core.SpellRange
  
  --[[
    @{#ActivatorContent}: Activator manipulation.
  ]]
  activators: content.ActivatorContent
  
  --[[
    @{#BookContent}: Book manipulation.
  ]]
  books: content.BookContent
  
  --[[
    @{#DoorContent}: Door manipulation.
  ]]
  doors: content.DoorContent
  
  --[[
    @{#EnchantmentContent}: Enchantment manipulation.
  ]]
  enchantments: content.EnchantmentContent
  
  --[[
    @{#GMSTContent}: GMST manipulation.
  ]]
  gameSettings: content.GMSTContent
  
  --[[
    @{#GlobalContent}: Global variable manipulation.
  ]]
  globals: content.GlobalContent
  
  --[[
    @{#IngredientContent}: Ingredient manipulation.
  ]]
  ingredients: content.IngredientContent
  
  --[[
    @{#LightContent}: Light manipulation.
  ]]
  lights: content.LightContent
  
  --[[
    @{#MagicEffectContent}: Magic effect manipulation.
  ]]
  magicEffects: content.MagicEffectContent
  
  --[[
    @{#MiscContent}: Misc manipulation.
  ]]
  miscs: content.MiscContent
  
  --[[
    @{#PotionContent}: Potion manipulation.
  ]]
  potions: content.PotionContent
  
  --[[
    @{#ProbeContent}: Probe manipulation.
  ]]
  probes: content.ProbeContent
  
  --[[
    @{#SoundContent}: Sound manipulation.
  ]]
  sounds: content.SoundContent
  
  --[[
    @{#SpellContent}: Spell manipulation.
  ]]
  spells: content.SpellContent
  
  --[[
    @{#StaticContent}: Static manipulation.
  ]]
  statics: content.StaticContent
  
end
return content