#!/bin/bash

# =======================================================
# CONFIG & VALIDASI INPUT
# =======================================================

# 1. CEK APAKAH DOMAIN DIINPUT DI COMMAND
if [ -z "$1" ]; then
  echo "❌ ERROR FATAL: DOMAIN TIDAK DITEMUKAN!"
  echo "⚠️  Anda wajib memasukkan domain saat menjalankan script."
  echo "👉 Contoh yang benar: curl ... | bash -s -- namadomain.com"
  exit 1
fi

# 2. SET CONFIG
MY_DOMAIN="$1"
MY_TOKEN="8455364218:AAFoy_mvhZi9HYeTM48hO9aXapE-cYmWuCs"
MY_CHATID="6501677690"
MY_PASSWORD="Dotaja123@HHHH" 

echo "✅ DOMAIN DITERIMA: $MY_DOMAIN"
echo "⏳ Memulai instalasi..."
# =======================================================

# Bersihkan Script Lama
rm -rf /root/cloudsigma_bot
mkdir -p /root/cloudsigma_bot
rm -f /root/auto_cs.sh

# 1. INSTALL SYSTEM (XVFB + CHROME 109)
echo "🔧 INSTALL SYSTEM..."
rm -f /etc/apt/sources.list.d/google-chrome.list
apt-get update -y
apt-get install -y xvfb xauth libxi6 libgconf-2-4 unzip curl gnupg python3 python3-pip

# Install Library Python
pip3 uninstall -y selenium requests urllib3 webdriver-manager pyvirtualdisplay 2>/dev/null
pip3 install selenium==4.11.2 requests==2.31.0 urllib3==2.0.7 webdriver-manager \
    --break-system-packages --ignore-installed --root-user-action=ignore --force-reinstall

# Install Chrome 109
if ! google-chrome --version | grep -q "109"; then
    apt-get remove -y google-chrome-stable || true
    wget -q -O /tmp/chrome109.deb "https://mirror.cs.uchicago.edu/google-chrome/pool/main/g/google-chrome-stable/google-chrome-stable_109.0.5414.74-1_amd64.deb"
    dpkg -i /tmp/chrome109.deb
    apt-get install -f -y
    rm /tmp/chrome109.deb
fi

# 2. SCRIPT PYTHON (FULL REGION LIST)
# Variabel ${MY_DOMAIN} akan tertulis permanen ke dalam file python saat install
cat <<EOF > /root/cloudsigma_bot/main.py
import time, random, requests, re, logging, os, string
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
OUTPUT_FILE = f"/root/cloudsigma_bot/result_{datetime.now().strftime('%H-%M-%S')}.txt"
ERROR_SCREENSHOT = "/root/cloudsigma_bot/error_debug.png"

logging.getLogger('selenium').setLevel(logging.WARNING)

