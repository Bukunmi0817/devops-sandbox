from flask import Flask, jsonify
import os

app = Flask(__name__)

ENV_ID = os.environ.get("ENV_ID", "unknown")
ENV_NAME = os.environ.get("ENV_NAME", "unnamed")

@app.route("/")
def home():
    return jsonify({
        "message": f"Hello from sandbox env: {ENV_NAME}",
        "env_id": ENV_ID
    })

@app.route("/health")
def health():
    return jsonify({
        "status": "ok",
        "env_id": ENV_ID,
        "env_name": ENV_NAME
    }), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
