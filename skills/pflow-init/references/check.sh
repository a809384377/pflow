#!/usr/bin/env bash
# ai/tech-design/check.sh — 结构真相文件六级校验（红灯阻断，黄灯报告）。
#
# 从项目 Git 根运行：bash ai/tech-design/check.sh
# 脚本也会自行定位 Git 根；真相文档固定读取 ai/tech-design/。
#
# 可选配置：ai/tech-design/check.conf（受信任的 Bash 赋值文件），或用环境变量
# TRUTH_CHECK_CONFIG 指向另一个配置文件（相对路径按 Git 根解析）。可配置项：
#   TRUTH_CHECK_MAX_AGE_DAYS=90
#   TRUTH_CHECK_MAX_LINES=500
#   TRUTH_CHECK_SOURCE_ROOTS="src lib"       # 留空时自动推导，可写嵌套目录
#   TRUTH_CHECK_SOURCE_EXTENSIONS="sh py ts" # 空格分隔，不带点
#   TRUTH_CHECK_EXEMPT_DIRS="tests assets build ..."
#   TRUTH_CHECK_EXEMPT_SUFFIXES=".test.ts .png ..."
# 配置中的列表按空白分隔，因此条目本身不能含空白。目录豁免匹配任意路径段，
# 后缀豁免匹配完整仓库相对路径的末尾。项目配置会覆盖同名默认值；如需在默认
# 清单后追加，可写：TRUTH_CHECK_EXEMPT_DIRS="$TRUTH_CHECK_EXEMPT_DIRS generated"。
#
# 源码路径识别策略：先从 git ls-files 中找出带已配置源码后缀、且未命中豁免的
# 文件，再以它们所在的顶层目录作为源码根；TRUTH_CHECK_SOURCE_ROOTS 可显式覆写。
# 文档正文中，落在这些源码根下的仓库相对路径按源码路径校验；为识别整个旧源码
# 目录已删除/搬移后的死路径，带已配置源码后缀且未命中豁免的路径也会兜底校验。
# frontmatter 的 sources 列表按约定本就只能放源码路径，故不经过根目录推断，全部对
# git ls-files 核实。正文路径支持 Markdown 代码片段/链接中的空格与非 ASCII 字符，
# 并保留普通 ASCII 路径兼容扫描；外部 URL 不参与校验。L2 对当前已跟踪源码快照做
# 全量反向覆盖，不依赖 git diff；文件 rename 后只认新路径，code-map 仍写旧路径会
# 同时触发 L1 红灯和 L2 黄灯。L4 约定 code-map 条目使用带表头分隔线的 Markdown
# 表格，条目名取每个数据行第一列，并与 Mermaid 代码块中的节点标签/隐式节点名比对。
#
# frontmatter 未闭合（缺第二个 ---）时按无 frontmatter 处理、扫描全文并输出一条
# L1 黄灯提示，不静默跳过正文校验。sources 仅支持块状列表写法（`sources:` 单独
# 一行 + 后续 `- ` 条目）；写成行内数组或标量会输出 L1 黄灯「格式无法解析」，不
# 静默忽略。L4 仅比对 flowchart 与 sequenceDiagram 节点名，其余 Mermaid 图类型
# 只识别图头部（避免被误当节点/边解析），节点一致性不参与比对。用 ~~~ 等外层
# 围栏包裹的示范用 mermaid 代码块不参与 L4 比对（同字符同长度的反引号围栏无法
# 安全嵌套，这类写法请改用不同围栏字符包裹）。

set -uo pipefail

PROGRAM_NAME="${0##*/}"

fail_internal() {
  printf 'ERROR %s: %s\n' "$PROGRAM_NAME" "$*" >&2
  exit 2
}

if ! ROOT="$(git rev-parse --show-toplevel)"; then
  fail_internal "当前目录不在 Git 仓库内"
fi
DESIGN_DIR="$ROOT/ai/tech-design"
[ -d "$DESIGN_DIR" ] || fail_internal "缺少 ai/tech-design 目录"
cd "$ROOT" || fail_internal "无法进入 Git 根目录: $ROOT"

TRUTH_CHECK_MAX_AGE_DAYS="${TRUTH_CHECK_MAX_AGE_DAYS-90}"
TRUTH_CHECK_MAX_LINES="${TRUTH_CHECK_MAX_LINES-500}"
TRUTH_CHECK_SOURCE_ROOTS="${TRUTH_CHECK_SOURCE_ROOTS-}"
TRUTH_CHECK_SOURCE_EXTENSIONS="${TRUTH_CHECK_SOURCE_EXTENSIONS-c cc cpp cxx h hh hpp hxx m mm swift go rs java kt kts scala py pyx rb php js jsx mjs cjs ts tsx vue svelte sh bash zsh fish pl pm lua r dart ex exs erl hrl fs fsi fsx cs vb sol proto sql html htm css scss sass less}"
TRUTH_CHECK_EXEMPT_DIRS="${TRUTH_CHECK_EXEMPT_DIRS-test tests __tests__ spec specs fixture fixtures mock mocks snapshot snapshots asset assets static public dist build coverage target out vendor vendors node_modules generated .cache cache tmp temp ai doc docs documentation}"
TRUTH_CHECK_EXEMPT_SUFFIXES="${TRUTH_CHECK_EXEMPT_SUFFIXES-.test.js .test.jsx .test.ts .test.tsx .spec.js .spec.jsx .spec.ts .spec.tsx _test.go _test.py _test.rb Test.java Tests.java .png .jpg .jpeg .gif .webp .svg .ico .pdf .woff .woff2 .ttf .eot .mp3 .wav .mp4 .mov .zip .gz .map .min.js .min.css}"

