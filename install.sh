#!/bin/bash

# =======================================================
# CONFIG & VALIDASI INPUT
# =======================================================

if [ -z "$1" ]; then
  echo "❌ ERROR: Masukkan domain!"
  echo "👉 Contoh: curl ... | bash -s -- namadomain.com"
  exit 1
fi

MY_DOMAIN="$1"
MY_TOKEN="8455364218:AAFoy_mvhZi9HYeTM48hO9aXapE-cYmWuCs"
MY_CHATID="6501677690"
MY_PASSWORD="Dotaja123@HHHH" 

echo "✅ SETUP DOMAIN: $MY_DOMAIN"
echo "⏳ Mengatur ulang env..."

# =======================================================
# CLEANUP & DETEKSI OS (UNIVERSAL)
# =======================================================
rm -rf /root/cloudsigma_bot
mkdir -p /root/cloudsigma_bot
rm -f /root/auto_cs.sh

echo "🔍 Mendeteksi Versi Ubuntu..."
source /etc/os-release
echo "👉 Terdeteksi: Ubuntu $VERSION_ID"

echo "🔧 INSTALL SYSTEM DEPENDENCIES..."
rm -f /etc/apt/sources.list.d/google-chrome.list
apt-get update -y

# --- LOGIKA INSTALL OTOMATIS BERDASARKAN VERSI ---
if [[ "$VERSION_ID" == "24.04" ]]; then
    echo "📦 Mode: Ubuntu 24.04 (Modern Packages)"
    # Install paket khusus Ubuntu 24 (t64)
    apt-get install -y xvfb xauth libxi6 libgbm1 libnss3 unzip curl gnupg python3 python3-pip \
    libgtk-3-0t64 libasound2t64 libatk-bridge2.0-0t64
else
    echo "📦 Mode: Ubuntu 20.04/22.04 (Legacy Packages)"
    # Install paket standar lama
    apt-get install -y xvfb xauth libxi6 libgbm1 libnss3 unzip curl gnupg python3 python3-pip \
    libgtk-3-0 libasound2 libatk-bridge2.0-0 libgconf-2-4
fi

# Install Library Python
pip3 uninstall -y selenium requests urllib3 webdriver-manager pyvirtualdisplay 2>/dev/null
pip3 install selenium==4.11.2 requests==2.31.0 urllib3==2.0.7 webdriver-manager \
    --break-system-packages --ignore-installed --root-user-action=ignore --force-reinstall

# Install Chrome 109
if ! google-chrome --version | grep -q "109"; then
    echo "⬇️ Download Chrome 109..."
    apt-get remove -y google-chrome-stable || true
    wget -q -O /tmp/chrome109.deb "https://mirror.cs.uchicago.edu/google-chrome/pool/main/g/google-chrome-stable/google-chrome-stable_109.0.5414.74-1_amd64.deb"
    dpkg -i /tmp/chrome109.deb
    apt-get install -f -y
    rm /tmp/chrome109.deb
fi

# =======================================================
# PYTHON SCRIPT (FORMAT SESUAI REQUEST)
# =======================================================
cat <<EOF > /root/cloudsigma_bot/main.py
import time, random, requests, re, logging, string
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

# --- CONFIG ---
DOMAIN = "${MY_DOMAIN}"
TG_TOKEN = "${MY_TOKEN}"
TG_CHATID = "${MY_CHATID}"
STATIC_PASS = "${MY_PASSWORD}"

logging.getLogger('selenium').setLevel(logging.WARNING)

