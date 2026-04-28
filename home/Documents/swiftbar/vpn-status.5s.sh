#!/usr/bin/env bash
# <xbar.title>VPN Status</xbar.title>
# <xbar.desc>utun 上の Tailscale CGNAT IP の有無で VPN 接続を判定して表示する。</xbar.desc>
# <xbar.version>2.0</xbar.version>

# 表示用ラベル (検出ロジックはこの値に依存しない)
VPN_NAME="Tailscale"

# Tailscale は utun* に CGNAT 帯 (100.64.0.0/10 = 100.64.0.0〜100.127.255.255) の IP を割り当てる。
# その有無で接続判定する。System Extension 版 (macsys / MAS) でも standalone tailscaled でも検出可能。
# 注意: 同じ CGNAT 帯を utun に張る別 VPN がある環境では誤検知し得る。
tunnel=$(/sbin/ifconfig -a inet | /usr/bin/awk '
  /^[^[:space:]:]+:/     { iface = "" }
  /^utun[0-9]+:/         { iface = $1; sub(":", "", iface) }
  iface && /^[[:space:]]*inet 100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\./ {
    print iface
    exit
  }
')

if [ -n "$tunnel" ]; then
  # 接続中は1秒ごとに6色レインボー回転
  sec=$(/bin/date +%S)
  mod=$((10#$sec % 6))
  case "$mod" in
    0) color="red" ;;
    1) color="orange" ;;
    2) color="yellow" ;;
    3) color="green" ;;
    4) color="blue" ;;
    5) color="magenta" ;;
  esac
  echo "VPN接続中 ● | color=$color"
  echo "---"
  echo "Status: Connected"
  echo "Service: $VPN_NAME"
  echo "Interface: $tunnel"
else
  echo "✗ | color=white"
  echo "---"
  echo "Status: Not Connected"
  echo "Service: $VPN_NAME"
fi