CONFIG_FILE="${TRUTH_CHECK_CONFIG-$DESIGN_DIR/check.conf}"
case "$CONFIG_FILE" in
  /*) ;;
  *) CONFIG_FILE="$ROOT/$CONFIG_FILE" ;;
esac
if [ -f "$CONFIG_FILE" ]; then
  if ! . "$CONFIG_FILE"; then
    fail_internal "配置文件加载失败: ${CONFIG_FILE#"$ROOT"/}"
  fi
fi

TRUTH_CHECK_MAX_AGE_DAYS="${TRUTH_CHECK_MAX_AGE_DAYS-}"
TRUTH_CHECK_MAX_LINES="${TRUTH_CHECK_MAX_LINES-}"
TRUTH_CHECK_SOURCE_ROOTS="${TRUTH_CHECK_SOURCE_ROOTS-}"
TRUTH_CHECK_SOURCE_EXTENSIONS="${TRUTH_CHECK_SOURCE_EXTENSIONS-}"
TRUTH_CHECK_EXEMPT_DIRS="${TRUTH_CHECK_EXEMPT_DIRS-}"
TRUTH_CHECK_EXEMPT_SUFFIXES="${TRUTH_CHECK_EXEMPT_SUFFIXES-}"

case "$TRUTH_CHECK_MAX_AGE_DAYS" in
  ''|*[!0-9]*) fail_internal "TRUTH_CHECK_MAX_AGE_DAYS 必须是非负整数" ;;
esac
case "$TRUTH_CHECK_MAX_LINES" in
  ''|*[!0-9]*) fail_internal "TRUTH_CHECK_MAX_LINES 必须是非负整数" ;;
esac
[ -n "$TRUTH_CHECK_SOURCE_EXTENSIONS" ] || fail_internal "TRUTH_CHECK_SOURCE_EXTENSIONS 不得为空"

umask 077
TMP_BASE=''
tmp_attempt=0
while [ "$tmp_attempt" -lt 20 ]; do
  tmp_attempt=$((tmp_attempt + 1))
  tmp_candidate="${TMPDIR:-/tmp}/truth-doc-check.$$-${RANDOM:-0}-$tmp_attempt"
  if mkdir "$tmp_candidate"; then
    TMP_BASE=$tmp_candidate
    break
  fi
done
[ -n "$TMP_BASE" ] || fail_internal "无法安全创建临时目录"
cleanup() {
  rm -rf "$TMP_BASE"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

TRACKED_FILE="$TMP_BASE/tracked"
SOURCE_ROOTS_FILE="$TMP_BASE/source-roots"
CODE_MAP_PATHS_FILE="$TMP_BASE/code-map-paths"
CODE_MAP_NAMES_FILE="$TMP_BASE/code-map-names"
MATCHES_FILE="$TMP_BASE/matches"
METADATA_FILE="$TMP_BASE/metadata"
FRONTMATTER_WARNINGS_FILE="$TMP_BASE/frontmatter-warnings"
MERMAID_FILE="$TMP_BASE/mermaid"
DATE_STDOUT_FILE="$TMP_BASE/date-stdout"
DATE_STDERR_FILE="$TMP_BASE/date-stderr"
: > "$SOURCE_ROOTS_FILE"
: > "$CODE_MAP_PATHS_FILE"
: > "$CODE_MAP_NAMES_FILE"

if ! git ls-files -z > "$TRACKED_FILE"; then
  fail_internal "git ls-files 执行失败"
fi

red_count=0
yellow_count=0
l1_checked=0
l2_checked=0
l3_checked=0
l4_checked=0
l5_checked=0
l6_checked=0

report_red() {
  red_count=$((red_count + 1))
  printf '红灯 %s %s:%s → %s\n' "$1" "$2" "$3" "$4"
}

report_yellow() {
  yellow_count=$((yellow_count + 1))
  printf '黄灯 %s %s:%s → %s\n' "$1" "$2" "$3" "$4"
}

file_has_exact_line() {
  grep -Fqx -- "$1" "$2"
  grep_status=$?
  if [ "$grep_status" -eq 0 ]; then
    return 0
  fi
  if [ "$grep_status" -eq 1 ]; then
    return 1
  fi
  fail_internal "grep 读取失败: $2"
}

append_unique_line() {
  if file_has_exact_line "$1" "$2"; then
    return 0
  fi
  printf '%s\n' "$1" >> "$2" || fail_internal "无法写入临时文件: $2"
}

normalize_relative_path() {
  normalized_path=$1
  while [ "${normalized_path#./}" != "$normalized_path" ]; do
    normalized_path=${normalized_path#./}
  done
  while :; do
    case "$normalized_path" in
      *.) normalized_path=${normalized_path%.} ;;
      *) break ;;
    esac
  done
  normalized_path=${normalized_path%/}
  printf '%s\n' "$normalized_path"
}

is_safe_relative_path() {
  case "$1" in
    ''|/*|../*|*/../*|*/..) return 1 ;;
    *) return 0 ;;
  esac
}

