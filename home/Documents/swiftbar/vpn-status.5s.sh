#!/usr/bin/env bash
# <xbar.title>VPN Status</xbar.title>
# <xbar.desc>Tailscale (utun + CGNAT IP) と Secondary VPN (ppp* + IPv4) の接続を判定して表示する。</xbar.desc>
# <xbar.version>3.0</xbar.version>

# Tailscale 検出: utun* に CGNAT 帯 (100.64.0.0/10) のIPv4が付いているか
# 同じ CGNAT 帯を utun に張る別 VPN がある環境では誤検知し得る。
tailscale_iface=$(/sbin/ifconfig -a inet | /usr/bin/awk '
  /^[^[:space:]:]+:/     { iface = "" }
  /^utun[[:digit:]]+:/   { iface = $1; sub(":", "", iface) }
  iface && /^[[:space:]]*inet[[:space:]]100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\./ {
    print iface
    exit
  }
')

# Secondary VPN 検出: ppp* に IPv4 が付いているか (macOS 標準の L2TP/IPsec は ppp0 を使う)
# 注意: 対象以外の PPP/L2TP/PPTP 系 VPN を併用すると誤検知し得る。
secondary_iface=$(/sbin/ifconfig -a inet | /usr/bin/awk '
  /^[^[:space:]:]+:/     { iface = "" }
  /^ppp[[:digit:]]+:/    { iface = $1; sub(":", "", iface) }
  iface && /^[[:space:]]*inet[[:space:]][0-9]/ {
    print iface
    exit
  }
')

if [ -n "$tailscale_iface" ] || [ -n "$secondary_iface" ]; then
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
  if [ -n "$tailscale_iface" ]; then
    echo "Tailscale: Connected ($tailscale_iface)"
  else
    echo "Tailscale: Not Connected"
  fi
  if [ -n "$secondary_iface" ]; then
    echo "Secondary: Connected ($secondary_iface)"
  else
    echo "Secondary: Not Connected"
  fi
else
  echo "✗ | color=white"
  echo "---"
  echo "Status: Not Connected"
  echo "Tailscale: Not Connected"
  echo "Secondary: Not Connected"
fi
