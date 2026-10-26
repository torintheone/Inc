"""Тексты этапа 6 для locale/game.csv: звук и музыка, обучение, титры, иллюстрации.
Файл подключает tools/locale_game.py.
"""

ROWS = [
    ("SOUND_ON", "Звук: вкл", "Sound: on"),
    ("SOUND_OFF", "Звук: выкл", "Sound: off"),
    ("MUSIC_ON", "Музыка: вкл", "Music: on"),
    ("MUSIC_OFF", "Музыка: выкл", "Music: off"),
    ("STAMP_DONE", "ПРИНЯТО", "DONE"),
    # --- титры ---
    ("MENU_CREDITS", "Титры", "Credits"),
    ("TUT_RESET", "Подсказки заново", "Tips again"),
    ("CREDITS_TITLE", "Титры", "Credits"),
    ("CREDITS_ABOUT", "Стратегия о рабочем движении в духе Plague Inc и Rebel Inc. Логика развития общества "
     "построена на категориях политэкономии и исторического материализма, упрощённых до игровой модели.",
     "A strategy game about the workers' movement."),
    ("CREDITS_CODE", "Код", "Code"),
    ("CREDITS_GODOT", "Движок Godot Engine 4.7 — Juan Linietsky, Ariel Manzur и участники проекта Godot (лицензия MIT).",
     "Godot Engine 4.7 (MIT)."),
    ("CREDITS_CLAUDE", "Код, данные, тексты, музыка и звуки написаны с помощью Claude Code (Anthropic).",
     "Code, data, texts, music and sounds made with Claude Code."),
    ("CREDITS_DATA", "Данные", "Data"),
    ("CREDITS_NATURAL_EARTH", "Границы стран, регионов, города и порты — Natural Earth (общественное достояние).",
     "Borders, regions, cities and ports: Natural Earth (public domain)."),
    ("CREDITS_WORLD_BANK", "Показатели стран — Всемирный банк, World Development Indicators (CC BY 4.0).",
     "Country indicators: World Bank WDI (CC BY 4.0)."),
    ("CREDITS_FONTS", "Шрифты", "Fonts"),
    ("CREDITS_PT_SANS", "PT Sans — ParaType (SIL Open Font License 1.1).", "PT Sans — ParaType (OFL 1.1)."),
    ("CREDITS_OSWALD", "Oswald — The Oswald Project Authors (SIL Open Font License 1.1).", "Oswald (OFL 1.1)."),
    ("CREDITS_SOUND", "Музыка и звуки", "Music and sound"),
    ("CREDITS_MUSIC_SONGS", "Песни из общественного достояния в своей аранжировке: «Смело, товарищи, в ногу» "
     "(Л. Радин) — меню, «Варшавянка» (старая революционная песня, слова Г. Кржижановского) — сражения, "
     "«Интернационал» (музыка П. Дегейтера) — победа.",
     "Public-domain songs in our own arrangement: \"Boldly, Comrades, in Step\" (L. Radin) — menu, "
     "\"Warszawianka\" (old revolutionary song) — battles, \"The Internationale\" (music by P. De Geyter) — victory."),
    ("CREDITS_MUSIC_OWN", "Остальные темы сочинены для игры; ноты и аранжировки — CC0.",
     "Other themes composed for the game; scores and arrangements are CC0."),
    ("CREDITS_SOUNDFONT", "Инструменты — SoundFont FluidR3_GM, Frank Wen (лицензия MIT).", "Instruments: FluidR3_GM by Frank Wen (MIT)."),
    ("CREDITS_SFX", "Звуки синтезированы скриптом из шума и тонов (CC0).", "Sounds synthesized by script (CC0)."),
    ("CREDITS_ART", "Иллюстрации", "Illustrations"),
    ("CREDITS_ART_GROK", "Иллюстрации созданы с помощью Grok (xAI).", "Illustrations created with Grok (xAI)."),
    ("CREDITS_ART_STUBS", "Иллюстрации появятся позже; пока карта, значки и эмблема нарисованы кодом.",
     "Illustrations will come later; the map, icons and emblem are drawn by code."),
    # --- обучение ---
    ("TUT_TITLE", "Подсказка", "Tip"),
    ("TUT_OK", "Понятно", "Got it"),
    ("TUT_DISABLE", "Без подсказок", "No more tips"),
    ("TUT_start", "Движение зародилось. Влияние растёт само, но медленно, а власть подавляет стихийные протесты. "
     "Время идёт неделями; скорость и пауза — справа вверху.",
     "The movement is born. Time runs in weeks; speed and pause are top right."),
    ("TUT_bubble", "Пузырёк! Красный — солидарность для «Развития», охристый — стихийный протест: "
     "коснитесь, и партия его поддержит. Не успеете — власть его подавит.",
     "A bubble! Red is solidarity, ochre is a protest. Tap it."),
    ("TUT_upgrade", "Солидарности хватает на улучшение. Откройте «Развитие»: кружки, профсоюзы, газета — "
     "движение растёт быстрее.", "Enough solidarity for an upgrade. Open Development."),
    ("TUT_action", "В стране накопились кадры. Коснитесь её и нажмите «Действия в стране» — "
     "например, стачку на предприятии.", "Cadres are ready. Tap the country and open its actions."),
    ("TUT_spread", "Движение перекинулось в другие страны — по торговле, с эмигрантами, через соседей. "
     "Следите за ними в панели «События» и «Статистика».", "The movement has spread to other countries."),
    ("TUT_window", "Охристая рамка — окно революции! Когда организованность дойдёт до 50, в «Действиях» "
     "появится «Восстание» — и сражение на карте страны.", "An ochre outline: a window of revolution."),
    ("TUT_reaction", "Реакция растёт: чем заметнее движение, тем жёстче ответ правящих классов. "
     "Подполье и конспирация смягчают удары.", "Reaction is growing. Underground work softens the blows."),
    ("TUT_society", "Революция победила! Коснитесь страны и откройте «Новое общество»: политики деревни, "
     "экономики и внешней линии решают, не переродится ли революция.", "Victory! Open New society."),
]


def rows() -> list[tuple[str, str, str]]:
    return ROWS
