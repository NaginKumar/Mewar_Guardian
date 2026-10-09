import os
from waitress import serve
from app import app
from database.db import create_database

if __name__ == "__main__":
    # Ensure database is initialized
    create_database()
    
    port = int(os.environ.get("PORT", 5000))
    host = os.environ.get("HOST", "0.0.0.0")
    
    print(f"============================================================")
    print(f" RAKSHAK AI - Production Server (Waitress)")
    print(f" Running on http://{host}:{port}")
    print(f"============================================================")
    
    # Run production WSGI server (multi-threaded, robust for Windows)
    serve(app, host=host, port=port, threads=6)
