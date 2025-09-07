OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')

if [[ "$ARCH" == "x86_64" ]] then
    ARCH="amd64"
fi

curl -s https://api.github.com/repos/ayehavgunne/mog/releases/latest \
| grep "browser_download_url.*${OS}_${ARCH}"\
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi -

mv mog_${OS}_${ARCH} mog
chmod +x mog
