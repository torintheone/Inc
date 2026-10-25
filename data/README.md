# Данные игры

Все данные лежат в JSON-файлах этой папки: игра читает их при запуске, интернет ей не нужен.

| Файл | Что внутри | Кто создаёт |
| --- | --- | --- |
| `world.json` | Страны: названия, показатели, зона мир-системы, соседи | `tools/build_world.py` |
| `world_shapes.json` | Полигоны стран для карты | `tools/build_world.py` |

Файлы `world*.json` руками не правят: их перезаписывает скрипт. Чтобы пересобрать их, запусти
в GitHub вкладку **Actions → «Данные мира» → Run workflow**. Тот же скрипт можно запустить
на компьютере: `pip install -r tools/requirements.txt`, затем `python3 tools/build_world.py`.

## world.json

```json
{
  "version": 1,
  "sources": {"borders": "...", "indicators": "...", "indicators_fetched": "2026-10-25"},
  "map": {"projection": "robinson", "width": 4000, "bounds": [minX, minY, maxX, maxY]},
  "zones": {"core": "ядро", "semi": "полупериферия", "periphery": "периферия"},
  "countries": [ { ...страна... } ]
}
```

Страна:

| Поле | Тип | Смысл |
| --- | --- | --- |
| `id` | строка | Код Natural Earth (`ADM0_A3`), обычно совпадает с ISO 3166 alpha-3: `FRA`, `RUS` |
| `wb_code` | строка или `null` | Код страны у Всемирного банка; `null` — у банка такой страны нет |
| `name_ru`, `name_en` | строка | Название |
| `continent`, `subregion`, `subregion_ru` | строка | Часть света и субрегион по классификации ООН |
| `zone` | `core` / `semi` / `periphery` | Зона мир-системы: ядро, полупериферия, периферия |
| `label` | `[x, y]` | Точка для подписи на карте, в координатах карты |
| `neighbors` | массив `id` | Страны с общей сухопутной границей |
| `indicators` | объект | Показатели, см. ниже |
| `years` | объект | Год, к которому относится каждый показатель |
| `estimated` | массив | Показатели, которых нет у Всемирного банка: они заменены медианой стран той же группы дохода |

Показатели (`indicators`):

| Ключ | Код Всемирного банка | Единицы |
| --- | --- | --- |
| `population` | SP.POP.TOTL | человек |
| `gdp_usd` | NY.GDP.MKTP.CD | доллары США |
| `gdp_per_capita` | NY.GDP.PCAP.CD | доллары США на человека |
| `industry_va` | NV.IND.TOTL.ZS | промышленность, % ВВП |
| `emp_agriculture` | SL.AGR.EMPL.ZS | % занятых |
| `emp_industry` | SL.IND.EMPL.ZS | % занятых |
| `emp_services` | SL.SRV.EMPL.ZS | % занятых |
| `wage_workers` | SL.EMP.WORK.ZS | наёмные работники, % занятых |
| `self_employed` | SL.EMP.SELF.ZS | самозанятые, % занятых |
| `unemployment` | SL.UEM.TOTL.ZS | % рабочей силы |
| `gini` | SI.POV.GINI | коэффициент Джини, 0–100 |
| `trade` | NE.TRD.GNFS.ZS | экспорт + импорт, % ВВП |
| `manuf_exports` | TX.VAL.MANF.ZS.UN | промышленные товары, % товарного экспорта |
| `fuel_exports` | TX.VAL.FUEL.ZS.UN | топливо, % товарного экспорта |
| `internet` | IT.NET.USER.ZS | % населения |
| `urban` | SP.URB.TOTL.IN.ZS | % населения |
| `migrant_stock` | SM.POP.TOTL.ZS | мигранты, % населения |
| `women_labor` | SL.TLF.TOTL.FE.ZS | женщины, % рабочей силы |
| `external_debt` | DT.DOD.DECT.GN.ZS | внешний долг, % ВНД (у богатых стран — 0) |

## world_shapes.json

```json
{
  "version": 1,
  "bounds": [minX, minY, maxX, maxY],
  "countries": {"FRA": [ {полигон}, ... ]},
  "neutral": [ {"id": "GRL", "name_ru": "Гренландия", "name_en": "Greenland", "polygons": [ ... ]} ]
}
```

Полигон — `{"rings": [[x0, y0, x1, y1, ...], [дыра], ...], "tris": [i0, i1, i2, ...]}`.
Первое кольцо — внешний контур, остальные — дыры (например, Лесото внутри ЮАР). `tris` — индексы
вершин треугольников заливки по всем кольцам подряд.

Координаты — проекция Робинсона, ширина карты 4000 единиц, ось Y направлена вниз.
`neutral` — территории с населением меньше 200 тысяч: на карте они серые, выбрать их нельзя.

## Источники

- Границы и названия: [Natural Earth](https://www.naturalearthdata.com/) 1:50m Admin 0 Countries v5.1.2, общественное достояние.
- Показатели: [Всемирный банк, World Development Indicators](https://data.worldbank.org/), лицензия CC BY 4.0.
