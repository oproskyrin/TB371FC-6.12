#!/bin/sh
# R186: Chromium smoothness test - a Rutube video for 40 s (muted), dropped frames from the browser
# (HTMLVideoElement.getVideoPlaybackQuality) + CPU load + chrome://gpu feature status.
# usage: r186-video-test.sh LABEL [extra chromium flags...]
label=$1; shift
pid=$(pgrep -u alarm plasmashell | head -1)
tr '\0' '\n' < /proc/$pid/environ | grep -v -E '^(_|SHLVL|PWD|OLDPWD)=' > /tmp/plasma.env
E="env -i $(tr '\n' ' ' < /tmp/plasma.env)"
cdp="python3 /usr/local/sbin/tb371fc-cdp.py"
pkill -u alarm -f '/usr/lib/chromium/chromium' 2>/dev/null; sleep 2
cd /home/alarm
setsid runuser -u alarm -- $E /usr/bin/chromium --remote-debugging-port=9222 --autoplay-policy=no-user-gesture-required \
  --no-first-run --password-store=basic --start-maximized "$@" https://rutube.ru/ >/tmp/chromium-test.log 2>&1 < /dev/null &
for i in $(seq 1 40); do curl -s http://127.0.0.1:9222/json >/dev/null 2>&1 && break; sleep 1; done
for i in $(seq 1 30); do n=$($cdp eval "document.querySelectorAll('a[href*=\"/video/\"]').length" 2>/dev/null); [ "${n:-0}" -gt 0 ] 2>/dev/null && break; sleep 2; done
id=$($cdp eval "(()=>{const m=[...document.querySelectorAll('a[href*=\"/video/\"]')].map(a=>a.href.match(/video\/([0-9a-f]{32})/)).filter(Boolean);return m.length?m[0][1]:''})()" | tr -d '"')
echo "video id: $id"
[ -n "$id" ] || { echo "no video found on the main page"; exit 1; }
$cdp nav "https://rutube.ru/play/embed/$id" >/dev/null
sleep 10
$cdp eval "(()=>{const v=document.querySelector('video'); if(!v) return 'no video element'; v.muted=true; v.play(); return 'play'})()"
sleep 15
# measure 40 s after start-up / preroll
ticks() { for p in $(pgrep -u alarm -f /usr/lib/chromium/chromium) $(pgrep -u alarm -x kwin_wayland); do awk '{s+=$14+$15} END{print s}' /proc/$p/stat; done | awk '{s+=$1} END{print s}'; }
q0=$($cdp eval "(()=>{const v=document.querySelector('video');const q=v.getVideoPlaybackQuality();return [q.totalVideoFrames,q.droppedVideoFrames,v.currentTime].join(' ')})()" | tr -d '"')
c0=$(ticks); set -- $(awk '/^cpu /{s=0;for(i=2;i<=NF;i++)s+=$i;print s,$5}' /proc/stat); a0=$1; i0=$2
sleep 40
q1=$($cdp eval "(()=>{const v=document.querySelector('video');const q=v.getVideoPlaybackQuality();return [q.totalVideoFrames,q.droppedVideoFrames,v.currentTime,v.videoWidth+'x'+v.videoHeight,v.paused].join(' ')})()" | tr -d '"')
c1=$(ticks); set -- $(awk '/^cpu /{s=0;for(i=2;i<=NF;i++)s+=$i;print s,$5}' /proc/stat); a1=$1; i1=$2
echo "$q0 | $q1" | awk -v L="$label" -v c=$((c1-c0)) -v a=$((a1-a0)) -v i=$((i1-i0)) '{split($0,x," [|] "); split(x[1],s," "); split(x[2],e," "); f=e[1]-s[1]; d=e[2]-s[2]; t=e[3]-s[3]; printf "%s: %s, played %.1f s, %d frames shown (%.1f fps), %d dropped (%.1f%%), paused=%s, browser+kwin CPU %.0f%% of one core, system busy %.0f%%\n", L, e[4], t, f, f/40, d, (f>0?100*d/f:0), e[5], c/40, 100*(a-i)/a}'
$cdp nav chrome://gpu >/dev/null; sleep 4
$cdp eval "(()=>{const i=document.querySelector('info-view');return (i&&i.shadowRoot?i.shadowRoot.innerText:document.body.innerText)})()" | python3 -c 'import json,sys; t=json.load(sys.stdin); t=t if isinstance(t,str) else str(t); s=t.find("Graphics Feature Status"); print(t[s:s+900])'
pkill -u alarm -f '/usr/lib/chromium/chromium'
