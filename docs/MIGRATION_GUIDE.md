# Инструкция по миграции с форка BlackHole на субмодульный подход

## Зачем мигрировать?

Текущий подход (форк BlackHole) имеет серьезные недостатки:

- 🔴 **Сложная синхронизация** - нужно постоянно мержить upstream изменения
- 🔴 **Лицензионные сложности** - GPL-3.0 от BlackHole смешивается с нашей лицензией  
- 🔴 **Риск конфликтов** при обновлениях BlackHole
- 🔴 **Смешанная кодовая база** - JoyCast логика перемешана с BlackHole

Новый подход (субмодуль) решает все эти проблемы:

- ✅ **Чистое разделение** - BlackHole остается нетронутым
- ✅ **Легкие обновления** - `git submodule update`
- ✅ **Четкие лицензии** - GPL для BlackHole, MIT для JoyCast
- ✅ **Профессиональная структура**

## План миграции

### 1. Подготовка

```bash
# Создай новый репозиторий
mkdir joycast.driver.new
cd joycast.driver.new
git init

# Добавь BlackHole как субмодуль
git submodule add https://github.com/ExistentialAudio/BlackHole.git BlackHole
```

### 2. Создай структуру

```bash
mkdir -p configs assets scripts docs releases
```

### 3. Перенеси конфигурации

Создай файлы конфигурации:

**configs/joycast_prod.env:**
```bash
DRIVER_NAME="JoyCast"
BUNDLE_ID="com.joycast.virtualmic"
DEVICE_NAME="JoyCast Virtual Microphone"
# ... остальные параметры
```

**configs/joycast_dev.env:**
```bash
DRIVER_NAME="JoyCast Dev"  
BUNDLE_ID="com.joycast.virtualmic.dev"
DEVICE_NAME="JoyCast Dev Virtual Microphone"
# ... остальные параметры
```

### 4. Создай скрипты сборки

**scripts/build_driver.sh** - основной скрипт сборки
**scripts/install_driver.sh** - скрипт установки
**configs/build_utils.sh** - утилиты для сборки

### 5. Перенеси ресурсы

```bash
# Скопируй JoyCast-специфичные файлы
cp old_repo/BlackHole/JoyCast.icns assets/
cp old_repo/VERSION .
cp old_repo/LICENSE .
```

### 6. Протестируй

```bash
# Собери dev версию
./scripts/build_driver.sh dev

# Проверь что все работает
ls -la build/
plutil -p build/JoyCast\ Dev.driver/Contents/Info.plist
```

### 7. Настрой CI/CD

Обнови GitHub Actions для работы с субмодулями:

```yaml
- name: Checkout with submodules
  uses: actions/checkout@v3
  with:
    submodules: recursive

- name: Build driver
  run: ./scripts/build_driver.sh prod
```

## Сравнение подходов

| Аспект | Форк (старый) | Субмодуль (новый) |
|--------|---------------|-------------------|
| Обновление BlackHole | `git merge upstream/master` + конфликты | `git submodule update` |
| Лицензирование | Смешанное GPL/MIT | Четкое разделение |
| Структура кода | Перемешано | Чистое разделение |
| Риск ошибок | Высокий | Низкий |
| Профессионализм | Средний | Высокий |

## Что меняется для разработчика

### Было (форк):
```bash
git clone https://github.com/joycast/joycast.driver.git
cd joycast.driver
./build_joycast_driver.sh dev
```

### Стало (субмодуль):
```bash
git clone --recursive https://github.com/joycast/joycast.driver.git
cd joycast.driver
./scripts/build_driver.sh dev
```

## Обновление BlackHole

### Было (сложно):
```bash
git remote add upstream https://github.com/ExistentialAudio/BlackHole.git
git fetch upstream
git merge upstream/master  # часто конфликты!
# разрешить конфликты...
git commit
```

### Стало (просто):
```bash
cd BlackHole
git fetch origin
git checkout v0.6.2  # новая версия
cd ..
git add BlackHole
git commit -m "Update BlackHole to v0.6.2"
```

## Рекомендации

1. **Мигрируй постепенно** - сначала настрой новую структуру, протестируй
2. **Сохрани старый репозиторий** - как backup на время
3. **Обнови документацию** - для команды и пользователей
4. **Настрой CI/CD** - для автоматической сборки и тестов

## Результат

После миграции ты получишь:

- 📁 **Чистую структуру** проекта
- 🔄 **Простые обновления** BlackHole  
- ⚖️ **Четкое лицензирование**
- 🛡️ **Меньше ошибок**
- 🏢 **Профессиональный подход**

Это инвестиция в будущее проекта, которая окупится уже через месяц использования! 