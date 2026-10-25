# ART_LIST — что сгенерировать в Grok

Всего **124 картинки**. У каждой есть имя файла и готовый промпт — его нужно скопировать целиком (кнопка копирования справа от блока с текстом) и вставить в Grok.

Игра не ждёт графику: пока картинок нет, вместо них показываются заглушки. Делать их можно в любом темпе и в любом порядке, но эталон стиля (шаг 1) — первым.

## Как работать

1. Открой Grok (приложение или grok.com) и выбери создание изображения.
2. Сделай первую картинку — `bg_menu` из шага 1. Сгенерируй несколько вариантов и выбери лучший: это эталон стиля для всех остальных.
3. Для каждой следующей картинки скопируй её промпт и вставь в Grok. Если в Grok можно прикрепить картинку к запросу, прикрепляй эталон `bg_menu` и допиши в начало промпта: `Use the attached image only as a style reference, draw a new scene:`. Если Grok вместо новой сцены просто перерисовывает эталон — генерируй без прикрепления.
4. Если в Grok есть выбор пропорций, ставь ту, что указана у картинки (16:9, 1:1 или 3:4; если 3:4 нет — 2:3). Точный размер в пикселях не важен: скрипт сам обрежет и уменьшит.
5. Сохрани удачный вариант и переименуй файл в имя из списка, например `ev_lockout.png`. Расширение может быть любым — `.png`, `.jpg` или `.webp`, главное — имя до точки.
6. Загрузи картинки пачкой в репозиторий (инструкция ниже) и напиши мне «картинки загружены».

### Какой вариант брать

- Нет букв, цифр и «каракулей, похожих на текст», — ни на знамёнах, ни на стенах.
- Нет свастик, гербов, флагов настоящих стран и логотипов. Серп и молот — можно.
- Нет узнаваемых реальных людей.
- Главное — в центре кадра: края при обработке могут обрезаться.
- Цвета не обязательно идеальные: скрипт сам приведёт картинку к палитре игры и наложит бумажную фактуру.

### Как отправить мне картинки

1. Открой на телефоне или компьютере ссылку: https://github.com/torintheone/Inc/upload/ccr-debc37c8-93qeel/art/incoming (на телефоне, если не открывается, включи в браузере «версию для ПК»).
2. Перетащи туда файлы или нажми «choose your files» и выбери их — до 100 штук за раз.
3. Внизу нажми зелёную кнопку **Commit changes**.
4. Напиши мне в чат «картинки загружены» — я обработаю их и встрою в игру.

Если загрузить в репозиторий не получается, можно прислать картинки прямо в чат, но тогда в сообщении подпиши имя каждой.

В титрах игры будет строка «Иллюстрации созданы с помощью Grok» — xAI просит указывать источник.

## Сводка

| Группа | Сколько | Формат |
| --- | --- | --- |
| Шаг 1. Эталон стиля | 1 | 16:9 |
| Иллюстрации событий | 55 | 16:9 |
| Карточки улучшений и действий | 48 | 1:1 |
| Портреты классов | 8 | 3:4 |
| Эмблемы стратегических линий | 5 | 1:1 |
| Фоны концовок | 5 | 16:9 |
| Иконка и обложка | 2 | 1:1 |
| **Всего** | **124** | |

