#!/bin/bash

# SwimMP3 for macOS v0.1.0
# 将外接磁盘中的 NCM/FLAC/MP3 整理为兼容性良好的 MP3。

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

VERSION="0.1.0"
VOLUMES_ROOT="${SWIMMP3_VOLUMES_ROOT:-/Volumes}"
BITRATE="192k"
SAMPLE_RATE="44100"

clear 2>/dev/null || true
echo "========================================"
echo "        SwimMP3 for macOS v$VERSION"
echo "========================================"
echo

finish() {
  echo
  read -r -p "按回车键关闭窗口……" _ </dev/tty 2>/dev/null || true
  exit "${1:-0}"
}

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ncmdump >/dev/null 2>&1; then
  echo "首次使用需要安装两个免费转换工具。"
  echo "请打开“终端”，粘贴下面一行并按回车："
  echo
  echo "brew install ffmpeg ncmdump"
  finish 1
fi

volumes_file=$(mktemp "${TMPDIR:-/tmp}/swimmp3-volumes.XXXXXX") || finish 1
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/swimmp3-work.XXXXXX") || finish 1
trap 'rm -f "$volumes_file"; rm -rf "$work_dir"' EXIT INT TERM

find "$VOLUMES_ROOT" -mindepth 1 -maxdepth 1 -type d \
  ! -name 'Macintosh HD' ! -name 'Preboot' ! -name 'Recovery' \
  -print > "$volumes_file" 2>/dev/null

volume_count=$(wc -l < "$volumes_file" | tr -d ' ')
if [ "$volume_count" -eq 0 ]; then
  echo "没有找到外接磁盘。请插入U盘后重新运行。"
  finish 1
fi

echo "请选择要整理的U盘："
index=1
while IFS= read -r volume; do
  echo "  $index. $(basename "$volume")"
  index=$((index + 1))
done < "$volumes_file"
echo
read -r -p "请输入序号并按回车：" choice
case "$choice" in
  ''|*[!0-9]*) echo "输入无效。"; finish 1 ;;
esac
if [ "$choice" -lt 1 ] || [ "$choice" -gt "$volume_count" ]; then
  echo "序号不在列表中。"
  finish 1
fi

USB_PATH=$(sed -n "${choice}p" "$volumes_file")
OUTPUT_DIR="$USB_PATH/MP3"
LOG_FILE="$OUTPUT_DIR/SwimMP3-转换记录.txt"

echo
echo "源位置：$USB_PATH"
echo "输出位置：$OUTPUT_DIR"
echo "格式：MP3 / 192 kbps / 44.1 kHz / 双声道"
echo
echo "请选择源文件处理方式："
echo "  1. 保留源文件（推荐）"
echo "  2. 成功后删除对应的 NCM/FLAC，已有 MP3 移入输出文件夹"
read -r -p "请输入 1 或 2（直接回车选择 1）：" delete_choice
DELETE_SOURCE=0
if [ "${delete_choice:-1}" = "2" ]; then
  DELETE_SOURCE=1
fi

file_list="$work_dir/files.list"
find "$USB_PATH" \
  \( -name '.Spotlight-V100' -o -name '.Trashes' -o -name '.fseventsd' -o -path "$OUTPUT_DIR" \) -prune -o \
  -type f ! -name '._*' \
  \( -iname '*.ncm' -o -iname '*.flac' -o -iname '*.mp3' \) -print0 \
  > "$file_list" 2>/dev/null

total=$(tr -cd '\0' < "$file_list" | wc -c | tr -d ' ')
if [ "$total" -eq 0 ]; then
  echo
  echo "这个U盘中没有找到待处理的 NCM、FLAC 或 MP3。"
  finish 0
fi

echo
echo "找到 $total 个音频文件。"
if [ "$DELETE_SOURCE" -eq 1 ]; then
  read -r -p "警告：成功处理后将删除或移动源文件。输入 DELETE 确认：" confirmation
  if [ "$confirmation" != "DELETE" ]; then
    echo "未确认，操作已取消。"
    finish 0
  fi
else
  read -r -p "源文件会保留。按回车开始，输入 q 取消：" confirmation
  case "$confirmation" in q|Q) finish 0 ;; esac
