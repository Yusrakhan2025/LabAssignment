
#!/usr/bin/env bash
set -Eeuo pipefail

echo "=========================================="
echo " DevOps Website Provisioning Started"
echo "=========================================="

WEBSITE_DIR="/vagrant/website"
TEMPLATE_URL="https://www.tooplate.com/zip-templates/2118_chilling_cafe.zip"

# ------------------------------------------------
# 1. Group information: REPLACE THESE PLACEHOLDERS
# ------------------------------------------------

export GROUP_NUMBER="YOUR-GROUP-NUMBER"

export MEMBER_1_NAME="Member One"
export MEMBER_1_REG="Registration Number 1"

export MEMBER_2_NAME="Member Two"
export MEMBER_2_REG="Registration Number 2"

export MEMBER_3_NAME="Member Three"
export MEMBER_3_REG="Registration Number 3"

export MEMBER_4_NAME="Member Four"
export MEMBER_4_REG="Registration Number 4"

# ------------------------------------------------
# 2. Install required utilities if missing
# ------------------------------------------------

if ! command -v curl >/dev/null 2>&1 ||
   ! command -v unzip >/dev/null 2>&1 ||
   ! command -v python3 >/dev/null 2>&1; then

    echo "Installing required utilities..."
    apt-get update
    apt-get install -y curl unzip python3 ca-certificates
fi

# ------------------------------------------------
# 3. Download and extract the website template
#    only when index.html is missing
# ------------------------------------------------

mkdir -p "$WEBSITE_DIR"

if [ ! -f "$WEBSITE_DIR/index.html" ]; then
    echo "Downloading Chilling Cafe template..."

    TEMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TEMP_DIR"' EXIT

    curl -fL --retry 3 \
      "$TEMPLATE_URL" \
      -o "$TEMP_DIR/chilling-cafe.zip"

    unzip -q "$TEMP_DIR/chilling-cafe.zip" \
      -d "$TEMP_DIR/extracted"

    TEMPLATE_INDEX="$(find "$TEMP_DIR/extracted" \
      -type f -name index.html -print -quit)"

    if [ -z "$TEMPLATE_INDEX" ]; then
        echo "ERROR: Template archive has no index.html."
        exit 1
    fi

    TEMPLATE_ROOT="$(dirname "$TEMPLATE_INDEX")"

    # Copy the template contents directly into website/.
    cp -a "$TEMPLATE_ROOT"/. "$WEBSITE_DIR"/

    echo "Template downloaded and extracted."
else
    echo "Existing website/index.html found; skipping download."
fi

# ------------------------------------------------
# 4. Add group details to index.html automatically
#    Marker replacement prevents duplicate sections.
# ------------------------------------------------

python3 <<'PYTHON'
import html
import os
from pathlib import Path

page = Path("/vagrant/website/index.html")

members = [
    (os.environ["MEMBER_1_NAME"], os.environ["MEMBER_1_REG"]),
    (os.environ["MEMBER_2_NAME"], os.environ["MEMBER_2_REG"]),
    (os.environ["MEMBER_3_NAME"], os.environ["MEMBER_3_REG"]),
    (os.environ["MEMBER_4_NAME"], os.environ["MEMBER_4_REG"]),
]

start = "<!-- DEVOPS_GROUP_INFO_START -->"
end = "<!-- DEVOPS_GROUP_INFO_END -->"

content = page.read_text(encoding="utf-8")

# Remove the previous generated section, if any.
while start in content and end in content:
    left = content.index(start)
    right = content.index(end, left) + len(end)
    content = content[:left] + content[right:]

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
  <p><strong>Group Number:</strong>
    {html.escape(os.environ["GROUP_NUMBER"])}</p>
  <table style="width:100%;border-collapse:collapse;">
    <thead>
      <tr><th style="text-align:left;padding:8px;">Member Name</th>
      <th style="text-align:left;padding:8px;">Registration Number</th></tr>
    </thead>
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
print("Group details added to website/index.html.")
PYTHON

# ------------------------------------------------
# 5. Install Docker only if it is missing
# ------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is missing. Installing Docker..."

    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
else
    echo "Docker is already installed; skipping installation."
fi

# ------------------------------------------------
# 6. Start Docker and enable it at boot
# ------------------------------------------------

systemctl enable --now docker

# ------------------------------------------------
# 7. Download the required Nginx image
# ------------------------------------------------

docker pull nginx:alpine

# ------------------------------------------------
# 8. Remove the old container if it exists
# ------------------------------------------------

if docker container inspect devops-web >/dev/null 2>&1; then
    echo "Removing existing devops-web container..."
    docker rm -f devops-web
fi

# ------------------------------------------------
# 9. Run the website container
# ------------------------------------------------

docker run -d \
    --name devops-web \
    --restart unless-stopped \
    -p 80:80 \
    -v /vagrant/website:/usr/share/nginx/html:ro \
    nginx:alpine

# ------------------------------------------------
# 10. Display the container and verify HTTP
# ------------------------------------------------

echo ""
echo "Running container:"
docker ps --filter "name=devops-web"

echo ""
echo "Checking website HTTP response..."

curl -sSI --retry 10 --retry-connrefused \
    --retry-delay 2 http://localhost

echo ""
echo "=========================================="
echo " Provisioning and Deployment Completed"
echo "=========================================="