Общий стилевой блок, с которого начинается каждый промпт:

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols.
```

## Шаг 1. Эталон стиля

Сделай её первой: по ней выравниваются все остальные.

### 1. Фон главного меню (эталон стиля)

Файл: `bg_menu.png` · формат 16:9 (1920×1080)

Что на картинке: Огромная колонна рабочих с красными знамёнами идёт на зрителя, за ними трубы и краны, а в небе встаёт полупрозрачный красный призрак.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A vast crowd of workers marching toward the viewer under plain red banners, factory chimneys and cranes behind them, a huge translucent red ghostly silhouette rising in the dawn sky above them like a specter. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

## Иллюстрации событий

55 штук, 16:9.

### 2. Кризис перепроизводства

Файл: `ev_overproduction_crisis.png` · формат 16:9 (1600×900)

Что на картинке: Склады ломятся от непроданных товаров за запертыми воротами, а снаружи мёрзнет толпа безработных.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Warehouses overflowing with unsold goods behind locked iron gates, while a crowd of cold, hungry unemployed workers stands outside in the snow. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 3. Массовые увольнения

Файл: `ev_mass_layoffs.png` · формат 16:9 (1600×900)

Что на картинке: Рабочие выходят из ворот завода с ящиками инструментов, мастер запирает ворота цепью.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Hundreds of workers streaming out of factory gates carrying their tool boxes, a foreman locking the gates behind them with a heavy chain. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 4. Локаут

Файл: `ev_lockout.png` · формат 16:9 (1600×900)

Что на картинке: Заводские ворота закованы цепью, их охраняет конная полиция; по другую сторону стоят рабочие с семьями.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Massive steel factory gates chained shut and guarded by mounted police in steel blue, workers with their families standing silently on the other side. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 5. Штрейкбрехеры

Файл: `ev_strikebreakers.png` · формат 16:9 (1600×900)

Что на картинке: Пикет стачечников, взявшихся за руки, перегораживает дорогу; полиция ведёт колонну сгорбленных штрейкбрехеров.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A tense picket line of strikers with linked arms blocking a factory road, as police in steel blue escort a column of hunched strikebreakers toward them. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 6. Новые машины на фабриках

Файл: `ev_new_machines.png` · формат 16:9 (1600×900)

Что на картинке: Гигантские новые станки нависают над горсткой встревоженных рабочих; по краям — силуэты тех, кто остался без работы.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Giant new automated machines with mechanical arms towering over a few worried workers on a factory floor, silhouettes of idle laid-off workers at the edges. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 7. Цены на хлеб

Файл: `ev_bread_prices.png` · формат 16:9 (1600×900)

Что на картинке: Женщины и рабочие толпятся у закрытой булочной с пустыми корзинами; одна буханка поднята над головами, как факел.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Angry women and workers crowding around a closed bakery holding up empty baskets, one loaf of bread raised high above the crowd like a torch. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 8. Крах банков

Файл: `ev_bank_crash.png` · формат 16:9 (1600×900)

Что на картинке: Лавочники и служащие ломятся в запертые двери банка; колонны трескаются, по ветру летят бумаги.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Panicked small shopkeepers and clerks crowding the locked doors of a grand bank whose classical columns are cracking, papers flying in the wind. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 9. Долгий подъём

Файл: `ev_long_boom.png` · формат 16:9 (1600×900)

Что на картинке: Процветающий промышленный город на рассвете: дымят трубы, рабочие в новой одежде, краны строят новые дома.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A busy prosperous industrial city at sunrise, smoking chimneys, workers in new clothes walking past bright shop windows, cranes building new towers. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 10. Катастрофа на шахте

Файл: `ev_mine_disaster.png` · формат 16:9 (1600×900)

Что на картинке: Шахтёры выносят носилки из дымящегося ствола шахты; у копра ждут женщины и дети, горят лампы.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Miners carrying a stretcher out of a smoking mine shaft at dusk, women and children waiting by the headframe, miners' lamps glowing. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 11. Неурожай

Файл: `ev_crop_failure.png` · формат 16:9 (1600×900)

Что на картинке: Потрескавшееся поле с засохшей пшеницей под палящим небом, исхудавшая крестьянская семья у пустой телеги.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Cracked dry fields of withered wheat under a burning sky, a gaunt peasant family standing beside an empty cart. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 12. Перенос производства

Файл: `ev_offshoring.png` · формат 16:9 (1600×900)

Что на картинке: Огромный кран поднимает целый завод с фундамента и несёт его за море; рабочие остаются на пустыре.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A huge crane lifting an entire factory off its foundations and carrying it across the sea toward a distant shore, workers left standing on an empty lot. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 13. Рабочие-мигранты

Файл: `ev_migrant_workers.png` · формат 16:9 (1600×900)

Что на картинке: Рабочие с чемоданами выходят на перрон, местные рабочие в спецовках встречают их; лица самых разных народов.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Migrant workers with suitcases arriving on a busy railway platform, local workers in overalls meeting them, faces of many different origins. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 14. Работа через платформы

Файл: `ev_platform_work.png` · формат 16:9 (1600×900)

Что на картинке: Курьеры на велосипедах и самокатах с коробами за спиной мчатся по ночному городу под дождём, в руках светятся телефоны.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Delivery couriers on bicycles and scooters with large cube backpacks racing through a rainy city at night, phone screens glowing in their hands. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 15. Запрет профсоюзов

Файл: `ev_union_ban.png` · формат 16:9 (1600×900)

Что на картинке: Полиция заколачивает двери профсоюзного дома; рабочие молча смотрят с другой стороны улицы.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Police in steel blue boarding up the doors of a workers' union hall, union members watching in silence from across the street. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 16. Расстрел демонстрации

Файл: `ev_demonstration_shot.png` · формат 16:9 (1600×900)

Что на картинке: Шеренга солдат поднимает винтовки на мирную толпу; на брусчатке брошенные знамёна, в воздухе дым. Без крови.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A line of soldiers in steel blue raising rifles toward a peaceful crowd on a city square, dropped banners and a lost cap on the cobblestones, smoke in the air, no blood. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 17. Арест лидеров

Файл: `ev_leaders_arrested.png` · формат 16:9 (1600×900)

Что на картинке: Ночной арест: агенты в длинных плащах выводят рабочего вожака к чёрной машине, соседи смотрят из окон.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A night raid: plainclothes agents in long coats leading a handcuffed workers' leader out of an apartment block to a black car, neighbors watching from the windows. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 18. Провокатор в организации

Файл: `ev_provocateur.png` · формат 16:9 (1600×900)

Что на картинке: Тайное собрание при одной лампе; один из участников в тени передаёт записку человеку за окном.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A secret meeting of workers around a table under a single lamp, one man in the shadows passing a folded note to a figure outside the window. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 19. Подкуп профсоюзных вождей

Файл: `ev_union_bribery.png` · формат 16:9 (1600×900)

Что на картинке: Сытый профсоюзный чиновник жмёт руку фабриканту в цилиндре, под столом переходит пухлый конверт. Эта же картинка — для события «Подкуп депутатов».

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A well-fed union official in a suit shaking hands with an industrialist in a top hat, a fat envelope passing between them under the table, silhouettes of workers in the background. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 20. Реформы сверху

Файл: `ev_reforms_from_above.png` · формат 16:9 (1600×900)

Что на картинке: Огромная рука из облаков протягивает маленький кусок хлеба многотысячной толпе, которая не опускает кулаков.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A giant hand descending from the clouds offering a small piece of bread to a vast crowd of workers who keep their fists raised. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 21. Чрезвычайное положение

Файл: `ev_state_of_emergency.png` · формат 16:9 (1600×900)

Что на картинке: Бронемашины и солдаты патрулируют пустую ночную улицу в комендантский час, прожекторы скользят по закрытым ставням.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Armored vehicles and soldiers in steel blue patrolling an empty street at night during curfew, searchlights sweeping across closed shutters. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 22. Закрытие газеты

Файл: `ev_newspaper_closed.png` · формат 16:9 (1600×900)

Что на картинке: Полиция громит печатный станок в тесной типографии, летят чистые листы, молодой печатник прячет пачку под пальто.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Police smashing a printing press in a cramped print shop, blank sheets of newsprint flying, a young printer hiding a stack of papers under his coat. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 23. Фашистская угроза, шаг 1: «Отряды на улицах»

Файл: `ev_fascist_squads.png` · формат 16:9 (1600×900)

Что на картинке: Колонны одинаковых громил в тёмных рубашках с дубинками и факелами идут по ночной улице, прохожие жмутся к стенам. Никаких реальных эмблем.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Marching columns of thugs in identical dark shirts with clubs and torches on a night street, frightened passers-by pressed against the walls, no insignia. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 24. Фашистская угроза, шаг 2: «Кризис власти»

Файл: `ev_power_crisis.png` · формат 16:9 (1600×900)

Что на картинке: Здание парламента с треснувшими колоннами; с одной стороны рабочие в красном, с другой — отряды в тёмных рубашках, над ними грозовые тучи.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A parliament building with cracked columns split down the middle, workers in red on one side and dark-shirted squads on the other, storm clouds above, no insignia. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 25. Фашистская угроза, шаг 3: фашистский режим

Файл: `ev_fascist_regime.png` · формат 16:9 (1600×900)

Что на картинке: Колоссальная безликая стальная статуя диктатора давит город; колючая проволока, прожекторы, крошечные фигурки узников.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A colossal faceless steel-blue statue of a dictator crushing a city underfoot, barbed wire and searchlights, tiny figures of prisoners below, no insignia. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 26. Военный переворот

Файл: `ev_military_coup.png` · формат 16:9 (1600×900)

Что на картинке: Танки въезжают по ступеням правительственного дворца на рассвете, генерал с биноклем на башне, на площади собирается толпа.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Tanks rolling up the steps of a government palace at dawn, a general with binoculars standing on a turret, a crowd gathering in the square. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 27. «Разделяй и властвуй»

Файл: `ev_divide_and_rule.png` · формат 16:9 (1600×900)

Что на картинке: Кукловод в цилиндре дёргает за нитки две группы рабочих, которые дерутся друг с другом, а завод за ними работает на него.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A puppet master in a top hat pulling the strings of two groups of workers fighting each other, while the factory behind them keeps working for him. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 28. Медийная кампания

Файл: `ev_media_campaign.png` · формат 16:9 (1600×900)

Что на картинке: Гигантские громкоговорители и светящиеся экраны над городом изливают туман пропаганды на загипнотизированных прохожих.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Giant loudspeakers and glowing screens on tall poles towering over a city, pouring a fog of propaganda over hypnotized commuters. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 29. Коррупционный скандал

Файл: `ev_corruption_scandal.png` · формат 16:9 (1600×900)

Что на картинке: Чиновники в костюмах мечутся, из распахнутого сейфа на мраморный пол сыплются деньги и золото, вспыхивают фотовспышки.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Officials in suits scrambling as a burst safe spills banknotes and gold across a marble floor, photographers' flashbulbs popping. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 30. Империалистическая война

Файл: `ev_imperialist_war.png` · формат 16:9 (1600×900)

Что на картинке: Две армии безликих солдат в окопах друг против друга; над ними фабриканты в цилиндрах двигают фигурки солдат по огромной карте.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Two armies of faceless soldiers in trenches facing each other across a ruined no-man's land, above them industrialists in top hats moving toy soldiers on a giant map. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 31. Освободительное восстание

Файл: `ev_liberation_uprising.png` · формат 16:9 (1600×900)

Что на картинке: Батраки с плантаций и жители деревень поднимаются с мачете и винтовками против колониальной крепости, пальмы, восходящее солнце.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Plantation workers and villagers rising up with machetes and rifles against a colonial-style fortress, palm trees, a rising sun. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 32. Интервенция

Файл: `ev_intervention.png` · формат 16:9 (1600×900)

Что на картинке: Чужие стальные военные корабли в гавани, к порту идут шлюпки с десантом, докеры на пирсе поднимают кулаки.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Foreign steel-blue warships looming in a harbor, landing boats full of troops approaching a port city, dockers on the pier raising their fists. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 33. Блокада и санкции

Файл: `ev_blockade.png` · формат 16:9 (1600×900)

Что на картинке: Кольцо серых кораблей и цепь через море вокруг маленькой красной страны-острова; одинокий грузовой корабль проскальзывает в просвет.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A ring of grey warships and a giant chain stretched across the sea around a small red island country, a lone cargo ship slipping through a gap. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 34. Конгресс солидарности

Файл: `ev_solidarity_congress.png` · формат 16:9 (1600×900)

Что на картинке: Большой зал, полный делегатов разных народов, голосующих поднятыми руками, с балконов свисают красные полотнища.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A large hall full of delegates of many nations voting with raised hands, plain red banners hanging from the balconies. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 35. Торговая война держав

Файл: `ev_trade_war.png` · формат 16:9 (1600×900)

Что на картинке: Два великана в цилиндрах перетягивают глобус цепями из контейнеров, рабочие обеих сторон попадают под ноги.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Two giant figures in top hats playing tug-of-war over a globe with chains of cargo containers, workers of both sides trampled beneath them. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 36. Долговая ловушка

Файл: `ev_debt_trap.png` · формат 16:9 (1600×900)

Что на картинке: Маленькая страна в образе рабочего прикована к огромному чугунному шару из монет; безликий банкир держит цепь с небоскрёба.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A small country drawn as a worker chained to a giant iron ball made of coins, a faceless banker holding the chain from the top of a skyscraper. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 37. Беженцы от террора

Файл: `ev_refugees.png` · формат 16:9 (1600×900)

Что на картинке: Длинная колонна беженцев с узлами переходит заснеженный горный перевал ночью, впереди рабочий с фонарём.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A long column of refugees with bundles crossing a snowy mountain border at night, led by a worker holding a lantern. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 38. Пример соседей

Файл: `ev_neighbors_example.png` · формат 16:9 (1600×900)

Что на картинке: Через пограничную реку люди смотрят на красный рассвет над соседним городом, где ликуют толпы; свет падает на их лица.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Across a border river, people watch a red sunrise over a neighboring city where crowds are celebrating, the light falling on their faces. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 39. Реформа или революция

Файл: `ev_reform_or_revolution.png` · формат 16:9 (1600×900)

Что на картинке: Толпа рабочих на развилке: одна дорога ведёт к спокойному серому парламенту, другая — крутой красной тропой к восходящему солнцу.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A crowd of workers at a fork in the road: one path leads to a calm grey parliament building, the other is a steep red mountain path toward a rising sun. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 40. Раскол партии

Файл: `ev_party_split.png` · формат 16:9 (1600×900)

Что на картинке: Длинный стол собрания треснул пополам, делегаты по обе стороны стоят и спорят, летят бумаги. Эта же картинка — для «Раскола из-за смены курса».

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A long meeting table cracked in half down the middle, delegates on both sides standing up and arguing, papers flying. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 41. Стихийное восстание

Файл: `ev_spontaneous_uprising.png` · формат 16:9 (1600×900)

Что на картинке: Беспорядочная толпа заполнила ночные улицы, перевёрнутые трамваи, костры, никаких вожаков, пламя отражается в окнах.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A chaotic crowd flooding the streets at night, overturned trams and bonfires, no leaders in sight, flames reflecting in the windows. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 42. Харизматичный лидер

Файл: `ev_charismatic_leader.png` · формат 16:9 (1600×900)

Что на картинке: Вымышленный оратор на ящике выступает перед огромной толпой; его гигантская тень ложится на стену завода.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A fictional orator with an anonymous stylized face standing on a crate addressing a huge crowd, his giant shadow cast across the factory wall behind him. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 43. Выгорание активистов

Файл: `ev_activist_burnout.png` · формат 16:9 (1600×900)

Что на картинке: Измученная молодая активистка уснула за столом среди пачек листовок и остывшего чая, на рассвете ещё горит лампа.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. An exhausted young activist asleep at a table among stacks of leaflets and cold tea at dawn, a dim lamp still burning. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 44. Работницы требуют равной оплаты

Файл: `ev_equal_pay.png` · формат 16:9 (1600×900)

Что на картинке: Текстильщицы в косынках и спецовках выходят из цеха под руку и поднимают кулаки, за ними видны ткацкие станки.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Women textile workers in headscarves and overalls marching out of a mill arm in arm with raised fists, looms visible behind them. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 45. Студенческие волнения

Файл: `ev_student_unrest.png` · формат 16:9 (1600×900)

Что на картинке: Студенты и молодые преподаватели заняли ступени университета с колоннами, сидят с книгами и полотнищами, внизу цепь полиции.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Students and young lecturers occupying the columned steps of a university, sitting with books and plain banners, a police line below. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 46. Ультралевая авантюра

Файл: `ev_ultraleft_adventure.png` · формат 16:9 (1600×900)

Что на картинке: Несколько молодых людей в масках с пистолетами в тёмном подвале; пожилой рабочий в дверях качает головой.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A small group of masked young men with pistols in a dim basement, an older worker standing in the doorway shaking his head in disapproval. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 47. Уроки поражения

Файл: `ev_lessons_of_defeat.png` · формат 16:9 (1600×900)

Что на картинке: Уцелевшие после разгромленного восстания сидят у костра среди руин; старый рабочий чертит в золе карту для молодых.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Survivors of a defeated uprising gathered around a fire in a ruined district, an old worker drawing a map in the ashes for young comrades. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 48. Саботаж специалистов

Файл: `ev_specialist_sabotage.png` · формат 16:9 (1600×900)

Что на картинке: Инженеры в костюмах ночью тайком сыплют песок в станок в пустом цеху, рабочий наблюдает из тени.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Engineers in suits secretly pouring sand into a machine at night in an empty factory, a worker watching them from the shadows. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 49. Голод в городах

Файл: `ev_city_famine.png` · формат 16:9 (1600×900)

Что на картинке: Длинная очередь исхудавших горожан в пальто с пустыми мисками у почти пустого пункта раздачи еды, зима.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A long winter queue of thin city dwellers in coats holding empty bowls at an almost empty food distribution point. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 50. Угроза бюрократизации

Файл: `ev_bureaucracy_threat.png` · формат 16:9 (1600×900)

Что на картинке: Бесконечный лабиринт серых столов и бумажных башен, крошечные клерки ставят печати, рабочий с прошением заблудился в коридорах.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. An endless maze of grey office desks and towering stacks of paper, tiny clerks stamping documents, a worker with a petition lost in the corridors. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 51. Роль профсоюзов

Файл: `ev_union_role.png` · формат 16:9 (1600×900)

Что на картинке: Профсоюзное собрание в цеху голосует поднятыми руками, на сцене за длинным столом сидят представители новой власти.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A trade union assembly in a factory hall voting with raised hands, officials of the new government seated at a long table on the stage facing them. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 52. Земля и кооперация

Файл: `ev_land_cooperation.png` · формат 16:9 (1600×900)

Что на картинке: Крестьяне собрались вокруг нового трактора на краю деревни: одни радуются, другие скрестили руки с сомнением.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Peasants gathering around a new tractor at the edge of a village, some cheering, others skeptical with arms crossed, wide fields behind them. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 53. Помощь другой революции

Файл: `ev_aid_revolution.png` · формат 16:9 (1600×900)

Что на картинке: Эшелоны с мешками зерна и ящиками уходят со станции к далёкому горящему горизонту, толпа провожает добровольцев.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Trains loaded with grain sacks and crates departing a station toward a distant burning horizon, crowds seeing off volunteers. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 54. Ошибка плана

Файл: `ev_plan_error.png` · формат 16:9 (1600×900)

Что на картинке: Гора одинаковых ненужных сапог на складе, а снаружи стоит очередь босых людей.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A mountain of identical unused boots piling up in a warehouse while a queue of barefoot people waits outside. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 55. Отъезд специалистов

Файл: `ev_specialists_leave.png` · формат 16:9 (1600×900)

Что на картинке: Инженеры и врачи с чемоданами поднимаются на корабль в сером порту и оглядываются на город, рабочие смотрят с пирса.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Engineers and doctors with suitcases boarding a ship in a grey port, looking back at the city, workers watching from the pier. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 56. Новая культура

Файл: `ev_new_culture.png` · формат 16:9 (1600×900)

Что на картинке: Рабочие всех возрастов учатся читать в светлом классе при заводе, рядом на сцене репетирует театр.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Workers of all ages learning to read in a bright factory classroom, a theater troupe rehearsing on a stage nearby, abstract geometric decorations. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

## Карточки улучшений и действий

45 штук, 1:1.

### 57. Рабочие кружки (развитие)

Файл: `card_study_circles.png` · формат 1:1 (512×512)

Что на картинке: Несколько рабочих читают вместе при одной лампе в тесной комнате.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A small group of workers reading together around a single lamp in a tiny room. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 58. Профсоюзы (развитие)

Файл: `card_trade_unions.png` · формат 1:1 (512×512)

Что на картинке: Множество рабочих рук, сцепленных в крепкое кольцо.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Many workers' hands clasped together in a firm grip, forming a ring. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 59. Отраслевые федерации (развитие)

Файл: `card_industry_federations.png` · формат 1:1 (512×512)

Что на картинке: Ряд разных предприятий — шахта, сталелитейный, ткацкая фабрика — связаны одной красной лентой.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A row of different industries, a coal mine, a steelworks and a textile mill, joined together by one bold red band. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 60. Рабочая партия (развитие)

Файл: `card_workers_party.png` · формат 1:1 (512×512)

Что на картинке: Оратор на трибуне перед рядами делегатов, за ним красное полотнище.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A speaker at a podium in front of rows of seated delegates, a plain red banner behind him. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 61. Рабочие советы (развитие; также «Совет депутатов» в сражении)

Файл: `card_workers_councils.png` · формат 1:1 (512×512)

Что на картинке: Собрание рабочих в цеху голосует поднятыми руками.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. An assembly of workers in a factory hall voting with raised hands. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 62. Подполье (развитие)

Файл: `card_underground.png` · формат 1:1 (512×512)

Что на картинке: Люк в полу подвала ведёт в тайную комнату с ручным печатным станком при свете лампы.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A hidden trapdoor in a cellar floor opening into a lamp-lit secret room with a small hand printing press. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 63. Листовки (развитие; также «Агитация в районе» в сражении)

Файл: `card_leaflets.png` · формат 1:1 (512×512)

Что на картинке: Вихрь чистых листовок летит над крышами рабочего квартала.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A whirlwind of blank leaflets flying over the rooftops of a working-class district. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 64. Рабочая газета (развитие)

Файл: `card_workers_newspaper.png` · формат 1:1 (512×512)

Что на картинке: Ручной печатный станок выпускает красные листы.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A hand-cranked printing press rolling out bright red sheets of paper. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 65. Школа кадров (развитие)

Файл: `card_cadre_school.png` · формат 1:1 (512×512)

Что на картинке: Молодой рабочий у доски с геометрическими схемами учит других рабочих.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A young worker at a blackboard covered with geometric diagrams, no writing, teaching a small group of workers. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 66. Клубы и культура (развитие)

Файл: `card_clubs_culture.png` · формат 1:1 (512×512)

Что на картинке: Рабочий хор и гармонист на маленькой сцене клуба.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A workers' choir and an accordion player on a small stage in a workers' club. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 67. Цифровые медиа (развитие)

Файл: `card_digital_media.png` · формат 1:1 (512×512)

Что на картинке: Смартфон испускает красные волны, которые расходятся к множеству других телефонов.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A smartphone emitting red radio waves that spread to many other phones around it. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 68. Союз с крестьянством (развитие; также «Земля — крестьянам» в сражении)

Файл: `card_peasant_alliance.png` · формат 1:1 (512×512)

Что на картинке: Заводской рабочий и крестьянка пожимают руки над пшеничным полем.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A factory worker and a peasant woman shaking hands above a field of wheat. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 69. Стачечный фонд (развитие)

Файл: `card_strike_fund.png` · формат 1:1 (512×512)

Что на картинке: Жестяная копилка, полная монет, переходит из рук в руки.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A tin collection box overflowing with coins being passed from hand to hand. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 70. Тактика захвата предприятий (развитие)

Файл: `card_occupation_tactic.png` · формат 1:1 (512×512)

Что на картинке: Рабочие сидят на остановленном станке в занятом цеху, скрестив руки.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Workers sitting on top of a silent machine inside an occupied factory, arms crossed. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 71. Всеобщая стачка (развитие)

Файл: `card_general_strike_prep.png` · формат 1:1 (512×512)

Что на картинке: Огромный заводской гудок на крыше вот-вот загудит, рабочие внизу ждут сигнала.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A giant factory steam whistle on a rooftop about to blow, workers below waiting for the signal. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 72. Единый фронт (развитие)

Файл: `card_united_front.png` · формат 1:1 (512×512)

Что на картинке: Две разные колонны рабочих сливаются в одну, обнимая друг друга за плечи.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Two different crowds of workers merging into one column, arms around each other's shoulders. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 73. Рабочая самооборона (развитие)

Файл: `card_self_defense.png` · формат 1:1 (512×512)

Что на картинке: Цепь рабочих в кепках с нарукавными повязками, взявшись за руки, защищает шествие.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A line of workers in caps with red armbands linking arms to protect a march behind them. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 74. Связи эмигрантов (развитие)

Файл: `card_emigrant_links.png` · формат 1:1 (512×512)

Что на картинке: Пароход с машущими рабочими, красная нить тянется от него к далёкому берегу.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A steamship with waving workers on deck, a red thread connecting it to a distant shore. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 75. Интернационал (развитие)

Файл: `card_international.png` · формат 1:1 (512×512)

Что на картинке: Земной шар в кольце сцепленных рук разных людей.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A globe encircled by a ring of linked hands of people of many origins. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 76. Солидарные стачки (развитие)

Файл: `card_solidarity_strikes.png` · формат 1:1 (512×512)

Что на картинке: Докеры в двух портах по разные стороны моря одновременно бросают работу, их соединяет красная линия.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Dockers in two ports on opposite sides of the sea laying down their tools at the same moment, linked by a red line. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 77. Поддержка освободительных движений (развитие)

Файл: `card_liberation_support.png` · формат 1:1 (512×512)

Что на картинке: Рука рабочего помогает крестьянину подняться на крутой утёс к восходящему солнцу.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A worker's hand helping a villager climb a steep cliff toward a rising sun. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 78. Антивоенная сеть (развитие)

Файл: `card_antiwar_network.png` · формат 1:1 (512×512)

Что на картинке: Солдат ломает винтовку о колено.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A soldier breaking his rifle over his knee. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 79. Конспирация (развитие)

Файл: `card_conspiracy.png` · формат 1:1 (512×512)

Что на картинке: Человек в кепке прижимает палец к губам, половина лица в тени.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A figure in a worker's cap holding a finger to his lips, half of his face in deep shadow. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 80. Юридическая служба (развитие)

Файл: `card_legal_service.png` · формат 1:1 (512×512)

Что на картинке: Рука рабочего держит весы правосудия.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A worker's hand holding up the scales of justice. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 81. Контрразведка (развитие)

Файл: `card_counterintelligence.png` · формат 1:1 (512×512)

Что на картинке: Лупа высвечивает спрятанное подслушивающее устройство под столом собрания.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A magnifying glass revealing a hidden listening device under a meeting table. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 82. Стачка на предприятии (действие; также «Стачка в районе» в сражении)

Файл: `card_strike_factory.png` · формат 1:1 (512×512)

Что на картинке: Рабочие уходят от затихшего завода, скрестив руки; трубы не дымят.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Workers walking away from a silent factory with folded arms, its chimneys without smoke. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 83. Отраслевая стачка (действие)

Файл: `card_industry_strike.png` · формат 1:1 (512×512)

Что на картинке: Длинный ряд заводских труб гаснет одна за другой.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A long row of factory chimneys going cold one after another. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 84. Всеобщая стачка (действие)

Файл: `card_general_strike.png` · формат 1:1 (512×512)

Что на картинке: Весь город замер: стоят трамваи, молчат заводы, над крышами — огромная красная фигура со скрещёнными руками.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. An entire city frozen still, trams stopped, factories silent, a giant red figure with folded arms standing over the skyline. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 85. Демонстрация (действие)

Файл: `card_demonstration.png` · формат 1:1 (512×512)

Что на картинке: Колонна с красными знамёнами идёт по диагонали карточки.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A marching crowd with plain red banners moving diagonally across the image. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 86. Кампания за сокращение рабочего дня (действие)

Файл: `card_shorter_workday.png` · формат 1:1 (512×512)

Что на картинке: Рабочие толкают назад стрелки огромных часов без цифр.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Workers pushing back the hands of a giant clock face without numbers. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 87. Захват предприятия (действие)

Файл: `card_factory_seizure.png` · формат 1:1 (512×512)

Что на картинке: Рабочие поднимают красный флаг над заводскими воротами.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Workers raising a plain red flag over a factory gate. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 88. Участие в выборах (действие)

Файл: `card_elections.png` · формат 1:1 (512×512)

Что на картинке: Рука рабочего опускает чистый бюллетень в урну.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A worker's hand dropping a blank ballot into a ballot box. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 89. Кооперативы и кассы взаимопомощи (действие)

Файл: `card_cooperatives.png` · формат 1:1 (512×512)

Что на картинке: Рабочие семьи делят хлеб за длинным общим столом.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Working families sharing bread at one long common table. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 90. Агитация среди безработных (действие)

Файл: `card_unemployed_agitation.png` · формат 1:1 (512×512)

Что на картинке: Агитатор говорит с очередью безработных у бесплатной столовой.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. An agitator talking to a queue of unemployed men outside a soup kitchen. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 91. Работа в армии (действие; также «Агитация в гарнизоне» в сражении)

Файл: `card_army_work.png` · формат 1:1 (512×512)

Что на картинке: Рабочий что-то шепчет молодому часовому, тот опустил винтовку.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A worker whispering to a young soldier on guard duty, the soldier lowering his rifle. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 92. Ячейки в портах и на транспорте (действие)

Файл: `card_port_cells.png` · формат 1:1 (512×512)

Что на картинке: Докеры на пирсе с кранами и паровозом, красный фонарь подаёт тайный сигнал.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Dockers on a pier with cranes and a steam locomotive, a hidden red lantern giving a secret signal. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 93. Антифашистская самооборона (действие)

Файл: `card_antifascist_defense.png` · формат 1:1 (512×512)

Что на картинке: Поднятый кулак ломает тёмную дубинку.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A raised fist breaking a dark truncheon in half. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 94. Уход в подполье (действие)

Файл: `card_go_underground.png` · формат 1:1 (512×512)

Что на картинке: Фигуры растворяются в тёмных ночных переулках, за ними гаснут окна.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Figures disappearing into dark night alleys one by one, windows going dark behind them. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 95. Восстание (действие)

Файл: `card_uprising.png` · формат 1:1 (512×512)

Что на картинке: Вооружённые рабочие перелезают через баррикаду и идут на дворец под красной зарёй.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Armed workers climbing over a barricade and charging toward a palace under a red dawn. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 96. Баррикады (сражение)

Файл: `card_barricades.png` · формат 1:1 (512×512)

Что на картинке: Баррикада из булыжников, бочек и перевёрнутой телеги поперёк узкой улицы, на ней красный флаг.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A barricade of cobblestones, barrels and an overturned cart across a narrow street, a plain red flag on top. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 97. Захват узла связи (сражение)

Файл: `card_seize_comms.png` · формат 1:1 (512×512)

Что на картинке: Рабочие занимают радиобашню, от вершины расходятся красные волны.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Workers occupying a radio tower, red radio waves spreading from its top. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 98. Захват железнодорожного узла (сражение)

Файл: `card_seize_railway.png` · формат 1:1 (512×512)

Что на картинке: Рабочие переводят стрелку на путях перед идущим паровозом.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Workers throwing a railway switch on the tracks in front of an approaching steam locomotive. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 99. Захват арсенала (сражение)

Файл: `card_seize_arsenal.png` · формат 1:1 (512×512)

Что на картинке: Распахнутые ворота арсенала, рабочие выносят ящики с винтовками.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. The open gates of an arsenal, workers carrying out crates of rifles. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 100. Захват порта (сражение)

Файл: `card_seize_port.png` · формат 1:1 (512×512)

Что на картинке: Докеры поднимают красный флаг на портовом кране, внизу корабли.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Dockers raising a plain red flag on top of a harbor crane, ships below. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 101. Переговоры с офицерами (сражение)

Файл: `card_officer_talks.png` · формат 1:1 (512×512)

Что на картинке: Рабочий и офицер стоят друг против друга за столом при свече, между ними карта.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A worker and an army officer facing each other across a table by candlelight, a map between them. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

## Портреты классов

8 штук, 3:4. Вымышленные типажи, не реальные люди.

### 102. Промышленный пролетариат

Файл: `class_industrial_proletariat.png` · формат 3:4 (768×1024)

Что на картинке: Сталевар в спецовке и кепке с закатанными рукавами и большим гаечным ключом, сзади зарево печи.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A steelworker in overalls and a cap with rolled-up sleeves holding a large wrench, the glow of a furnace behind him. Vertical 3:4 portrait, half-length figure of a fictional character, simple background.
```