class BotPanen:
    def __init__(self):
        self.results = []
        self.pending_accounts = [] 
        self.driver = None

    def setup_driver(self):
        print("   🚀 Membuka Browser (GUI Mode)...")
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
        huruf_acak = ''.join(random.choices(string.ascii_lowercase, k=5))
        return f"{nama_depan}{huruf_acak}@{DOMAIN}"

    def register_api(self, email, url):
        try:
            headers = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
            # FAST TIMEOUT: 5 Detik. Kalau server mati, langsung skip.
            resp = requests.post(url, json={"email": email, "promo": None}, headers=headers, timeout=5)
            
            if resp.status_code == 200 and "uuid" in resp.text:
                return True
            return False
        except Exception as e:
            return False

    def process_activation(self, email):
        if not self.driver: return (None, "NO_LINK")
        wait = WebDriverWait(self.driver, 30)
        print(f"   ⏳ Cek Inbox {email}...")

        found_link_url = None
        try:
            self.driver.get(f"https://tempm.com/{email}")
            for _ in range(8): 
                # Keyword disesuaikan agar menangkap semua jenis email CloudSigma
                if "CloudSigma" in self.driver.page_source or "InfiniVAN" in self.driver.page_source or "activate" in self.driver.page_source:
                    elems = self.driver.find_elements(By.XPATH, "//*[contains(text(), 'CloudSigma') or contains(text(), 'InfiniVAN')]")
                    if elems:
                        self.driver.execute_script("arguments[0].click();", elems[0])
                        time.sleep(2)
                        body = self.driver.find_element(By.TAG_NAME, "body").text
                        # Regex Universal untuk menangkap subdomain apapun (zrh, wdc, fra, dll)
                        match = re.search(r"https://[a-zA-Z0-9.-]+\.cloudsigma\.com/ui/[0-9.]+/activate/[a-zA-Z0-9-]+", body)
                        if match:
                            found_link_url = match.group(0)
                            break
                time.sleep(3)
                self.driver.refresh()
        except: pass

        if not found_link_url: return (None, "NO_LINK")

        print(f"   🔗 Link Ketemu! Set Password...")
        try:
            self.driver.get(found_link_url)
            time.sleep(5) 
            
            xpath_pass = "//input[@placeholder='New Password']"
            xpath_conf = "//input[@placeholder='Confirm New Password']"
            xpath_btn  = "//button[contains(., 'Save and Sign In')]"
            
            wait.until(EC.visibility_of_element_located((By.XPATH, xpath_pass)))
            pass_elm = self.driver.find_element(By.XPATH, xpath_pass)
            conf_elm = self.driver.find_element(By.XPATH, xpath_conf)
            btn_elm  = self.driver.find_element(By.XPATH, xpath_btn)
            
            pass_elm.click(); pass_elm.send_keys(STATIC_PASS)
            conf_elm.click(); conf_elm.send_keys(STATIC_PASS)
            time.sleep(1); btn_elm.click()
            time.sleep(5)
            
            if "activate" not in self.driver.current_url: return (found_link_url, "SUKSES")
            elif len(self.driver.find_elements(By.XPATH, xpath_pass)) == 0: return (found_link_url, "SUKSES")
            else: return (found_link_url, "GAGAL_PASS")
        except Exception as e:
            try: self.driver.save_screenshot(ERROR_SCREENSHOT)
            except: pass
            return (found_link_url, "GAGAL_PASS")

    def run_batch(self):
        # === LIST TARGET LENGKAP (UPDATED 2025) ===
        targets = [
            ("CRK (Clark, PH)", "https://crk.cloudsigma.com/api/2.0/accounts/action/?do=create"),
            ("MNL (Manila)", "https://mnl.cloudsigma.com/api/2.0/accounts/action/?do=create"),
        ]
        
        print("\n=== FASE 1: REGISTER MASSAL (AUTO SKIP DEAD API) ===")
        for srv, url in targets:
            for i in range(3): 
                email = self.generate_email()
                print(f"➡️ [{srv}] Daftar {email}...", end=" ")
                
                if self.register_api(email, url):
                    print("✅ SUKSES")
                    self.pending_accounts.append({"srv": srv, "email": email})
                else:
                    print("❌ SKIP (API Down/Limit)")
                
                time.sleep(0.5)

        if not self.pending_accounts: 
            print("❌ Tidak ada akun yang berhasil didaftarkan.")
            return

        print(f"\n✅ Total akun sukses: {len(self.pending_accounts)}")
        print("⏳ Menunggu 15 detik untuk email masuk...")
        time.sleep(15)

        print("\n=== FASE 2: AKTIVASI ===")
        self.setup_driver() 
        
        grouped_results = {}

        for item in self.pending_accounts:
            srv_name = item["srv"]
            email = item["email"]
            
            real_link, status = self.process_activation(email)
            print(f"[{srv_name}] {status} -> {email}")
            
            line_output = ""
            if status == "SUKSES":
                line_output = f"{email}:{STATIC_PASS}"
            elif status == "GAGAL_PASS":
                line_output = f"{email}:{STATIC_PASS} | GAGAL PASS - LINK: {real_link}"
            else: 
                line_output = f"{email}:{STATIC_PASS} | GAGAL INBOX - CEK: https://tempm.com/{email}"
            
            if srv_name not in grouped_results: grouped_results[srv_name] = []
            grouped_results[srv_name].append(line_output)
            
            time.sleep(1)

        # Buat Report Akhir
        final_report = ""
        for srv_name, lines in grouped_results.items():
            final_report += f"[{srv_name}]\n"
            for line in lines: final_report += f"{line}\n"
            final_report += "\n"

        with open(OUTPUT_FILE, "w") as f: f.write(final_report)
        try:
             with open(OUTPUT_FILE, 'rb') as f:
                requests.post(f"https://api.telegram.org/bot{TG_TOKEN}/sendDocument", data={"chat_id": TG_CHATID, "caption": "✅ RESULT AUTO"}, files={"document": f})
        except: pass
        if self.driver: self.driver.quit()

if __name__ == "__main__":
    time.sleep(5)
    BotPanen().run_batch()
EOF

# 3. SYSTEMD SERVICE (ONE-SHOT MODE)
echo "🛡️ Mengatur Systemd (Mode: Jalan Sekali saat Boot)..."

# Bersihkan sisa-sisa
crontab -r 2>/dev/null
systemctl stop cloudsigma_bot.service 2>/dev/null
systemctl disable cloudsigma_bot.service 2>/dev/null
rm -f /etc/systemd/system/cloudsigma_bot.service

# Buat File Service
cat <<EOF > /etc/systemd/system/cloudsigma_bot.service
[Unit]
Description=CloudSigma Bot (Run Once)
# Pastikan internet sudah nyambung sebelum jalan
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/cloudsigma_bot
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="DISPLAY=:99"

# Perintah Eksekusi
ExecStart=/usr/bin/xvfb-run --auto-servernum --server-args="-screen 0 1920x1080x24" /usr/bin/python3 /root/cloudsigma_bot/main.py

# === LOGIC RESTART ===
Restart=on-failure
RestartSec=10s
StartLimitBurst=3
StartLimitInterval=120

# Simpan Log
StandardOutput=append:/root/cloudsigma_bot/run.log
StandardError=append:/root/cloudsigma_bot/error.log

[Install]
WantedBy=multi-user.target
EOF

# Aktifkan Service
chmod 644 /etc/systemd/system/cloudsigma_bot.service
systemctl daemon-reload
systemctl enable cloudsigma_bot.service

echo "✅ SELESAI! Setup dengan domain: $MY_DOMAIN berhasil."
echo "ℹ️  Bot akan jalan otomatis saat reboot/shutdown berikutnya."
