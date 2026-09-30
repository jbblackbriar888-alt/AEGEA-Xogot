# Лицензии ассетов нативного переноса

Ниже сохранены авторство, лицензии и история ассетов из AEGEA 5.6. Упоминания браузера, Three.js, Web Audio и прошлых функций описывают исходную сборку, а не гарантируют наличие этих реализаций в Godot. Фактический состав нативной версии указан в `README.md` и `docs/PARITY.md`. В этой поставке модели лежат в `assets/models/`, данные согласования — в `data/`, исходные инструменты подготовки и тестовые fixtures в поставку для телефона не включены. Движок Godot установлен отдельно в Xogot; Three.js в игре не запускается.

## Точный состав этой поставки

В этой поставке 72 GLB, 28 превью построек JPG, 16 PBR-карт JPG, одно HDR-небо, 26 MP3, 32 собственных SVG-значка AEGEA и шрифт DejaVu Sans. Точное соответствие каждого файла автору и лицензии: `licenses/CURRENT-ASSET-MAP.csv`. Исторические разделы ниже могут упоминать прежние файлы, отсутствующие в этой поставке; это не список её содержимого.

Превью построек в `assets/buildings/` — производные изображения моделей архитектуры, CC BY-SA 3.0. Сохраняйте указанные авторство, ссылки на лицензии и сведения об изменениях. Лицензии сторонних ассетов не задают лицензию всего игрового кода. Новая общая лицензия на код AEGEA здесь не назначается.

Для Quaternius сохранена исходная лицензия Standard-пакета CC0 (`licenses/hero-52.txt`) и сведения о его источнике (`licenses/quaternius-source-evidence.json`). Использованные версии обозначены CC0 на страницах конкретных наборов. Общее лицензионное соглашение для иных или более новых выпусков не переопределяет уже полученную CC0-лицензию. Анимации Quaternius созданы при участии Gonzalo Furnier. Шрифт содержит также глифы Arev; их исходное уведомление добавлено в `assets/FONT-LICENSE.txt`.

# Архитектурные модели AEGEA 5.6

28 согласованных моделей в `architecture-55.gltf` и `architecture-55-buffer-00.bin`–`architecture-55-buffer-06.bin`. Исходный GLB разделён на glTF и бинарные блоки без изменения геометрии, уровней детализации, материалов или текстур. Основные модели **Wildfire Games / 0 A.D.**, CC BY-SA 3.0; закреплённая ревизия 61a3b9507d974084e6badb88a0826bd89a6d5b8b. https://github.com/0ad/0ad/tree/61a3b9507d974084e6badb88a0826bd89a6d5b8b/binaries/data/mods/public/art

R2: B07 (очаг) и B15 (колодец) — новая геометрия AEGEA, CC BY-SA 3.0. B11, B13 и B16 — композиции моделей 0 A.D. с новым входом в шахту, оборудованием кожевни и печью AEGEA. B17 и B21 — модели 0 A.D. Текстуры камня, досок и кирпича — Poly Haven CC0, использованные из ранее лицензированного набора (rock_boulder_dry, wood_planks_grey, castle_brick_02_red). Одноцветные вспомогательные материалы созданы AEGEA.

Конвертация, масштабирование, исправление нормалей и UV, отдельные створки ворот, мобильные текстуры и превью меню — адаптация AEGEA. Лицензия производной геометрии: https://creativecommons.org/licenses/by-sa/3.0/ . Уведомление: `licenses/0ad-art.txt`. Исходная геометрия дополнений находится в `tools/asset-pipeline/architecture-custom`; согласованные композиции и хэши — `architecture-approved.json`, `architecture-sources.json`.