### 103. Сельский пролетариат, батраки

Файл: `class_rural_proletariat.png` · формат 3:4 (768×1024)

Что на картинке: Обожжённый солнцем батрак в соломенной шляпе с мотыгой, позади поля плантации.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A sun-scorched farmhand in a straw hat holding a hoe, plantation fields behind him. Vertical 3:4 portrait, half-length figure of a fictional character, simple background.
```

### 104. Крестьянство

Файл: `class_peasantry.png` · формат 3:4 (768×1024)

Что на картинке: Пожилой крестьянин с мешком зерна на плече, позади плуг и деревня.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. An older peasant man with a sack of grain on his shoulder, a horse-drawn plough and a village behind him. Vertical 3:4 portrait, half-length figure of a fictional character, simple background.
```

### 105. Служащие и интеллигенция

Файл: `class_intelligentsia.png` · формат 3:4 (768×1024)

Что на картинке: Молодая учительница или служащая в очках со стопкой книг и бумаг, за ней окна городской конторы.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A young woman teacher or office clerk in glasses holding a stack of books and papers, city office windows behind her. Vertical 3:4 portrait, half-length figure of a fictional character, simple background.
```

### 106. Мелкая буржуазия

Файл: `class_petty_bourgeoisie.png` · формат 3:4 (768×1024)

Что на картинке: Лавочник в фартуке тревожно пересчитывает монеты в дверях своей маленькой лавки.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A shopkeeper in an apron anxiously counting coins in the doorway of his small shop. Vertical 3:4 portrait, half-length figure of a fictional character, simple background.
```

