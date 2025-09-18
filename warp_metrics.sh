#!/bin/bash
# Путь к директории текстового сборщика
TEXTFILE_DIR="/var/lib/node_exporter/textfiles"
OUTPUT_FILE="$TEXTFILE_DIR/warp_metrics.prom"
TEMP_FILE="$OUTPUT_FILE.$$"

# Убеждаемся, что директория существует
mkdir -p "$TEXTFILE_DIR"

# Получение статуса WARP через curl с таймаутом
WARP_TRACE=$(timeout 10 curl --proxy http://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace/ 2>/dev/null)

# Извлечение значения warp из ответа
WARP_VALUE=$(echo "$WARP_TRACE" | grep "warp=" | cut -d'=' -f2)

# Проверка статуса подключения
if [ "$WARP_VALUE" = "on" ]; then
    STATUS=1
else
    STATUS=0
fi

# Получение дополнительной информации с проверкой на пустые значения
ENDPOINT=""
PROTOCOL=""



# Время последнего обновления
TIMESTAMP=$(date +%s)

# Запись метрик в формате Prometheus
cat << EOF > "$TEMP_FILE"
# HELP warp_connected_status Статус подключения WARP (1 = подключен, 0 = отключен)
# TYPE warp_connected_status gauge
warp_connected_status $STATUS

# HELP warp_last_update_timestamp Время последнего обновления метрик
# TYPE warp_last_update_timestamp gauge
warp_last_update_timestamp $TIMESTAMP
EOF

# Проверяем, что файл создался корректно
if [ -s "$TEMP_FILE" ]; then
    # Атомарная замена файла
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    
    # Логирование успеха
    echo "$(date): WARP metrics updated successfully. Status: $STATUS" >> /var/log/warp_metrics.log
else
    # Удаляем поврежденный временный файл
    rm -f "$TEMP_FILE"
    
    # Логирование ошибки
    echo "$(date): Error: Failed to create metrics file" >> /var/log/warp_metrics.log
    exit 1
fi
