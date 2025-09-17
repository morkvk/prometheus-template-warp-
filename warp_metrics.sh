#!/bin/bash

# Путь к директории текстового сборщика
TEXTFILE_DIR="/var/lib/node_exporter/textfiles"
OUTPUT_FILE="$TEXTFILE_DIR/warp_metrics.prom"
TEMP_FILE="$OUTPUT_FILE.$$"

# Убеждаемся, что директория существует
mkdir -p "$TEXTFILE_DIR"

# Получение статуса WARP с таймаутом
WARP_STATUS=$(timeout 10 warp-cli status 2>/dev/null)
WARP_SETTINGS=$(timeout 10 warp-cli settings 2>/dev/null)

# Проверка статуса подключения
if echo "$WARP_STATUS" | grep -q "Connected"; then
    STATUS=1
else
    STATUS=0
fi

# Получение дополнительной информации
ENDPOINT=""
PROTOCOL=""
if [ $STATUS -eq 1 ]; then
    ENDPOINT=$(echo "$WARP_STATUS" | grep -o 'via [^[:space:]]*' | cut -d' ' -f2 | head -1)
    PROTOCOL=$(echo "$WARP_SETTINGS" | grep -i "protocol" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
fi

# Время последнего обновления
TIMESTAMP=$(date +%s)

# Запись метрик в формате Prometheus
cat << EOF > "$TEMP_FILE"
# HELP warp_connected_status Статус подключения WARP (1 = подключен, 0 = отключен)
# TYPE warp_connected_status gauge
warp_connected_status $STATUS

# HELP warp_info Информация о WARP подключении
# TYPE warp_info gauge
warp_info{endpoint="$ENDPOINT",protocol="$PROTOCOL"} $STATUS

# HELP warp_last_update_timestamp Время последнего обновления метрик
# TYPE warp_last_update_timestamp gauge
warp_last_update_timestamp $TIMESTAMP
EOF

# Атомарная замена файла
mv "$TEMP_FILE" "$OUTPUT_FILE"

# Логирование (опционально)
echo "$(date): WARP metrics updated. Status: $STATUS" >> /var/log/warp_metrics.log