### 107. Крупная буржуазия

Файл: `class_big_bourgeoisie.png` · формат 3:4 (768×1024)

Что на картинке: Тучный фабрикант в цилиндре и фраке с сигарой и золотой цепочкой часов, позади заводы и небоскрёбы, стальные тона.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A portly industrialist in a top hat and tailcoat with a cigar and a gold watch chain, factories and skyscrapers behind him, in steel blue tones. Vertical 3:4 portrait, half-length figure of a fictional character, simple background.
```

### 108. Землевладельцы

Файл: `class_landowners.png` · формат 3:4 (768×1024)

Что на картинке: Помещик в сапогах для верховой езды и широкополой шляпе со стеком, позади усадьба и бескрайние поля.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A landowner in riding boots and a wide-brimmed hat holding a riding crop, a manor house and vast estates behind him. Vertical 3:4 portrait, half-length figure of a fictional character, simple background.
```

### 109. Люмпен-пролетариат

Файл: `class_lumpenproletariat.png` · формат 3:4 (768×1024)

Что на картинке: Оборванец в рваном пальто в тёмном переулке под фонарём, взгляд неопределённый.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A ragged man in a torn coat leaning against a wall in a dark alley under a street lamp, with an ambiguous gaze. Vertical 3:4 portrait, half-length figure of a fictional character, simple background.
```

## Эмблемы стратегических линий

5 штук, 1:1.

### 110. Авангардная партия

Файл: `line_vanguard.png` · формат 1:1 (512×512)

Что на картинке: Плотная колонна марширующих фигур в форме красного наконечника стрелы пробивает тёмную стену вверх.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A tight column of marching figures shaped like a red arrowhead, piercing upward through a dark wall. Square 1:1 round emblem, symmetrical, one central symbol, flat colors on cream paper.
```