fi

mkdir -p "$OUTPUT_DIR" || { echo "无法创建输出文件夹。"; finish 1; }
touch "$LOG_FILE" 2>/dev/null || { echo "U盘不可写或空间不足。"; finish 1; }
echo "---- $(date '+%Y-%m-%d %H:%M:%S') 开始 ----" >> "$LOG_FILE"

converted=0
copied=0
skipped=0
failed=0
processed=0

safe_base() {
  printf '%s' "$1" | tr '/:' '__'
}

choose_target() {
  local base="$1" source="$2" candidate number
  candidate="$OUTPUT_DIR/$base.mp3"
  if [ ! -e "$candidate" ]; then
    printf '%s\n' "$candidate"
    return
  fi
  # 同一路径或已有非空结果视为已处理，避免每次运行都产生新副本。
  if [ "$candidate" = "$source" ] || [ -s "$candidate" ]; then
    printf '%s\n' ""
    return
  fi
  number=2
  while [ -e "$OUTPUT_DIR/$base ($number).mp3" ]; do number=$((number + 1)); done
  printf '%s\n' "$OUTPUT_DIR/$base ($number).mp3"
}

record() {
  printf '%s | %s\n' "$1" "$2" >> "$LOG_FILE"
}

while IFS= read -r -d '' source; do
  processed=$((processed + 1))
  filename=$(basename "$source")
  extension=$(printf '%s' "${source##*.}" | tr '[:upper:]' '[:lower:]')
  base=$(safe_base "${filename%.*}")
  target=$(choose_target "$base" "$source")
  echo "[$processed/$total] $filename"

  if [ -z "$target" ]; then
    echo "  已存在，跳过"
    skipped=$((skipped + 1))
    record "跳过" "$source"
    continue
  fi

  if [ "$extension" = "mp3" ]; then
    if [ "$DELETE_SOURCE" -eq 1 ]; then
      action="mv"
    else
      action="cp -p"
    fi
    if $action "$source" "$target"; then
      copied=$((copied + 1)); record "整理成功" "$source -> $target"
    else
      rm -f "$target"; failed=$((failed + 1)); record "整理失败" "$source"
    fi
    continue
  fi

  input="$source"
  if [ "$extension" = "ncm" ]; then
    job_dir=$(mktemp -d "$work_dir/ncm.XXXXXX") || { failed=$((failed + 1)); continue; }
    cp "$source" "$job_dir/$filename" || { failed=$((failed + 1)); record "读取失败" "$source"; continue; }
    if ! (cd "$job_dir" && ncmdump "$filename" >/dev/null 2>&1); then
      echo "  NCM解码失败，源文件已保留"
      failed=$((failed + 1)); record "解码失败" "$source"; continue
    fi
    input=$(find "$job_dir" -maxdepth 1 -type f \
      \( -iname '*.flac' -o -iname '*.mp3' -o -iname '*.wav' -o -iname '*.m4a' \) \
      ! -iname '*.ncm' -print -quit)
    if [ -z "$input" ]; then
      failed=$((failed + 1)); record "未找到解码结果" "$source"; continue
    fi
  fi

  if ffmpeg -nostdin -hide_banner -loglevel error -i "$input" \
      -map_metadata 0 -map 0:a:0 -codec:a libmp3lame -b:a "$BITRATE" \
      -ar "$SAMPLE_RATE" -ac 2 "$target"; then
    converted=$((converted + 1)); record "转换成功" "$source -> $target"
    if [ "$DELETE_SOURCE" -eq 1 ]; then rm -f "$source"; fi
  else
    rm -f "$target"
    echo "  转换失败，源文件已保留"
    failed=$((failed + 1)); record "转换失败" "$source"
  fi
done < "$file_list"

echo "---- $(date '+%Y-%m-%d %H:%M:%S') 完成 ----" >> "$LOG_FILE"
echo
echo "========================================"
echo "处理完成：转换 $converted，整理 $copied，跳过 $skipped，失败 $failed"
echo "音乐位置：$OUTPUT_DIR"
echo "记录文件：$LOG_FILE"
echo "========================================"
echo "请先试听几首，再安全推出U盘。"
finish 0
