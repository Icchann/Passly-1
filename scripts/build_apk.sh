#!/usr/bin/env bash
# ==============================================================================
# Passly イベント配布用 Android APK ビルドスクリプト
#
# 【概要】
# 本スクリプトは、PasslyのAndroid APK（通常版およびデモ版）をチーム開発環境で
# 安全・確実に再現性高くビルドするためのスクリプトです。
#
# 【チーム開発・環境保護ポリシー】
# - 内部パッケージの更新・変更を防止するため、flutter build には --no-pub を付与します。
# - ビルド成果物は build/outputs/apk/ に整理され、SHA256ハッシュを記録します。
#
# 【使用方法】
#   ./scripts/build_apk.sh [options]
#
# 【オプション】
#   --demo          : デモモード（サーバー通信なし、ダミーデータ動作）でビルド
#   --all           : 通常版とデモ版の両方を連続ビルド
#   --debug         : デバッグビルド（開発・ログ確認用）
#   --help          : 使用方法の表示
# ==============================================================================

set -euo pipefail

# プロジェクトルートディレクトリの取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

# ------------------------------------------------------------------------------
# JDK環境の自動検出と設定
# Android Gradle Plugin 8.x との完全な互換性のため、Java 17 または 21 を優先します
# ------------------------------------------------------------------------------
detect_java_home() {
    if [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
        export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
        export PATH="${JAVA_HOME}/bin:${PATH}"
    elif command -v /usr/libexec/java_home >/dev/null 2>&1; then
        local jdk21
        jdk21="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"
        if [ -n "${jdk21}" ] && [ -d "${jdk21}" ]; then
            export JAVA_HOME="${jdk21}"
            export PATH="${JAVA_HOME}/bin:${PATH}"
        else
            local jdk17
            jdk17="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
            if [ -n "${jdk17}" ] && [ -d "${jdk17}" ]; then
                export JAVA_HOME="${jdk17}"
                export PATH="${JAVA_HOME}/bin:${PATH}"
            fi
        fi
    fi
}
detect_java_home

# 出力先ディレクトリ
OUTPUT_DIR="${PROJECT_ROOT}/build/outputs/apk"

# オプション初期値
BUILD_TYPE="release"
BUILD_MODE="normal" # "normal", "demo", "all"

# ヘルプ表示
show_help() {
    cat << 'EOF'
使用方法: ./scripts/build_apk.sh [オプション]

オプション:
  --release       リリースビルドを実行（デフォルト）
  --debug         デバッグビルドを実行
  --demo          デモモード（DEMO_MODE=true）でビルド
  --all           通常版とデモ版の両方をビルド
  -h, --help      このヘルプを表示

例:
  ./scripts/build_apk.sh --all            # イベント用に通常版とデモ版の両方をビルド
  ./scripts/build_apk.sh --demo           # デモ版のみビルド
EOF
}

# 引数解析
while [[ $# -gt 0 ]]; do
    case "$1" in
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        --debug)
            BUILD_TYPE="debug"
            shift
            ;;
        --demo)
            BUILD_MODE="demo"
            shift
            ;;
        --all)
            BUILD_MODE="all"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "エラー: 未知のオプション '$1'"
            show_help
            exit 1
            ;;
    esac
done

# ビルド実行関数
# 引数1: モード名称 ("normal" または "demo")
build_single_apk() {
    local mode="$1"
    local define_flag=""
    local suffix=""

    if [ "${mode}" = "demo" ]; then
        define_flag="--dart-define=DEMO_MODE=true"
        suffix="demo-"
        echo "=================================================="
        echo "【デモ版】Android APK ビルドを開始します..."
        echo "モード: ${BUILD_TYPE} (DEMO_MODE=true)"
        echo "=================================================="
    else
        suffix="production-"
        echo "=================================================="
        echo "【通常版】Android APK ビルドを開始します..."
        echo "モード: ${BUILD_TYPE} (サーバー通信連携)"
        echo "=================================================="
    fi

    # Flutter ビルドの実行
    # ※ チーム環境保護のため --no-pub を指定して依存パッケージ変更を防止
    if [ -n "${define_flag}" ]; then
        flutter build apk "--${BUILD_TYPE}" --no-pub "${define_flag}"
    else
        flutter build apk "--${BUILD_TYPE}" --no-pub
    fi

    # ビルド成果物の確認とコピー
    local src_apk=""
    if [ "${BUILD_TYPE}" = "release" ]; then
        src_apk="${PROJECT_ROOT}/build/app/outputs/flutter-apk/app-release.apk"
    else
        src_apk="${PROJECT_ROOT}/build/app/outputs/flutter-apk/app-debug.apk"
    fi

    if [ ! -f "${src_apk}" ]; then
        echo "エラー: ビルド成果物が見つかりません: ${src_apk}"
        exit 1
    fi

    mkdir -p "${OUTPUT_DIR}"
    local date_str
    date_str="$(date +%Y%m%d_%H%M%S)"
    local dest_apk="${OUTPUT_DIR}/passly-${suffix}${BUILD_TYPE}-${date_str}.apk"
    local latest_apk="${OUTPUT_DIR}/passly-${suffix}${BUILD_TYPE}-latest.apk"

    cp "${src_apk}" "${dest_apk}"
    cp "${src_apk}" "${latest_apk}"

    # SHA256チェックサムの生成
    local sha256_val
    sha256_val="$(shasum -a 256 "${latest_apk}" | awk '{print $1}')"
    echo "${sha256_val}  $(basename "${latest_apk}")" > "${latest_apk}.sha256"

    echo ""
    echo "ビルドが正常に完了しました。"
    echo "出力先: ${dest_apk}"
    echo "最新リンク: ${latest_apk}"
    echo "SHA256: ${sha256_val}"
    echo ""
}

# メイン処理
mkdir -p "${OUTPUT_DIR}"

if [ "${BUILD_MODE}" = "all" ]; then
    build_single_apk "normal"
    build_single_apk "demo"
else
    build_single_apk "${BUILD_MODE}"
fi

echo "=================================================="
echo "すべてのAPKビルド処理が完了しました。"
echo "成果物ディレクトリ: ${OUTPUT_DIR}"
echo "=================================================="