### 111. Рабочие советы

Файл: `line_councils.png` · формат 1:1 (512×512)

Что на картинке: Кольцо из множества поднятых рук вокруг шестерни.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A ring of many raised voting hands around a factory gear. Square 1:1 round emblem, symmetrical, one central symbol, flat colors on cream paper.
```

### 112. Революционный синдикализм

Файл: `line_syndicalism.png` · формат 1:1 (512×512)

Что на картинке: Кулак сжимает тяжёлый гаечный ключ на фоне большой шестерни.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A fist gripping a heavy wrench in front of a large gear. Square 1:1 round emblem, symmetrical, one central symbol, flat colors on cream paper.
```

### 113. Массовая партия

Файл: `line_mass_party.png` · формат 1:1 (512×512)

Что на картинке: Факел высоко над морем голов.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A torch held high above a dense sea of heads. Square 1:1 round emblem, symmetrical, one central symbol, flat colors on cream paper.
```

### 114. Народная война

Файл: `line_peoples_war.png` · формат 1:1 (512×512)

Что на картинке: Винтовка и колос пшеницы крест-накрест на фоне гор и восходящего солнца.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A rifle and an ear of wheat crossed over mountains and a rising sun. Square 1:1 round emblem, symmetrical, one central symbol, flat colors on cream paper.
```

