
WALLET_DIR="$HOME/.local/share/kwalletd"
WALLET_FILE="$WALLET_DIR/kdewallet.kwl"
SALT_FILE="$WALLET_DIR/kdewallet.salt"
KDEGLOBALS="$HOME/.config/kdeglobals"
LOGTAG="kwallet-switchuser"

if [ ! -f "$WALLET_FILE" ]; then
 [ ! -d "$WALLET_DIR" ] && mkdir -p "$WALLET_DIR"
 touch "$WALLET_FILE"
fi

#if [ "$(pidof ksecretd)" == "" ]; then
# ksecretd &
# disown
#fi
