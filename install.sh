#!/bin/sh
# 编译安装 picom（meson）
# 默认：ninja install → /usr/local（需 doas/sudo）
# --user：PREFIX=$HOME/.local，不提权
# --config：把 picom.sample.conf 链到 ~/.config/picom/picom.conf（已存在则跳过）
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
MODE=system
DO_CONFIG=0

usage() {
	cat <<'EOF'
用法: ./install.sh [选项]

  （默认）     meson + ninja install → /usr/local（需 doas/sudo）
  --user       PREFIX=$HOME/.local（个人，不提权）
  --config     若无 ~/.config/picom/picom.conf，则链接仓内 picom.sample.conf
  -h, --help   显示本说明

依赖见仓库 README；Arch 示例：
  sudo pacman -S base-devel meson ninja git asciidoc \
    libx11 libxext libxcb xcb-util xcb-util-image xcb-util-renderutil \
    xorgproto pixman libconfig libev uthash libglvnd mesa \
    pcre2 dbus
EOF
}

for arg in "$@"; do
	case "$arg" in
	--user) MODE=user ;;
	--config) DO_CONFIG=1 ;;
	-h|--help) usage; exit 0 ;;
	-*)
		echo "未知选项: $arg（见 ./install.sh --help）" >&2
		exit 1
		;;
	*)
		echo "未知参数: $arg" >&2
		exit 1
		;;
	esac
done

cd "$ROOT"
if [ -f .gitmodules ] && [ -s .gitmodules ]; then
	git submodule update --init --recursive
fi

BUILD="$ROOT/build"
if [ -d "$BUILD" ]; then
	# 已有 build：只重配 prefix 时用 configure；干净重建用 --wipe 需手动
	:
fi

if [ "$MODE" = user ]; then
	PREFIX="${HOME}/.local"
	meson setup --buildtype=release --prefix="$PREFIX" "$BUILD" .
	ninja -C "$BUILD"
	ninja -C "$BUILD" install
	echo "picom → $PREFIX/bin/picom"
else
	meson setup --buildtype=release --prefix=/usr/local "$BUILD" .
	ninja -C "$BUILD"
	if command -v doas >/dev/null 2>&1; then
		doas ninja -C "$BUILD" install
	elif command -v sudo >/dev/null 2>&1; then
		sudo ninja -C "$BUILD" install
	else
		echo "需要 doas 或 sudo 安装到 /usr/local" >&2
		exit 1
	fi
	echo "picom → /usr/local/bin/picom"
fi

if [ "$DO_CONFIG" = 1 ]; then
	conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/picom"
	dest="$conf_dir/picom.conf"
	# 优先仓内 picom.conf，否则 sample
	if [ -f "$ROOT/picom.conf" ]; then
		src="$ROOT/picom.conf"
	else
		src="$ROOT/picom.sample.conf"
	fi
	mkdir -p "$conf_dir"
	if [ -e "$dest" ] || [ -L "$dest" ]; then
		# 若仍链到旧 sample，改为 picom.conf
		if [ -L "$dest" ] && [ -f "$ROOT/picom.conf" ]; then
			cur="$(readlink "$dest" 2>/dev/null || true)"
			case "$cur" in
			*picom.sample.conf)
				ln -sfn "$ROOT/picom.conf" "$dest"
				echo "配置已改链 → $dest"
				;;
			*)
				echo "已有 $dest，跳过 --config"
				;;
			esac
		else
			echo "已有 $dest，跳过 --config"
		fi
	elif [ -f "$src" ]; then
		ln -s "$src" "$dest"
		echo "配置 → $dest"
	else
		echo "缺少 $src" >&2
	fi
fi