## Фоны концовок

5 штук, 16:9. Фон меню уже сделан на шаге 1.

### 115. Концовка «Мировая федерация»

Файл: `bg_end_federation.png` · формат 16:9 (1920×1080)

Что на картинке: Земной шар из космоса в сети светящихся красных линий, люди всех континентов взялись за руки вокруг него, яркий рассвет.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. The globe seen from space wrapped in a network of glowing red lines, people of all continents joined hand in hand around it, a bright dawn. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 116. Концовка «Мировая революция»

Файл: `bg_end_world_revolution.png` · формат 16:9 (1920×1080)

Что на картинке: Толпы празднуют одновременно на площадях нескольких больших городов — небоскрёбы, купола, гавани, — всюду красные знамёна и салют.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Crowds celebrating at once on the squares of several great cities with skyscrapers, domes and harbors, plain red banners rising everywhere, fireworks. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 117. Концовка «Мир двух систем»

Файл: `bg_end_two_systems.png` · формат 16:9 (1920×1080)

Что на картинке: Мир разделён пополам: красная половина с заводами и толпами, стальная — с небоскрёбами и военными кораблями, между ними стена.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A world split down the middle: one half red with factories and crowds, the other half steel blue with skyscrapers and warships, a tense wall between them. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 118. Концовка «Термидор»

