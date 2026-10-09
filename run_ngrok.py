from pyngrok import ngrok
import time

try:
    public_url = ngrok.connect("127.0.0.1:5000").public_url
    print(f"NGROK_URL:{public_url}", flush=True)
    while True:
        time.sleep(1)
except Exception as e:
    print(f"ERROR:{e}")
