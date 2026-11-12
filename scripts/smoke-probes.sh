# shellcheck shell=bash
# Scrutiny：sso=none（上游没有任何登录，网页在核心网关登录之后）；清单没有 mcp。
# 上游 webapp 的接口无认证（server.go 没有认证中间件），经网关用 web_get 调（带用户会话）。
# 数据探针走应用自己的设置接口：GET /api/settings 拿全部设置，把 theme 换成随机标记后整份 POST 回去。
# 必须整份回传：POST 绑定整个 Settings 结构体再全量写回设置表（上游 scrutiny_repository_settings.go
# 的 SaveSettings），缺字段会按零值写掉别的设置。值落在 SQLite（/opt/scrutiny/config/scrutiny.db），
# 升级、重装不删数据就还在。
#
# 变量别叫 state：shellcheck 把这份文件连着 probes.sh 一起分析，probes.sh 自己也读一个 dev.sh 提供的 state；
# 子壳体函数（fn() ( … )）里给 state 赋值，SC2031 就报在 probes.sh 上，CI 红。

web_assert() { grep -qi '<title>scrutiny'; }   # 上游 Angular 单页的 index.html 标题

export IDENTITY_NA=1
export SMOKE_NOTE="应用没有登录和用户体系（上游无认证，网页在核心网关登录之后）"

data_write() {
  local settings marker resp
  settings="$(web_get /api/settings)" || { echo "GET /api/settings 失败：$settings"; return 1; }
  settings="$(jq -ce '.settings' <<<"$settings")" || { echo "settings 响应不对：$(head -c 200 <<<"$settings")"; return 1; }
  marker="wonton-smoke-$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
  resp="$(web_get /api/settings -X POST -H 'Content-Type: application/json' \
    --data "$(jq -cn --argjson s "$settings" --arg m "$marker" '$s * {theme: $m}')")" \
    || { echo "POST /api/settings 失败：$resp"; return 1; }
  jq -e --arg m "$marker" '.success == true and .settings.theme == $m' <<<"$resp" >/dev/null \
    || { echo "POST 返回的 theme 不是 $marker：$(head -c 200 <<<"$resp")"; return 1; }
  printf '%s' "$marker" >"$SMOKE_STATE"
}

data_check() { # 设置表里的 theme 还是那个标记
  local marker got
  marker="$(cat "$SMOKE_STATE")"
  [[ -n "$marker" ]] || { echo "标记文件里没有标记"; return 1; }
  got="$(web_get /api/settings)" || { echo "读回设置失败：$got"; return 1; }
  jq -e --arg m "$marker" '.settings.theme == $m' <<<"$got" >/dev/null \
    || { echo "theme 不是 $marker：$(head -c 200 <<<"$got")"; return 1; }
}