tracked_path_exists() {
  tracked_probe=${1%/}
  while IFS= read -r -d '' tracked_entry || [ -n "$tracked_entry" ]; do
    case "$tracked_entry" in
      "$tracked_probe"|"$tracked_probe"/*) return 0 ;;
    esac
  done < "$TRACKED_FILE"
  return 1
}

is_source_extension() {
  source_filename=${1##*/}
  case "$source_filename" in
    *.*) source_extension=${source_filename##*.} ;;
    *) return 1 ;;
  esac
  for configured_extension in $TRUTH_CHECK_SOURCE_EXTENSIONS; do
    if [ "$source_extension" = "$configured_extension" ]; then
      return 0
    fi
  done
  return 1
}

is_exempt_path() {
  exempt_candidate=$1
  exempt_remainder=$exempt_candidate
  while :; do
    case "$exempt_remainder" in
      */*)
        path_component=${exempt_remainder%%/*}
        exempt_remainder=${exempt_remainder#*/}
        ;;
      *)
        path_component=$exempt_remainder
        exempt_remainder=''
        ;;
    esac
    for exempt_directory in $TRUTH_CHECK_EXEMPT_DIRS; do
      if [ "$path_component" = "$exempt_directory" ]; then
        return 0
      fi
    done
    [ -n "$exempt_remainder" ] || break
  done
  for exempt_suffix in $TRUTH_CHECK_EXEMPT_SUFFIXES; do
    case "$exempt_candidate" in
      *"$exempt_suffix") return 0 ;;
    esac
  done
  return 1
}

path_is_under_source_root() {
  candidate_path=$1
  while IFS= read -r configured_root || [ -n "$configured_root" ]; do
    case "$candidate_path" in
      "$configured_root"|"$configured_root"/*) return 0 ;;
    esac
  done < "$SOURCE_ROOTS_FILE"
  return 1
}

path_looks_like_source() {
  if path_is_under_source_root "$1"; then
    return 0
  fi
  if is_source_extension "$1" && ! is_exempt_path "$1"; then
    return 0
  fi
  return 1
}

add_source_root() {
  source_root="$(normalize_relative_path "$1")"
  is_safe_relative_path "$source_root" || fail_internal "非法源码根目录: $1"
  append_unique_line "$source_root" "$SOURCE_ROOTS_FILE"
}

if [ -n "$TRUTH_CHECK_SOURCE_ROOTS" ]; then
  for explicit_root in $TRUTH_CHECK_SOURCE_ROOTS; do
    add_source_root "$explicit_root"
  done
else
  while IFS= read -r -d '' tracked_entry || [ -n "$tracked_entry" ]; do
    case "$tracked_entry" in
      */*) ;;
      *) continue ;;
    esac
    if is_exempt_path "$tracked_entry"; then
      continue
    fi
    if is_source_extension "$tracked_entry"; then
      add_source_root "${tracked_entry%%/*}"
    fi
  done < "$TRACKED_FILE"
fi

