-- Предметы. Минимальный набор для Этапа 7; расширяется в дальнейших этапах.
-- type: "passive" | "active" | "glitch" | "consumable"
return {
    -- ====== Пассивные мутагены ======
    {
        id = "myelin_layer", name = "Миелиновый Слой",
        type = "passive", rarity = "common",
        description = "Скорость +15%.",
        stat_modifiers = { speed_mult = 1.15 },
        color = {0.4, 0.8, 1.0},
    },
    {
        id = "ribosome_shield", name = "Рибосомный Щит",
        type = "passive", rarity = "rare",
        description = "Блокирует 1 удар каждые 5 секунд.",
        stat_modifiers = { shield_cooldown = 5.0 },
        color = {0.8, 0.9, 0.3},
    },
    {
        id = "viral_vector", name = "Вирусный Вектор",
        type = "passive", rarity = "rare",
        description = "Враги иногда взрываются при смерти.",
        stat_modifiers = { explode_chance = 0.2, explode_damage = 5 },
        color = {0.3, 1.0, 0.4},
    },
    {
        id = "axon_accel", name = "Аксонный Ускоритель",
        type = "passive", rarity = "common",
        description = "Скорострельность +30%, нагрев +10%.",
        stat_modifiers = { fire_rate_mult = 1.3, heat_mult = 1.1 },
        color = {1.0, 0.4, 0.3},
    },
    {
        id = "glycine", name = "Глициновый Рецептор",
        type = "passive", rarity = "rare",
        description = "Шанс крита +15% (×2 урон).",
        stat_modifiers = { crit_chance = 0.15, crit_mult = 2 },
        color = {1.0, 0.9, 0.2},
    },
    {
        id = "mito_drain", name = "Митохондриальный Дрейн",
        type = "passive", rarity = "epic",
        description = "+1 HP за убийство элитного врага.",
        stat_modifiers = { elite_heal = 1 },
        color = {0.4, 0.2, 0.6},
    },

    -- ====== Активные протоколы (оружие/способности) ======
    {
        id = "axon", name = "Аксон",
        type = "active", rarity = "common",
        description = "Скорострельный протокол: низкий урон, низкий нагрев.",
        stat_modifiers = { damage = 4, heat_per_shot = 6, fire_rate = 5 },
        color = {0.6, 0.9, 1.0},
        is_protocol = true,
    },
    {
        id = "dendrite", name = "Дендрит",
        type = "active", rarity = "common",
        description = "3 выстрела разбросом, средний нагрев.",
        stat_modifiers = { damage = 3, heat_per_shot = 14, fire_rate = 2.5, spread_shots = 3 },
        color = {1.0, 0.7, 0.3},
        is_protocol = true,
    },
    {
        id = "acid_burst", name = "Кислотный Всплеск",
        type = "active", rarity = "rare",
        description = "AOE конус, высокий урон/нагрев.",
        stat_modifiers = { damage = 8, heat_per_shot = 25, fire_rate = 1.5, aoe = 30 },
        color = {0.4, 1.0, 0.3},
        is_protocol = true,
    },

    -- ====== Когнитивные сбои (рискованные апгрейды) ======
    {
        id = "vampiric", name = "Вампирический Импульс",
        type = "glitch", rarity = "epic",
        description = "Выстрелы лечат 1 HP. Каждые 8 сек экран чернеет на 0.4 сек.",
        stat_modifiers = { lifesteal = 1, blackout_interval = 8 },
        color = {1.0, 0.2, 0.4},
    },
    {
        id = "quantum_rift", name = "Квантовый Разлом",
        type = "glitch", rarity = "epic",
        description = "+50% урона. Каждые 15 сек случайный телепорт в комнате.",
        stat_modifiers = { damage_mult = 1.5, teleport_interval = 15 },
        color = {0.6, 0.3, 1.0},
    },
    {
        id = "biomass", name = "Биомасса",
        type = "glitch", rarity = "rare",
        description = "+3 узла синапса, скорость -25%.",
        stat_modifiers = { synapses = 3, speed_mult = 0.75 },
        color = {0.5, 0.7, 0.3},
    },

    -- ====== Расходники ======
    {
        id = "glial_cell", name = "Глиальная Клетка",
        type = "consumable", rarity = "common",
        description = "Соберите 3 для нового узла синапса (+2 макс HP).",
        stat_modifiers = { glial_progress = 1 },
        color = {0.4, 1.0, 0.6},
    },
    {
        id = "dna_fragment", name = "Фрагмент ДНК",
        type = "consumable", rarity = "rare",
        description = "5 фрагментов одного врага открывают меню Интеграции.",
        stat_modifiers = { dna_progress = 1 },
        color = {0.6, 0.4, 1.0},
    },
    {
        id = "memory_fragment", name = "Фрагмент Памяти",
        type = "consumable", rarity = "epic",
        description = "Открывает запись в Кодексе.",
        stat_modifiers = { codex_unlock = 1 },
        color = {1.0, 0.85, 0.4},
    },
}