B08 — первая греческая палатка Wildfire Games. B26 — авторская геометрия AEGEA, CC BY-SA 3.0. Новые карты Poly Haven: [beige_wall_001](https://polyhaven.com/a/beige_wall_001) и [clay_plaster](https://polyhaven.com/a/clay_plaster), CC0: цвет, normal OpenGL и roughness. Ссылки и SHA-256 включены в `architecture-sources.json`.

Оптимизация LOD: meshoptimizer 1.1.1, Arseny Kapoulkine, MIT. Используется только при подготовке ассетов; код и уведомление в `tools/asset-pipeline/vendor`. Лицензия производных моделей CC BY-SA 3.0 сохранена. Legacy specular-карты преобразованы в художественное приближение roughness.

# История: новые архитектурные модели AEGEA 5.5

19 согласованных моделей: **Wildfire Games / 0 A.D.**, CC BY-SA 3.0, включая адаптированные GLB и изображения в меню. Закреплённый источник: https://github.com/0ad/0ad/tree/61a3b9507d974084e6badb88a0826bd89a6d5b8b/binaries/data/mods/public/art . Лицензия: https://creativecommons.org/licenses/by-sa/3.0/ . Исходное уведомление: `licenses/0ad-art.txt`.

Проведены сборка вложенных акторов, конвертация COLLADA, масштабирование, исправление UV, нормалей и вырожденных граней, запекание нейтрального цвета команды, выделение движущихся створок ворот, настройка материалов и облегчение мобильных текстур. Снимки моделей сделаны для меню; это производные изображения под CC BY-SA 3.0. Геометрия дороги адаптирована к рельефу.

Точный перечень и согласование: `tools/asset-pipeline/architecture-approved.json`. SHA256 оригинальных файлов: `tools/asset-pipeline/architecture-sources.json`. Конвертер: `tools/asset-pipeline/build-architecture-55.py`. Исходные модели доступны по закреплённой ссылке и не требуют платного аккаунта. В выпуске 5.5 использовались 19 одобренных вариантов. Окончательный перечень 5.6 приведён выше; заменённые варианты не загружаются игрой.

# AEGEA 5.3 — авторы и лицензии ассетов

Все указанные модели и текстуры входят в архив. Игра загружает их со своего сайта, без внешних CDN.

## Персонажи и анимации — Quaternius

Автор **Quaternius**, лицензия [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
Использованы бесплатные **Standard** версии авторских наборов:

- [Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html) — головы, глаза и волосы.
- [Modular Character Outfits — Fantasy](https://quaternius.com/packs/modularcharacteroutfitsfantasy.html) — мужская/женская одежда Ranger и Peasant, совместимый скелет.
- [Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html) и [Universal Animation Library 2](https://quaternius.com/packs/universalanimationlibrary2.html).

Файлы: `ranger.glb`, `guard.glb`, `worker.glb`, `woman.glb`. Изменения: сборка головы и одежды на одном скелете, исправление двух имён карт нормалей, цвет волос и формы охраны, выбор 23 авторских действий; производные действия mine, pullCart и bow. Всего 26 клипов на модель. Текстуры PBR уменьшены до 1K для браузерной загрузки. Это стилизованные модели с человеческими пропорциями, не фотосканированные люди. Персонажи System G6 из 4.0 заменены.

## Животные и взрослые сосны — Wildfire Games

Исходник: художественные материалы [0 A.D.](https://github.com/0ad/0ad/tree/master/binaries/data/mods/public/art).
Автор: **Wildfire Games**, <http://www.wildfiregames.com/>.
Лицензия: [Creative Commons Attribution-ShareAlike 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/).

Файлы: `assets/models/deer.glb`, `bear.glb`, `wolf.glb`, `boar.glb`, `goat.glb`, `pine-mature.glb`, `pine-mature-b.glb`.

**Эти семь преобразованных моделей, включая встроенные текстуры и анимации, распространяются под CC BY-SA 3.0.** При их дальнейшем распространении сохраняйте атрибуцию Wildfire Games, ссылку на лицензию и указание изменений; изменения этих ассетов также публикуйте под этой лицензией.

Модификации для AEGEA: конвертация COLLADA в GLB, перенос матричных анимаций в анимацию скелета, пересчёт bind-матриц и весов, нормализация нормалей, выбор основной UV-развёртки, сжатие изображений, преобразование DDS сосен в PNG. Оригинальное лицензионное уведомление: `licenses/0ad-art.txt`.

Эта атрибуция не означает, что Wildfire Games поддерживает или одобряет AEGEA. Лицензия ассетов не объявляется лицензией всего игрового кода.

## Окружение и материалы — Poly Haven

**Powered by Poly Haven** — <https://polyhaven.com/>.
Лицензия ассетов: [CC0](https://polyhaven.com/license).

| Ассет | Исходник | Файлы в игре |
|---|---|---|
| Молодая сосна | [pine_sapling_small](https://polyhaven.com/a/pine_sapling_small) | `pine.glb`, `pine-lod.glb` |
| Шесть камней | [rock_moss_set_01](https://polyhaven.com/a/rock_moss_set_01) | `rocks.glb` |
| Скальная поверхность | [rock_face_01](https://polyhaven.com/a/rock_face_01) | `cliff.glb` |
| Травянистая земля | [aerial_grass_rock](https://polyhaven.com/a/aerial_grass_rock) | `pbr/grass-*` |
| Лесная почва | [brown_mud_leaves_01](https://polyhaven.com/a/brown_mud_leaves_01) | `pbr/soil-*` |
| Песчаный берег | [coast_sand_04](https://polyhaven.com/a/coast_sand_04) | `pbr/sand-*` |
| Каменная земля | [rock_boulder_dry](https://polyhaven.com/a/rock_boulder_dry) | `pbr/rock-*` |
| Доски | [wood_planks_grey](https://polyhaven.com/a/wood_planks_grey) | `pbr/wood_planks_grey-*` |
| Кладка | [castle_brick_02_red](https://polyhaven.com/a/castle_brick_02_red) | `pbr/castle_brick_02_red-*` |
| Черепица | [roof_tiles_14](https://polyhaven.com/a/roof_tiles_14) | `pbr/roof_tiles_14-*` |
| HDR-небо | [kloppenheim_06_puresky](https://polyhaven.com/a/kloppenheim_06_puresky) | `pbr/sky.hdr` |

Модификации: уменьшение числа полигонов, отдельная упрощённая сосна для дальнего плана, упаковка текстур в GLB, ограничение изображений до 1K, сжатие JPEG. Ландшафт четырёх островов и размещение объектов созданы процедурно для AEGEA; готовая карта островов не скачивалась.

## Движок

Three.js r169 и подключённые модули — MIT. Авторское уведомление и лицензия: `vendor/THREE-LICENSE.txt`. Исходник: <https://github.com/mrdoob/three.js/tree/r169>.

Резервная текстура травы и нормали воды взяты из примеров Three.js: <https://threejs.org/examples/textures/terrain/grasslight-big.jpg> и <https://threejs.org/examples/textures/waternormals.jpg>.

Точный список файлов, размеры и контрольные суммы содержатся в `assets/manifest.json`. Инструменты конвертации включены в `tools/asset-pipeline`; они не требуются для запуска игры.

## Морская техника, тележка и три лука — Wildfire Games

Файлы: `boat-rowboat.glb`, `ship-sloop.glb`, `ship-merchant.glb`, `cart.glb`, `ballista.glb`, `bow-short.glb`, `bow-long.glb`, `bow-composite.glb` в `assets/models`.

Оригиналы: [0 A.D. art](https://github.com/0ad/0ad/tree/master/binaries/data/mods/public/art), **Wildfire Games**, <http://www.wildfiregames.com/>. Точные исходные файлы, URL и SHA-256: `tools/asset-pipeline/voyage-sources.json`.

**Все восемь преобразованных моделей и встроенные текстуры распространяются под [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/).** Изменения: конвертация COLLADA в GLB, согласование единиц измерения, сборка корпуса и паруса, запекание исходной позы, удаление ненужной арматуры, PBR-материалы, преобразование DDS и сжатие текстур до 1K. Для шлюпа использован кельтский парусник, для торгового судна — Kyrenia. Баллиста основана на римском скорпионе, масштабированном под корабельную установку. Тележка адаптирована из двухколёсной повозки; животное в упряжке не используется.

## Галеон — Daniel Quevedo

[Pirate Ship](https://opengameart.org/content/pirate-ship-0), **Daniel Quevedo**, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Файл: `assets/models/ship-warship.glb`. Исходник GalleonOGA.blend. Изменения: исправление нормалей, разделение материалов дерева/парусины/металла, фаски, упаковка в GLB. Материал дерева — wood_planks_grey от Poly Haven, CC0. Вооружение и экипаж добавляются игрой отдельно.

## Пушка — JamesWhite

[Ship Cannon](https://opengameart.org/content/ship-cannon), **JamesWhite**, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Файл `assets/models/cannon.glb`. Сохранена авторская UV-текстура, добавлены параметры металла, конвертация GLB и сжатие изображения. Исходный архив: 002_ship_cannon_0.zip.

## Звук и музыка

Точный источник каждого MP3: `assets/audio/sources.json`.

- **Wildfire Games**, <http://www.wildfiregames.com/>, [0 A.D. audio](https://github.com/0ad/0ad/tree/master/binaries/data/mods/public/audio), **[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/)**: wind, water, ship, sink, chop, chop2, stone, stone2, bow, arrow, boar, build, music. Музыка — Mediterranean Waves. Изменения: обрезка до игровых фрагментов, нормализация громкости, преобразование в MP3; музыка сокращена до 150 секунд с плавным началом и окончанием. Эти преобразованные аудиофайлы также распространяются под CC BY-SA 3.0. Оригинальное уведомление: `licenses/0ad-audio.txt`.
- **Kenney**, [RPG Audio](https://kenney.nl/assets/rpg-audio), **CC0 1.0**: три шага, взмах, металлический удар, ткань, подбор добычи, инвентарь и скрип. Конвертация OGG → MP3. Оригинальное уведомление: `licenses/kenney-rpg-audio.txt`.
- **NaturesTemper**, [Wolf Howl](https://freesound.org/people/NaturesTemper/sounds/398430/), CC0: стилизованный голосовой вой волка.
- **celldroid**, [Bear](https://freesound.org/people/celldroid/sounds/763026/), CC0.
- **ferventtorpor**, [Deer](https://freesound.org/people/ferventtorpor/sounds/696774/), CC0.
- **leosalom**, [Goat](https://freesound.org/people/leosalom/sounds/234286/), CC0.

Для четырёх звуков Freesound использованы публичные MP3-превью, нормализованные и при необходимости обрезанные. Это игровые звуковые эффекты, не заявленные как высококачественные полевые записи. Пушечный бас, шум выстрела, всплески и часть ударов синтезируются Web Audio. Исходный игровой код, иконки интерфейса и частицы созданы для AEGEA; графика, код и звук Lineage не используются.

## Дракон и монстры

| Файл | Автор и оригинал | Лицензия | Изменения |
|---|---|---|---|
| `dragon.glb` | Guillaume «GuieA_7» Englert, [Dragon 3D](https://opengameart.org/content/dragon-3d) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | Перенос материалов Blender, выбор и переименование 6 действий, упаковка текстуры/скелета в GLB |
| `troll.glb` | piacenti, [Troll Mauler](https://opengameart.org/content/troll-mauler) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | Выбрана средняя модель с ригом, восстановлены текстуры, уменьшены до 2K, ткань окрашена; 5 действий, включая производные позы |
| `golem.glb` | piacenti, [Earth Elemental Golem](https://opengameart.org/content/earth-elemental-golem) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | Конвертация FBX через ufbx, UV, нормали, 4 веса на вершину, выделены 7 клипов по авторской временной шкале |
| `warwolf.glb` | ThetankOmeter; анимации TripleSnail, [WarWolf](https://opengameart.org/content/warwolf) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Восстановлены материалы, выбран скелет и 7 действий, конвертация GLB |

Изменённая модель дракона и её текстуры распространяются под **CC BY-SA 4.0**. Указанные лицензии относятся к соответствующим ассетам; авторы не заявляются сторонниками проекта.

## Дельфины и рыба — Quaternius

[Animated Fish Pack](https://quaternius.com/packs/animatedfish.html), зеркало автора: [OpenGameArt](https://opengameart.org/content/animated-fish). Автор **Quaternius**, **CC0 1.0**. Файлы `dolphin.glb`, `fish.glb`, `fish-silver.glb`, `fish-reef.glb`. Сохранены скелет и плавание; гладкое затенение, параметры материала и конвертация GLB. Это небольшие стилизованные модели для морского окружения.

## 20 трав и 20 растений — Wildfire Games

Файлы `grass-01.glb` … `grass-20.glb`, `plant-01.glb` … `plant-20.glb`. Оригинальные меши и текстуры [0 A.D. art](https://github.com/0ad/0ad/tree/master/binaries/data/mods/public/art), автор **Wildfire Games**, <http://www.wildfiregames.com/>, **[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/)**. Все эти преобразованные модели и встроенные изображения также распространяются под CC BY-SA 3.0.

Точное соответствие actor / mesh / texture: `tools/asset-pipeline/flora-sources.json`. Изменения: конвертация COLLADA и DDS, нормализация единиц, материалы с alpha mask, сжатие изображений до 1K; старый fern COLLADA прочитан с восстановлением полигонов и UV. Ветер, размещение и LOD выполняются игрой. У тележки выделены колёса и сохранены центры вращения; геометрия и текстура остаются под CC BY-SA 3.0.

Новые голоса монстров составлены из уже лицензированных звуков bear/wolf с изменённой высотой тона; огненное дыхание, всплески и выстрелы дополнены синтезом Web Audio. Отдельные реалистичные записи драконов не заявляются.

## Мобильные варианты 5.0.1

`assets/mobile/models` содержит 73 облегчённых варианта тех же ассетов с неизменной геометрией и анимациями. Текстуры уменьшены до 256 px, у персонажа игрока и галеона — до 512 px; сжатие JPEG/PNG. Авторство и лицензия каждого варианта совпадают с исходным файлом из `assets/models`, в том числе CC BY-SA 3.0/4.0 для соответствующих производных ассетов. PBR-карты Poly Haven уменьшены до 256 px. Мобильные MP3 сохраняют авторов и лицензии исходных аудиофайлов: преобразованы в моно 22,05 кГц, музыка обрезана до 45 секунд с затуханием.

## Дополнения 5.1

Восемь процедурных небольших растений, каменные секции дорог, фундамент, дополнительная экипировка и ручки тележки созданы кодом проекта. Сторонние модели 5.0.1 и их лицензии сохранены; новых сторонних загрузок для 5.1 нет.

## Референсы интерфейса

Снимки Lineage 2M и другие несвободные референсы в эту поставку не включены. Иконки предметов AEGEA созданы отдельно.

## Дополнения 5.2 — лицо и волосы

Для `ranger.glb` и `guard.glb`, включая мобильные варианты, вновь загружен официальный Standard-пакет **Quaternius Universal Base Characters**, **CC0 1.0**: https://quaternius.com/packs/universalbasecharacters.html, загрузка автора https://quaternius.itch.io/universal-base-characters. Встроены `Hair_SimpleParted`, `Hair_Beard` и текстуры лица. Удалён закрывающий лицо капюшон; веса волос переназначены на совместимый скелет; сохранены существующие экипировка и 26 клипов. Полные карты лица — до 1K, ключевые мобильные карты лица героя — 512 px, остальные мобильные карты — 256 px.

Оригинальная лицензия: `licenses/hero-52.txt`. Отчёт преобразования: `tests/hero-asset-report-52.json`; скрипт: `tools/asset-pipeline/hero-52.py`. Новые плащи, мелкие детали земли, карты рельефа, шейдеры и контактные тени созданы кодом проекта.


## Добавлено в 5.3

- **horse.glb** — Wildfire Games / 0 A.D., CC BY-SA 3.0. `horse_celtic.dae`, `horse_brown.png`, horse_idle_01 / horse_walk / horse_gallop. Конвертация скелета и трёх клипов; текстуры 1K и 512 px. Производные GLB сохраняют CC BY-SA 3.0.
- **ship-merchant-53.glb** — карфагенский торговый корабль, Wildfire Games / 0 A.D., CC BY-SA 3.0. Собраны корпус, парус и палубный груз; текстуры преобразованы и сжаты. Производные GLB сохраняют CC BY-SA 3.0.
- **ship-sloop-53.glb** — кельтский торговый парусник, используется как шлюп, Wildfire Games / 0 A.D., CC BY-SA 3.0. Парус поставлен на авторское крепление мачты; перевод COLLADA в GLB. Производные GLB сохраняют CC BY-SA 3.0.
- **coast_sand_04**, **coast_sand_05** — Poly Haven, CC0. Цвет и normal OpenGL, 1K / 512 px. Файлы `sand-*` и `shore-*` в `assets/pbr` и `assets/mobile/pbr`.

Ссылки исходников, размеры и SHA-256: `tools/asset-pipeline/sources-53.json`. Авторский репозиторий: https://github.com/0ad/0ad/tree/master/binaries/data/mods/public/art ; лицензия: https://creativecommons.org/licenses/by-sa/3.0/ . Берег: https://polyhaven.com/a/coast_sand_04 и https://polyhaven.com/a/coast_sand_05 .

Код AEGEA добавляет уплотнение сетки и колебания парусов, отверстия при повреждении, плащ с закреплённым воротником, набор видимой экипировки, упряжь/шасси повозки и видимый груз. Эти изменения не приписываются авторам исходных наборов.
