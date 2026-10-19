
#!/usr/bin/env bash
set -Eeuo pipefail

echo "=========================================="
echo " DevOps Website Provisioning Started"
echo "=========================================="

WEBSITE_DIR="/vagrant/website"
TEMPLATE_URL="https://www.tooplate.com/zip-templates/2118_chilling_cafe.zip"

export MEMBER_1_NAME="Taufiq-ur-Rahim"
export MEMBER_1_REG="FA23-BCS-125"

export MEMBER_2_NAME="Yusra Javed"
export MEMBER_2_REG="FA23-BCS-137"

# Install required utilities only when missing.
if ! command -v curl >/dev/null 2>&1 ||
   ! command -v unzip >/dev/null 2>&1 ||
   ! command -v python3 >/dev/null 2>&1; then
    apt-get update
    apt-get install -y curl unzip python3 ca-certificates
fi


# Download the template if index.html is missing or empty.
mkdir -p "$WEBSITE_DIR"

if [ ! -s "$WEBSITE_DIR/index.html" ]; then
    echo "Attempting to download the Chilling Cafe template..."

    TEMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TEMP_DIR"' EXIT
    mkdir -p "$TEMP_DIR/extracted"

    if curl -fL --retry 2 --retry-delay 2 \
        --connect-timeout 20 \
        "$TEMPLATE_URL" -o "$TEMP_DIR/website.zip" &&
       unzip -q "$TEMP_DIR/website.zip" \
        -d "$TEMP_DIR/extracted"; then

        TEMPLATE_INDEX="$(find "$TEMP_DIR/extracted" \
            -type f -name index.html -print -quit)"

        if [ -n "$TEMPLATE_INDEX" ]; then
            cp -a "$(dirname "$TEMPLATE_INDEX")"/. "$WEBSITE_DIR"/
            echo "Chilling Cafe template downloaded successfully."
        else
            echo "Template archive has no index.html; using fallback."
        fi
    else
        echo "Template download failed; using fallback website."
    fi

    # Create a local website if the download was unsuccessful.
    if [ ! -s "$WEBSITE_DIR/index.html" ]; then
        cat > "$WEBSITE_DIR/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DevOps Cafe</title>
<style>
body {
  margin: 0;
  font-family: Arial, sans-serif;
  background: #f5eee5;
  color: #39291f;
}
header {
  padding: 70px 20px;
  text-align: center;
  background: #49352a;
  color: white;
}
header h1 { font-size: 42px; margin-bottom: 12px; }
main {
  max-width: 900px;
  margin: 35px auto;
  padding: 25px;
  background: white;
  border-radius: 12px;
  line-height: 1.7;
}
h2 { color: #805333; }
footer {
  padding: 20px;
  text-align: center;
  background: #49352a;
  color: white;
}
</style>
</head>
<body>
<header>
  <h1>Welcome to DevOps Cafe</h1>
  <p>A website deployed automatically using Vagrant, Docker and Nginx.</p>
</header>
<main>
  <h2>Our Website</h2>
  <p>This website is hosted inside an Nginx Docker container running
  in an Ubuntu virtual machine managed by Vagrant.</p>
  <p>Deployment is automated through shell provisioning.</p>
</main>
<footer>DevOps Lab Project</footer>
</body>
</html>
HTML
        echo "Fallback website created successfully."
    fi
else
    echo "Website already exists; skipping download."
fi


# Add group details, replacing the generated section on reruns.
python3 <<'PYTHON'
import html
import os
from pathlib import Path

page = Path("/vagrant/website/index.html")
content = page.read_text(encoding="utf-8")

start = "<!-- DEVOPS_GROUP_INFO_START -->"
end = "<!-- DEVOPS_GROUP_INFO_END -->"

while start in content and end in content:
    left = content.index(start)
    right = content.index(end, left) + len(end)
    content = content[:left] + content[right:]

members = [
    (os.environ["MEMBER_1_NAME"], os.environ["MEMBER_1_REG"]),
    (os.environ["MEMBER_2_NAME"], os.environ["MEMBER_2_REG"]),
]

rows = "\n".join(
    "<tr><td>{}</td><td>{}</td></tr>".format(
        html.escape(name), html.escape(reg)
    )
    for name, reg in members
)

section = f"""
{start}
<section style="max-width:900px;margin:35px auto;padding:24px;
background:#fff8ee;color:#382b20;border-radius:10px;
font-family:Arial,sans-serif;">
<h2>DevOps Lab Group Details</h2>
<table style="width:100%;border-collapse:collapse;">
<thead><tr><th>Member Name</th><th>Registration Number</th></tr></thead>
<tbody>{rows}</tbody>
</table>
</section>
{end}
"""

if "</body>" in content:
    content = content.replace("</body>", section + "\n</body>", 1)
else:
    content += section

page.write_text(content, encoding="utf-8")
print("Group details added to website.")
PYTHON

# Install Docker only if it is missing.
if ! command -v docker >/dev/null 2>&1; then
    echo "Installing Docker inside Ubuntu..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
else
    echo "Docker is already installed."
fi

# Start Docker.
systemctl enable --now docker

# Download the Nginx image.
docker pull nginx:alpine

# Remove the previous container on repeated provisioning.
if docker container inspect devops-web >/dev/null 2>&1; then
    docker rm -f devops-web
fi

# Start the website container.
docker run -d \
    --name devops-web \
    --restart unless-stopped \
    -p 80:80 \
    -v /vagrant/website:/usr/share/nginx/html:ro \
    nginx:alpine

# Display the container and verify the HTTP response.
echo "Running container:"
docker ps --filter "name=devops-web"

echo "Checking website response..."
curl -f -sS -I \
    --retry 10 \
    --retry-connrefused \
    --retry-delay 2 \
    http://localhost

echo "=========================================="
echo " Provisioning and Deployment Completed"
echo "=========================================="
