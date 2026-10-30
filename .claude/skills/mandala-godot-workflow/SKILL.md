---
name: mandala-godot-workflow
description: Как работать с проектом «мандала» (Godot 4.3 C#, папка mandala_) и его 3D-моделями через Godot и Blender из командной строки — правка сцен .tscn, свет, материалы и шейдеры, импорт текстур, проверка результата рендером в PNG, габариты моделей, осмотр и доработка моделей и текстур в Blender (например, более реалистичная кожа). Используй этот навык всегда, когда задача касается сцен, моделей, текстур, света или внешнего вида в mandala_/ (Датта, мандала, teurgia, божества, лотос, пол, VR-версия под Quest), даже если пользователь не называет Godot или Blender прямо — например «сделай пол красивее», «лицо мультяшное», «поправь свет», «добавь кнопку в меню», «проверь, как выглядит сцена».
---

# Проект «мандала»: Godot + Blender из командной строки

Пользователь пишет по-русски, отвечай по-русски. Цель проекта — VR-версия для Meta Quest на Godot.

## Пути

| Что | Где |
|---|---|
| Проект Godot | `C:\Users\shumi\Documents\VR\mandala_` |
| Godot 4.3 .NET (консоль) | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.3-stable_mono_win64\Godot_v4.3-stable_mono_win64_console.exe` |
| Blender 5.2 | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` |
| Скрипты навыка | `scripts/` рядом с этим файлом |

Ниже `$G` — путь к консольному Godot, `$B` — к Blender, `$S` — к папке `scripts/`.

## Главные правила (почему — в скобках)

1. **Перед правкой любого `.tscn` убедись, что Godot закрыт** (`tasklist /FI "IMAGENAME eq Godot_v4.3-stable_mono_win64.exe"`). Если запущен — попроси пользователя закрыть Godot целиком, не только таб. (Открытый редактор при сохранении или F5 молча перезаписывает файл своей версией — так терялись правки трижды.) Новые файлы — шейдеры, материалы `.tres`, текстуры — создавать при открытом редакторе можно. После правок скажи, что Godot можно открывать.
2. **Эксперименты — в копии `teurgia1`**: сцена `teurgia1.tscn`, ассеты `models/gods/teurgia1/`. Оригинал (`main.tscn`, `models/gods/datta/`) не трогай. (Пользователь хочет сравнивать с оригиналом и откатываться.)
3. **Проверяй результат глазами**: после изменения внешнего вида сними кадр (`render_shot.gd`) и посмотри PNG через Read. Сравнивай «до/после» с тем же ракурсом и отправляй пользователю кадры через SendUserFile. Если стало хуже — скажи прямо и откати.
4. Сначала делай немного и проверяй: сильные эффекты (SSS, ореол, свет 14+) уже давали «молочное» лицо и пересвет.

## Формат файлов Godot 4.3

- `Transform3D(...)` в `.tscn` — базис **построчно**: `x.x, y.x, z.x, x.y, y.y, z.y, x.z, y.z, z.z, ox, oy, oz`. Для «стоит в точке A и смотрит на B» не считай вручную — используй `look_at_xf.gd`.
- При добавлении узла/ресурса увеличь `load_steps` в шапке `[gd_scene ...]`, если добавил `ext_resource`/`sub_resource`.
- `ext_resource` можно писать без `uid=` — Godot найдёт по пути и сам назначит uid.
- **Копируя ассеты**, убирай `uid="uid://..."` из шапок и ссылок в копиях, а в `.import` — строки `uid=`, `path...=`, `dest_files=`; иначе дубли UID и копия путается с оригиналом. Пути `res://...` в копиях замени на новые.
- После копирования/новых текстур: `"$G" --headless --path mandala_ --import`. Модель `.glb` с текстурами рядом может импортироваться раньше них — тогда удали её `.md5` в `.godot/imported/` и импортируй ещё раз.
- **Новые PNG для 3D** Godot по умолчанию импортирует как 2D (без сжатия и mipmap). Перед первым импортом создай рядом `.import` с `compress/mode=2`, `mipmaps/generate=true` и `compress/normal_map=1` для normal map (`=2` для цвета). Готовый образец — `models/gods/teurgia1/main/textures/Datta_low_Material_3_Normal_skin.png.import` (скопируй, поменяй `source_file`, убери `uid`/`path`/`dest_files`).
- Проект на рендерере **Forward+** (SSR/SSAO/SSIL работают на ПК); на Quest будет Mobile, где их нет.

## Устройство сцен

- `Initial.tscn` → `src/app/App.tscn` (сплэш + меню) → `main.tscn` (Датта), `mandala5.tscn` (Датта + 5 божеств), `teurgia1.tscn` (копия Датты для экспериментов).
- Меню `src/menu/menu_layer.tscn` + `Menu.cs`: кнопки сцен показываются по свойствам `IsStart…Shown`, которые выставляет каждая сцена у своего экземпляра `Menu`.
- В Датте свет: 3 прожектора на `MainCamera` (едут с камерой), в `teurgia1` ещё `Environment/KeyLight` и `RimLight` (неподвижные). Камера крутится вокруг `Gods/Datta/CameraOrigin` (`Scene.cs`).
- Модель Датты (`datta.glb`): голова с тремя лицами `Golova_low` + глаза `Glasa_low` → `Material_3`; тело/руки `Body_low`, стопы `Stupni_low`, одежда, волосы → `Material_1`; атрибуты → `Material_2`. Текстуры HDRP 4096²: MaskMap R=metallic, G=AO, A=**smoothness** (не roughness). Мир Godot: Y вверх, лицо смотрит в +Z; в Blender после импорта glTF: Z вверх, лицо в −Y.

## Скрипты

### Снимок сцены — `render_shot.gd`
Открывает окно на пару секунд (нужен настоящий рендер, `--headless` не подойдёт).
```powershell
$env:SCENE="res://teurgia1.tscn"; $env:OUT="<scratchpad>\shot.png"; $env:CAM="0,3.05,1.0"; $env:LOOK="0,3.0,0"
& $G --path C:\Users\shumi\Documents\VR\mandala_ --windowed -s "$S\render_shot.gd"
```
Ракурсы Датты: лицо крупно `CAM=0,3.02,0.55`; лицо и плечи `0,3.05,1.0`; по пояс `CAM=0,2.6,1.6 LOOK=0,2.4,0`; вид сверху `CAM=0,20,0.01 LOOK=0,0,0 ORTHO=12` (потом сними `$env:ORTHO`, иначе следующие кадры тоже будут орто). Корневой скрипт сцены и `Menu` отключаются, свет и камера с прожекторами — игровые.

Кадр «как в игре» (с меню и игровой камерой): `& $G --path ... "res://teurgia1.tscn" --windowed --resolution 1280x720 --write-movie <папка>\frame.png --fixed-fps 10 --quit-after 40` — папка должна существовать; смотри последний `frameNNNNNNNN.png`.

### Габариты моделей — `bounds.gd`
`& $G --headless --path ... -s "$S\bounds.gd" -- res://models/gods/teurgia1/others/lotos.tscn` → `BOUNDS ... min max center size`. Нужно, чтобы ставить объекты (пол, свет) точно, а не на глаз. Пример: лотос — низ y≈−0.17, центр (0.05, −0.36) по xz, радиус ≈2.4.

### Трансформ «смотреть на точку» — `look_at_xf.gd`
`& $G --headless -s "$S\look_at_xf.gd" -- "-2.2,4.8,2.4" "0,3.0,0"` → готовая строка `transform = Transform3D(...)` для `.tscn`.

### Осмотр модели в Blender — `blender_inspect.py`
`& $B --background --factory-startup --python "$S\blender_inspect.py" -- <модель.glb>` → объекты, вершины, материалы, размеры.

### Реалистичная кожа — `skin_texture.py`
Добавляет в «нарисованную» ровную кожу неравномерность тона, румянец носа/щёк/губ, тень глазниц и поры в normal map. Маска кожи — по цвету и по выбранным объектам, поэтому одежда и волосы не меняются. Зоны лица находятся сами по объекту глаз.
```powershell
# лицо (голова + глаза)
& $B --background --factory-startup --python "$S\skin_texture.py" -- --glb <...>\teurgia1\main\datta.glb `
  --texdir <...>\teurgia1\main\textures --prefix Datta_low_Material_3 --objects Golova_low --eyes Glasa_low `
  --out <scratchpad>\out --preview <scratchpad>\prev
# тело: поры слабее, бежевая/оранжевая одежда исключена
... --prefix Datta_low_Material_1 --objects Body_low,Stupni_low --pores 0.25 --sat-max 0.4 --preview-center 0,-0.3,2.4
```
Около минуты на 4096². Кроп превью берётся у первого найденного лица (может оказаться боковое — это нормально) или у `--preview-center`. Перед подключением посмотри `prev/crop_masks.png` (красный — щёки и губы, зелёный — нос, синий — глазницы; должны лечь на лицо) и `crop_before/after.png`. Затем скопируй PNG в папку текстур копии, создай `.import` (см. выше), импортируй, поменяй два пути в нужном `Material_N.tres` и сравни рендеры. Откат — вернуть пути на `.tga`.

Чего этот подход не умеет: менять форму лица (глаза, скулы, нос). Это работа 3D-художника в Blender/ZBrush — так и скажи пользователю.

## Что уже пробовали и не сработало
- Шейдер кожи с SSS (даже 0.12) размывает глаза и губы; инверсия roughness на голове делает волосы синими от отражения неба. Материалы Датты оставлены стандартными, реализм — через свет и текстуры.
