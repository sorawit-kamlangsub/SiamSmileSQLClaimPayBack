import json
import os
import urllib.request


LINE_TOKEN = os.environ["LINE_CHANNEL_ACCESS_TOKEN"]
LINE_TO = os.environ["LINE_TO"]

with open("issues.json", "r", encoding="utf-8") as f:
    issues = json.load(f)


for issue in issues:

    title = issue["title"]
    url = issue["url"]

    message = (
        f"🔔 {title}\n\n"
        f"{url}"
    )

    data = {
        "to": LINE_TO,
        "messages": [
            {
                "type": "text",
                "text": message
            }
        ]
    }

    request = urllib.request.Request(
        "https://api.line.me/v2/bot/message/push",
        data=json.dumps(data).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {LINE_TOKEN}"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(request) as response:
            print(
                f"LINE sent: "
                f"Issue #{issue['number']} "
                f"HTTP {response.status}"
            )

    except urllib.error.HTTPError as e:
        print(f"LINE ERROR: HTTP {e.code}")
        print(e.read().decode("utf-8"))