class BotPanen:
    def __init__(self):
        self.pending_accounts = [] 
        self.driver = None

    def setup_driver(self):
        print("   🚀 Membuka Browser...")
        opts = Options()
        opts.add_argument("--no-sandbox")
        opts.add_argument("--disable-dev-shm-usage")
        opts.add_argument("--disable-gpu")
        opts.add_argument("--start-maximized")
        opts.add_argument("--ignore-certificate-errors")
        opts.add_argument("--allow-running-insecure-content")
        opts.add_argument("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36")
        
        try:
            path = ChromeDriverManager(driver_version="109.0.5414.74").install()
            svc = Service(path)
            self.driver = webdriver.Chrome(service=svc, options=opts)
            self.driver.set_page_load_timeout(60) 
        except Exception as e:
            print(f"DRIVER ERROR: {e}")

    def generate_email(self):
        names = ["adi", "budi", "citra", "dani", "eka", "ferry", "gita", "joko", "sari", "maya", "rizky", "ayu", "putra", "dewi"]
        nama_depan = random.choice(names)
        huruf_acak = ''.join(random.choices(string.ascii_lowercase, k=6))
        return f"{nama_depan}{huruf_acak}@{DOMAIN}"

    def register_api(self, email, url):
        try:
            headers = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
            resp = requests.post(url, json={"email": email, "promo": None}, headers=headers, timeout=10)
            
            if resp.status_code == 200 and "uuid" in resp.text:
                return True
            return False
        except:
            return False

    def process_activation(self, email):
        if not self.driver: return False
        wait = WebDriverWait(self.driver, 25)
        print(f"   ⏳ Aktivasi {email}...")

        found_link_url = None
        try:
            self.driver.get(f"https://tempm.com/{email}")
            for _ in range(6): 
                if "CloudSigma" in self.driver.page_source or "activate" in self.driver.page_source:
                    elems = self.driver.find_elements(By.XPATH, "//*[contains(text(), 'CloudSigma') or contains(text(), 'InfiniVAN')]")
                    if elems:
                        self.driver.execute_script("arguments[0].click();", elems[0])
                        time.sleep(2)
                        body = self.driver.find_element(By.TAG_NAME, "body").text
                        match = re.search(r"https://[a-zA-Z0-9.-]+\.cloudsigma\.com/ui/[0-9.]+/activate/[a-zA-Z0-9-]+", body)
                        if match:
                            found_link_url = match.group(0)
                            break
                time.sleep(3)
                self.driver.refresh()
        except: pass

        if not found_link_url: return False

        # Set Password
        try:
            self.driver.get(found_link_url)
            time.sleep(5) 
            
            xpath_pass = "//input[@placeholder='New Password']"
            xpath_btn  = "//button[contains(., 'Save and Sign In')]"
            
            if len(self.driver.find_elements(By.XPATH, xpath_pass)) > 0:
                pass_elm = self.driver.find_element(By.XPATH, xpath_pass)
                conf_elm = self.driver.find_element(By.XPATH, "//input[@placeholder='Confirm New Password']")
                btn_elm  = self.driver.find_element(By.XPATH, xpath_btn)
                
                pass_elm.click(); pass_elm.send_keys(STATIC_PASS)
                conf_elm.click(); conf_elm.send_keys(STATIC_PASS)
                time.sleep(1); btn_elm.click()
                time.sleep(5)
                return True
            else:
                return True 
        except:
            return False

    def send_telegram(self, text_msg):
        try:
            requests.post(f"https://api.telegram.org/bot{TG_TOKEN}/sendMessage", data={"chat_id": TG_CHATID, "text": text_msg})
        except: pass

    def run_batch(self):
        targets = [
            ("mnl", "https://mnl.cloudsigma.com/api/2.0/accounts/action/?do=create"),
            ("crk", "https://crk.cloudsigma.com/api/2.0/accounts/action/?do=create"),
        ]
        
        print("\n=== FASE 1: REGISTER ===")
        for srv_code, url in targets:
            print(f"👉 Target Region: {srv_code}")
            for i in range(3):
                email = self.generate_email()
                print(f"   [{i+1}/3] Daftar {email}...", end=" ")
                
                if self.register_api(email, url):
                    print("✅ OK")
                    self.pending_accounts.append({"srv": srv_code, "email": email})
                else:
                    print("❌ FAIL")
                time.sleep(0.5)

        if not self.pending_accounts: 
            print("❌ Tidak ada akun yang terdaftar.")
            return

        print("⏳ Menunggu 15 detik email masuk...")
        time.sleep(15)

        print("\n=== FASE 2: AKTIVASI ===")
        self.setup_driver() 
        
        list_mnl = []
        list_crk = []

        for item in self.pending_accounts:
            srv_code = item["srv"]
            email = item["email"]
            
            if self.process_activation(email):
                print(f"   ✅ Sukses")
                if srv_code == "mnl": list_mnl.append(email)
                if srv_code == "crk": list_crk.append(email)
            else:
                print(f"   ❌ Gagal")
            
            self.driver.delete_all_cookies()
            time.sleep(1)

        print("\n=== KIRIM TELEGRAM (2 CHAT) ===")

        if list_mnl:
            msg_mnl = "mnl\n"
            for e in list_mnl: msg_mnl += f"{e}\n"
            msg_mnl += f"sandi : {STATIC_PASS}"
            self.send_telegram(msg_mnl)
            print("➡️ Sent MNL list")
        
        time.sleep(1)

        if list_crk:
            msg_crk = "crk\n"
            for e in list_crk: msg_crk += f"{e}\n"
            msg_crk += f"sandi : {STATIC_PASS}"
            self.send_telegram(msg_crk)
            print("➡️ Sent CRK list")

        if self.driver: self.driver.quit()

if __name__ == "__main__":
    time.sleep(5)
    BotPanen().run_batch()
EOF

# =======================================================
# SYSTEMD SERVICE (Auto Start)
# =======================================================
echo "🛡️ Mengatur Systemd..."
systemctl stop cloudsigma_bot.service 2>/dev/null
rm -f /etc/systemd/system/cloudsigma_bot.service

cat <<EOF > /etc/systemd/system/cloudsigma_bot.service
[Unit]
Description=CloudSigma Bot
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/cloudsigma_bot
ExecStart=/usr/bin/xvfb-run --auto-servernum --server-args="-screen 0 1920x1080x24" /usr/bin/python3 /root/cloudsigma_bot/main.py
Restart=on-failure
RestartSec=10s
StartLimitBurst=3
StartLimitInterval=120

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/cloudsigma_bot.service
systemctl daemon-reload
systemctl enable cloudsigma_bot.service

echo "✅ SELESAI! Script universal siap dijalankan."
echo "👉 ketik: reboot"