Файл: `bg_end_thermidor.png` · формат 16:9 (1920×1080)

Что на картинке: Когда-то красная площадь посерела: пустая огромная трибуна, одинокий чиновник в длинном пальто идёт мимо выцветших знамён, холодный ветер. Эта же картинка — для события «Термидор».

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A once-red monumental square turned grey, a huge empty podium, a lone bureaucrat in a long coat walking past faded banners in a cold wind. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

### 119. Концовка «Белый террор»

Файл: `bg_end_white_terror.png` · формат 16:9 (1920×1080)

Что на картинке: Тёмный город под стальными прожекторами, колючая проволока, разорванное красное знамя в снегу, сквозь трещину пробивается маленький красный цветок. Эта же картинка — для события «Контрреволюция».

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A dark city under steel-blue searchlights, barbed wire, a torn red banner lying in the snow, a single small red flower growing through a crack. Wide 16:9 composition, key subject in the center, nothing important near the edges.
```

## Иконка и обложка

2 штуки, 1:1.

### 120. Иконка приложения

Файл: `app_icon.png` · формат 1:1 (1024×1024)

Что на картинке: Красный силуэт призрака с поднятым кулаком над чёрными силуэтами заводов, кремовый фон.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A bold red ghostly specter silhouette with a raised fist rising over a black factory skyline, cream background, no border. Square 1:1 app icon, one bold silhouette, very simple shapes, readable at 48 pixels.
```