extract_document_paths() {
  path_content=$1
  if ! printf '%s\n' "$path_content" | awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function emit(value) {
      value = trim(value)
      if (substr(value, 1, 1) == "<" && substr(value, length(value), 1) == ">") {
        value = substr(value, 2, length(value) - 2)
      }
      sub(/[[:space:]]+"[^"]*"$/, "", value)
      sub(/[?#].*$/, "", value)
      value = trim(value)
      if (value != "" && !seen[value]++) {
        print value
      }
    }
    function emit_code(value, slash_at, prefix) {
      value = trim(value)
      slash_at = index(value, "/")
      if (slash_at == 0) {
        return
      }
      prefix = substr(value, 1, slash_at - 1)
      if (prefix !~ /[[:space:]]/) {
        emit(value)
      }
    }
    {
      line = $0

      rest = line
      while (match(rest, /`[^`]+`/)) {
        emit_code(substr(rest, RSTART + 1, RLENGTH - 2))
        rest = substr(rest, RSTART + RLENGTH)
      }

      rest = line
      while (match(rest, /\]\([^[:space:]]*\)/)) {
        emit(substr(rest, RSTART + 2, RLENGTH - 3))
        rest = substr(rest, RSTART + RLENGTH)
      }

      # 裸文本兜底扫描操作在下面这份被逐步"挖空"的 line 副本上：反引号代码段与
      # Markdown 链接目标已在上面两遍单独扫描中完整提取，这里整段替换成一个空
      # 格，防止兜底扫描重新扫到同一段文本、在空格/括号/非 ASCII 字符处截断，
      # 生成一个文档里根本不存在的残缺路径。
      while (match(line, /`[^`]+`/)) {
        line = substr(line, 1, RSTART - 1) " " substr(line, RSTART + RLENGTH)
      }
      while (match(line, /\]\([^[:space:]]*\)/)) {
        line = substr(line, 1, RSTART - 1) " " substr(line, RSTART + RLENGTH)
      }
      while (match(line, /[A-Za-z][A-Za-z0-9+.-]*:\/\/[^[:space:]<>]+/)) {
        line = substr(line, 1, RSTART - 1) " " substr(line, RSTART + RLENGTH)
      }
      while (match(line, /(\.\/)?[A-Za-z0-9._-]+\/([A-Za-z0-9._-]+\/)*[A-Za-z0-9._-]+/)) {
        emit(substr(line, RSTART, RLENGTH))
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' > "$MATCHES_FILE"; then
    fail_internal "文档路径提取失败"
  fi
}

is_external_reference() {
  case "$1" in
    *://*|mailto:*|data:*) return 0 ;;
    *) return 1 ;;
  esac
}

extract_frontmatter_sources() {
  : > "$FRONTMATTER_WARNINGS_FILE"
  if ! awk -v warn_file="$FRONTMATTER_WARNINGS_FILE" '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    NR == 1 {
      text = $0
      sub(/\r$/, "", text)
      if (text == "---") {
        in_frontmatter = 1
      }
      next
    }
    in_frontmatter {
      text = $0
      sub(/\r$/, "", text)
      if (text == "---") {
        exit
      }
      if (text ~ /^[[:space:]]*sources:[[:space:]]*(#.*)?$/) {
        in_sources = 1
        next
      }
      if (text ~ /^[[:space:]]*sources:[[:space:]]*[^[:space:]#]/) {
        # 块状列表以外的写法（行内数组 sources: [a, b]、标量 sources: a 等）不
        # 被解析；不能静默丢掉这条声明，记一条行号供调用方输出黄灯。
        printf "%d\n", NR > warn_file
        in_sources = 0
        next
      }
      if (in_sources && text ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*:/) {
        in_sources = 0
      }
      if (in_sources && text ~ /^[[:space:]]*-[[:space:]]+/) {
        value = text
        sub(/^[[:space:]]*-[[:space:]]+/, "", value)
        sub(/[[:space:]]+#.*$/, "", value)
        value = trim(value)
        if ((substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") ||
            (substr(value, 1, 1) == "\047" && substr(value, length(value), 1) == "\047")) {
          value = substr(value, 2, length(value) - 2)
        }
        if (value != "") {
          printf "%d\t%s\n", NR, value
        }
      }
    }
  ' "$1" > "$METADATA_FILE"; then
    fail_internal "frontmatter sources 解析失败: ${1#"$ROOT"/}"
  fi
}

detect_frontmatter_state() {
  # 三态：none（不以 --- 开头，没有 frontmatter）/ closed（正常闭合）/
  # unclosed（以 --- 开头但直到文件结束都没有第二个 ---）。调用方据此决定要不
  # 要在正文扫描里跳过"frontmatter 区间"——unclosed 时绝不能跳过，否则整份
  # 正文（包括其中的死链接）会被当成 frontmatter 静默吞掉，见 L1 阻断项。
  if ! awk '
    NR == 1 {
      text = $0
      sub(/\r$/, "", text)
      if (text == "---") {
        state = "open"
      } else {
        state = "none"
      }
      next
    }
    state == "open" {
      text = $0
      sub(/\r$/, "", text)
      if (text == "---") {
        state = "closed"
        exit
      }
    }
    END {
      if (state == "open") { state = "unclosed" }
      if (state == "") { state = "none" }
      print state
    }
  ' "$1"; then
    return 1
  fi
}

scan_design_document_l1() {
  document_path=$1
  document_relative=${document_path#"$ROOT"/}
  collect_code_map=$2

  frontmatter_state="$(detect_frontmatter_state "$document_path")" || fail_internal "frontmatter 状态探测失败: $document_relative"

  if [ "$frontmatter_state" = "unclosed" ]; then
    report_yellow L1 "$document_relative" 1 "frontmatter 未闭合（缺少第二个 ---），已按无 frontmatter 处理并扫描全文"
  fi

  if [ "$frontmatter_state" = "closed" ]; then
    extract_frontmatter_sources "$document_path"
    while IFS= read -r warn_line || [ -n "$warn_line" ]; do
      [ -n "$warn_line" ] || continue
      report_yellow L1 "$document_relative" "$warn_line" "sources 格式无法解析（不是块状列表写法，如行内数组或标量），未参与 L1 校验"
    done < "$FRONTMATTER_WARNINGS_FILE"
    while IFS="$(printf '\t')" read -r source_line declared_source || [ -n "${source_line}${declared_source}" ]; do
      [ -n "$declared_source" ] || continue
      declared_source="$(normalize_relative_path "$declared_source")"
      l1_checked=$((l1_checked + 1))
      if ! is_safe_relative_path "$declared_source"; then
        report_red L1 "$document_relative" "$source_line" "sources 含非法仓库相对路径: $declared_source"
      elif ! tracked_path_exists "$declared_source"; then
        report_red L1 "$document_relative" "$source_line" "源码路径未被 Git 跟踪: $declared_source"
      fi
    done < "$METADATA_FILE"
  fi

  line_number=0
  in_frontmatter=0
  while IFS= read -r document_line || [ -n "$document_line" ]; do
    line_number=$((line_number + 1))
    clean_line=${document_line%$'\r'}
    if [ "$frontmatter_state" = "closed" ] && [ "$line_number" -eq 1 ] && [ "$clean_line" = "---" ]; then
      in_frontmatter=1
      continue
    fi
    if [ "$in_frontmatter" -eq 1 ]; then
      if [ "$clean_line" = "---" ]; then
        in_frontmatter=0
      fi
      continue
    fi

    extract_document_paths "$document_line"
    while IFS= read -r raw_path || [ -n "$raw_path" ]; do
      if is_external_reference "$raw_path"; then
        continue
      fi
      source_path="$(normalize_relative_path "$raw_path")"
      if ! path_looks_like_source "$source_path"; then
        continue
      fi
      l1_checked=$((l1_checked + 1))
      if ! is_safe_relative_path "$source_path"; then
        report_red L1 "$document_relative" "$line_number" "非法仓库相对源码路径: $source_path"
        continue
      fi
      if [ "$collect_code_map" -eq 1 ]; then
        append_unique_line "$source_path" "$CODE_MAP_PATHS_FILE"
      fi
      if ! tracked_path_exists "$source_path"; then
        report_red L1 "$document_relative" "$line_number" "源码路径未被 Git 跟踪: $source_path"
      fi
    done < "$MATCHES_FILE"
  done < "$document_path"
}

CODE_MAP_FILE="$DESIGN_DIR/code-map.md"
for design_document in "$DESIGN_DIR"/*.md; do
  [ -f "$design_document" ] || continue
  if [ "$design_document" = "$CODE_MAP_FILE" ]; then
    scan_design_document_l1 "$design_document" 1
  else
    scan_design_document_l1 "$design_document" 0
  fi
done

if [ ! -s "$SOURCE_ROOTS_FILE" ]; then
  report_yellow L2 ai/tech-design/code-map.md 1 "未识别到源码根目录；请检查源码后缀或配置 TRUTH_CHECK_SOURCE_ROOTS"
else
  SOURCE_ROOTS_SEEN_FILE="$TMP_BASE/source-roots-seen"
  : > "$SOURCE_ROOTS_SEEN_FILE"
  while IFS= read -r -d '' tracked_entry || [ -n "$tracked_entry" ]; do
    if ! path_is_under_source_root "$tracked_entry"; then
      continue
    fi
    if is_exempt_path "$tracked_entry"; then
      continue
    fi
    if ! is_source_extension "$tracked_entry"; then
      continue
    fi
    l2_checked=$((l2_checked + 1))
    while IFS= read -r configured_root || [ -n "$configured_root" ]; do
      case "$tracked_entry" in
        "$configured_root"|"$configured_root"/*) append_unique_line "$configured_root" "$SOURCE_ROOTS_SEEN_FILE" ;;
      esac
    done < "$SOURCE_ROOTS_FILE"
    if ! file_has_exact_line "$tracked_entry" "$CODE_MAP_PATHS_FILE"; then
      report_yellow L2 "$tracked_entry" 1 "源码文件未登记到 ai/tech-design/code-map.md"
    fi
  done < "$TRACKED_FILE"
  while IFS= read -r configured_root || [ -n "$configured_root" ]; do
    if ! file_has_exact_line "$configured_root" "$SOURCE_ROOTS_SEEN_FILE"; then
      report_yellow L2 ai/tech-design/code-map.md 1 "源码根下未识别到源码文件: $configured_root"
    fi
  done < "$SOURCE_ROOTS_FILE"
fi

scan_pointer_document_l3() {
  pointer_document=$1
  pointer_relative=${pointer_document#"$ROOT"/}
  pointer_line_number=0
  while IFS= read -r pointer_line || [ -n "$pointer_line" ]; do
    pointer_line_number=$((pointer_line_number + 1))
    extract_document_paths "$pointer_line"
    while IFS= read -r raw_pointer || [ -n "$raw_pointer" ]; do
      if is_external_reference "$raw_pointer"; then
        continue
      fi
      pointer_path="$(normalize_relative_path "$raw_pointer")"
      case "$pointer_path" in
        ai/*) ;;
        *) continue ;;
      esac
      l3_checked=$((l3_checked + 1))
      if ! is_safe_relative_path "$pointer_path"; then
        report_red L3 "$pointer_relative" "$pointer_line_number" "非法 ai/ 文件指针: $pointer_path"
      elif [ ! -e "$ROOT/$pointer_path" ]; then
        report_red L3 "$pointer_relative" "$pointer_line_number" "ai/ 文件指针不存在: $pointer_path"
      fi
    done < "$MATCHES_FILE"
  done < "$pointer_document"
}

for pointer_document in "$ROOT/ai/ROADMAP.md" "$ROOT/ai/KNOWLEDGE.md" "$ROOT"/ai/specs/*.md; do
  [ -f "$pointer_document" ] || continue
  scan_pointer_document_l3 "$pointer_document"
done

if [ -f "$CODE_MAP_FILE" ]; then
  if ! awk '
    function clean_name(value, close_at) {
      sub(/\r$/, "", value)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      close_at = index(value, "](")
      if (substr(value, 1, 1) == "[" && close_at > 0) {
        value = substr(value, 2, close_at - 2)
      }
      gsub(/`/, "", value)
      gsub(/\*\*/, "", value)
      gsub(/"/, "", value)
      gsub(/[[:space:]]+/, " ", value)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    /^[[:space:]]*\|/ {
      compact = $0
      gsub(/[|:[:space:]-]/, "", compact)
      if (compact == "") {
        in_table = 1
        next
      }
      if (in_table) {
        split($0, fields, "|")
        name = clean_name(fields[2])
        if (name != "") {
          print name
        }
      }
      next
    }
    { in_table = 0 }
  ' "$CODE_MAP_FILE" > "$CODE_MAP_NAMES_FILE"; then
    fail_internal "code-map 条目解析失败"
  fi
fi

extract_mermaid_nodes() {
  if ! awk '
    function clean_label(value) {
      gsub(/<[bB][rR][^>]*>/, " ", value)
      gsub(/<[^>]*>/, "", value)
      gsub(/`/, "", value)
      gsub(/\*\*/, "", value)
      gsub(/"/, "", value)
      gsub(/[\[\](){}]/, "", value)
      gsub(/[[:space:]]+/, " ", value)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function emit_implicit(segment, value) {
      gsub(/\|[^|]*\|/, " ", segment)
      sub(/^[[:space:]]+/, "", segment)
      sub(/[[:space:]]+$/, "", segment)
      if (segment ~ /[\[\](){}]/) {
        return
      }
      sub(/:::[A-Za-z_][A-Za-z0-9_-]*$/, "", segment)
      value = segment
      sub(/[^A-Za-z0-9_-].*$/, "", value)
      if (value ~ /^[A-Za-z_][A-Za-z0-9_-]*$/) {
        printf "%d\t%s\n", NR, value
      }
    }
    # 外层围栏（如 ~~~ 包裹）内的内容整段跳过，包括其中出现的字面 ```mermaid：
    # 这类写法通常是文档里"如何画图"的示范文本，不是真实要比对的图。反引号围栏
    # 无法安全嵌套同字符同长度的围栏，这里只识别 ~~~ 这种不与 ``` 冲突的外层
    # 包裹写法；组内出现的 ~~~ 边线语法（flowchart 的隐形连线）只在 in_mermaid
    # 为真时才会走到内容解析分支，不会被误当外层围栏。
    outer_fence && /^[[:space:]]*~~~/ {
      outer_fence = 0
      next
    }
    outer_fence { next }
    !in_mermaid && /^[[:space:]]*~~~/ {
      outer_fence = 1
      next
    }
    /^[[:space:]]*```[[:space:]]*mermaid[[:space:]]*$/ {
      in_mermaid = 1
      biz_skip = 0
      next
    }
    in_mermaid && /^[[:space:]]*```/ {
      in_mermaid = 0
      biz_skip = 0
      next
    }
    !in_mermaid { next }
    # 业务视角图：图内标记注释「%% 业务视角」声明节点用业务语言、不与 code-map
    # 比对（规范见 truth-doc-guidelines.md §5 业务视角图），该图整块跳过 L4 解析。
    /^[[:space:]]*%%[[:space:]]*业务视角/ {
      biz_skip = 1
      next
    }
    biz_skip { next }
    {
      line = $0
      sub(/[[:space:]]*%%.*$/, "", line)
      # L4 仅真正比对 flowchart/graph 与 sequenceDiagram 的节点名；下面这份类型
      # 清单只是识别"这是图头部声明行，别把它当节点/边解析"，不代表该类型的节
      # 点/关系语法会被比对——classDiagram 的 <|--、*-- 等关系符号和成员声明、
      # erDiagram/journey/gantt/pie/mindmap/timeline 各自的专用语法均不被解析，
      # 因此不出现在这份清单里，交由下面的通用规则按普通文本处理（不产生比对）。
      if (line ~ /^[[:space:]]*(flowchart|graph|sequenceDiagram|stateDiagram)([[:space:]]|$)/) {
        next
      }
      if (line ~ /^[[:space:]]*(subgraph|end|classDef|class|style|linkStyle|click)([[:space:]]|$)/) {
        next
      }

      macro_rest = line
      macro_found = 0
      while (match(macro_rest, /(Person|Person_Ext|System|System_Ext|SystemDb|Container|Container_Ext|ContainerDb|Component|Component_Ext|ComponentDb|Boundary|Relationship)[[:space:]]*\([^,]+,[[:space:]]*"[^"]+"/)) {
        token = substr(macro_rest, RSTART, RLENGTH)
        sub(/^[^,]+,[[:space:]]*"/, "", token)
        sub(/".*$/, "", token)
        token = clean_label(token)
        if (token != "") {
          printf "%d\t%s\n", NR, token
        }
        macro_rest = substr(macro_rest, RSTART + RLENGTH)
        macro_found = 1
      }
      if (macro_found) {
        next
      }

      if (line ~ /^[[:space:]]*(participant|actor)[[:space:]]+/) {
        label = line
        if (label ~ /[[:space:]]+as[[:space:]]+/) {
          sub(/^.*[[:space:]]+as[[:space:]]+/, "", label)
        } else {
          sub(/^[[:space:]]*(participant|actor)[[:space:]]+/, "", label)
        }
        label = clean_label(label)
        if (label != "") {
          printf "%d\t%s\n", NR, label
        }
        next
      }

      if (line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*(-*>>?|--x|--)[+*-]?[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*:/) {
        message = line
        sub(/^[[:space:]]*/, "", message)
        sender = message
        sub(/[[:space:]]*(-*>>?|--x|--).*$/, "", sender)
        receiver = message
        sub(/^[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*(-*>>?|--x|--)[+*-]?[[:space:]]*/, "", receiver)
        sub(/[[:space:]]*:.*$/, "", receiver)
        if (sender != "") {
          printf "%d\t%s\n", NR, sender
        }
        if (receiver != "") {
          printf "%d\t%s\n", NR, receiver
        }
        next
      }

      if (line ~ /^[[:space:]]*state[[:space:]]+"[^"]+"[[:space:]]+as[[:space:]]+/) {
        label = line
        sub(/^[[:space:]]*state[[:space:]]+"/, "", label)
        sub(/"[[:space:]]+as[[:space:]].*$/, "", label)
        label = clean_label(label)
        if (label != "") {
          printf "%d\t%s\n", NR, label
        }
        next
      }

      node_rest = line
      while (match(node_rest, /[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*(\[[^][]+\]|\([^()]+\)|\{[^{}]+\})/)) {
        token = substr(node_rest, RSTART, RLENGTH)
        sub(/^[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*/, "", token)
        token = clean_label(token)
        if (token != "") {
          printf "%d\t%s\n", NR, token
        }
        node_rest = substr(node_rest, RSTART + RLENGTH)
      }

      edge_line = line
      gsub(/<-->|-->|---|-\.-?>|==>|~~~|--x|--o/, "\t", edge_line)
      if (index(edge_line, "\t") > 0) {
        edge_count = split(edge_line, edge_parts, "\t")
        for (edge_index = 1; edge_index <= edge_count; edge_index++) {
          emit_implicit(edge_parts[edge_index])
        }
      }
    }
  ' "$1" > "$MERMAID_FILE"; then
    fail_internal "Mermaid 节点解析失败: ${1#"$ROOT"/}"
  fi
}

for design_document in "$DESIGN_DIR"/*.md; do
  [ -f "$design_document" ] || continue
  design_relative=${design_document#"$ROOT"/}
  extract_mermaid_nodes "$design_document"
  while IFS="$(printf '\t')" read -r mermaid_line mermaid_name || [ -n "${mermaid_line}${mermaid_name}" ]; do
    [ -n "$mermaid_name" ] || continue
    l4_checked=$((l4_checked + 1))
    if ! file_has_exact_line "$mermaid_name" "$CODE_MAP_NAMES_FILE"; then
      report_yellow L4 "$design_relative" "$mermaid_line" "Mermaid 节点未匹配 code-map 条目名: $mermaid_name"
    fi
  done < "$MERMAID_FILE"
done

if date -u -d '1970-01-02' '+%s' > "$DATE_STDOUT_FILE" 2> "$DATE_STDERR_FILE"; then
  DATE_STYLE=gnu
elif date -j -u -f '%Y-%m-%d' '1970-01-02' '+%s' > "$DATE_STDOUT_FILE" 2> "$DATE_STDERR_FILE"; then
  DATE_STYLE=bsd
else
  fail_internal "当前 date 不支持 GNU -d 或 BSD -j -f 日期解析"
fi
if ! NOW_EPOCH="$(date -u '+%s')"; then
  fail_internal "无法读取当前时间"
fi

parse_review_date() {
  review_value=$1
  case "$review_value" in
    ????-??-??) ;;
    *) return 1 ;;
  esac
  review_year=${review_value%%-*}
  review_tail=${review_value#*-}
  review_month=${review_tail%%-*}
  review_day=${review_tail##*-}
  case "${review_year}${review_month}${review_day}" in
    *[!0-9]*) return 1 ;;
  esac
  if [ "$DATE_STYLE" = gnu ]; then
    date -u -d "$review_value" '+%s' > "$DATE_STDOUT_FILE" 2> "$DATE_STDERR_FILE" || return 1
  else
    date -j -u -f '%Y-%m-%d' "$review_value" '+%s' > "$DATE_STDOUT_FILE" 2> "$DATE_STDERR_FILE" || return 1
  fi
  review_epoch=$(awk 'NR == 1 { print; exit }' "$DATE_STDOUT_FILE") || return 1
  case "$review_epoch" in
    ''|*[!0-9-]*) return 1 ;;
  esac
  printf '%s\n' "$review_epoch"
}

extract_last_reviewed() {
  if ! awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    NR == 1 {
      text = $0
      sub(/\r$/, "", text)
      if (text == "---") {
        in_frontmatter = 1
      }
      next
    }
    in_frontmatter {
      text = $0
      sub(/\r$/, "", text)
      if (text == "---") {
        exit
      }
      if (text ~ /^[[:space:]]*last_reviewed[[:space:]]*:/) {
        value = text
        sub(/^[[:space:]]*last_reviewed[[:space:]]*:[[:space:]]*/, "", value)
        sub(/[[:space:]]+#.*$/, "", value)
        value = trim(value)
        if ((substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") ||
            (substr(value, 1, 1) == "\047" && substr(value, length(value), 1) == "\047")) {
          value = substr(value, 2, length(value) - 2)
        }
        printf "%d\t%s\n", NR, value
        exit
      }
    }
  ' "$1" > "$METADATA_FILE"; then
    fail_internal "last_reviewed 解析失败: ${1#"$ROOT"/}"
  fi
}

for mechanism_document in "$DESIGN_DIR"/*.md; do
  [ -f "$mechanism_document" ] || continue
  mechanism_basename=${mechanism_document##*/}
  case "$mechanism_basename" in
    README.md|code-map.md) continue ;;
  esac
  mechanism_relative=${mechanism_document#"$ROOT"/}

  l5_checked=$((l5_checked + 1))
  extract_last_reviewed "$mechanism_document"
  review_line=''
  review_date=''
  if IFS="$(printf '\t')" read -r review_line review_date < "$METADATA_FILE" && [ -n "$review_line" ]; then
    if review_epoch="$(parse_review_date "$review_date")"; then
      age_seconds=$((NOW_EPOCH - review_epoch))
      max_age_seconds=$((TRUTH_CHECK_MAX_AGE_DAYS * 86400))
      if [ "$age_seconds" -lt 0 ]; then
        report_yellow L5 "$mechanism_relative" "$review_line" "last_reviewed 位于未来: $review_date"
      elif [ "$age_seconds" -gt "$max_age_seconds" ]; then
        age_days=$((age_seconds / 86400))
        report_yellow L5 "$mechanism_relative" "$review_line" "last_reviewed 已过期 ${age_days} 天（阈值 ${TRUTH_CHECK_MAX_AGE_DAYS} 天）"
      fi
    else
      report_yellow L5 "$mechanism_relative" "$review_line" "last_reviewed 不是有效的 YYYY-MM-DD 日期: $review_date"
    fi
  else
    report_yellow L5 "$mechanism_relative" 1 "缺少 frontmatter last_reviewed"
  fi

  l6_checked=$((l6_checked + 1))
  if ! document_lines="$(awk 'END { print NR + 0 }' "$mechanism_document")"; then
    fail_internal "无法统计文档行数: $mechanism_relative"
  fi
  if [ "$document_lines" -gt "$TRUTH_CHECK_MAX_LINES" ]; then
    report_yellow L6 "$mechanism_relative" 1 "机制文档共 ${document_lines} 行，超过 ${TRUTH_CHECK_MAX_LINES} 行阈值，请拆分或提炼"
  fi
done

printf '%s\n' '---'
printf '校验完成：红灯 %d，黄灯 %d。L1 路径 %d；L2 源码 %d；L3 指针 %d；L4 节点 %d；L5 新鲜度 %d；L6 体积 %d。\n' \
  "$red_count" "$yellow_count" "$l1_checked" "$l2_checked" "$l3_checked" "$l4_checked" "$l5_checked" "$l6_checked"
if [ "$red_count" -gt 0 ]; then
  printf '%s\n' 'FAIL · 存在红灯问题，请修复后重试。'
  exit 1
fi
if [ "$yellow_count" -gt 0 ]; then
  printf '%s\n' 'WARN · 无红灯；黄灯仅报告，不影响退出码。'
  exit 0
fi
printf '%s\n' 'OK · 六级校验全部通过。'
exit 0