### 121. Обложка

Файл: `app_cover.png` · формат 1:1 (1024×1024)

Что на картинке: Гигантский красный призрак поднимается из заводского дыма над старинной картой мира, внизу крошечные толпы рабочих поднимают кулаки.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A giant red specter rising from factory chimney smoke over an old-style world map, tiny crowds of workers below raising their fists, dramatic diagonal composition. Square 1:1 composition, dramatic and readable at a glance.
```

## Дополнение к версии 0.2

3 карточки, 1:1. Новые улучшения и действие, которых не было в первом списке.

### 122. Помощь политзаключённым (развитие)

Файл: `card_prisoner_aid.png` · формат 1:1 (512×512)

Что на картинке: Женщина передаёт свёрток с хлебом через решётку тюремного окна, рядом — дети.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A woman passing a bundle of bread through the bars of a prison window, children beside her. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 123. Явочные квартиры (развитие)

Файл: `card_safe_houses.png` · формат 1:1 (512×512)

Что на картинке: Тёмная лестница старого дома, приоткрытая дверь, полоска тёплого света и силуэт в шляпе.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. A dark staircase in an old tenement, a door ajar with a strip of warm light, a silhouette in a hat slipping inside. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```

### 124. Прислать организаторов (действие)

Файл: `card_send_organizers.png` · формат 1:1 (512×512)

Что на картинке: Двое рабочих с чемоданами сходят с поезда на перроне, их встречает толпа с поднятыми руками.

```
Original propaganda poster illustration in 1920s constructivist style, bold flat shapes, limited palette of vermilion red, black and cream paper with small accents of ochre and steel blue, strong diagonal composition, halftone and paper grain texture, anonymous stylized faces, no real people, no text, no letters, no numbers, no logos, plain banners and flags without symbols. Two workers with suitcases stepping off a train onto a platform, greeted by a crowd raising their hands. Square 1:1 composition, one bold central subject on a simple background, readable at small size.
```
