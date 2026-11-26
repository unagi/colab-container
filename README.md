# colab-container (NVIDIA RTX Spark / ARM64)

Windows 11 on ARM + WSL2 + Docker Desktop 環境で、**NVIDIA RTX Spark (N1X / Blackwell `sm_121` / ARM64)** の GPU リソースを Google Colab のローカルランタイムから安全に利用するための Docker コンテナ環境です。

Google Colab 公式コンテナ（`us-docker.pkg.dev/colab-images/public/runtime`）は `linux/amd64` 専用のため ARM64 ではネイティブ動作しません。本リポジトリは NVIDIA 公式の ARM64 対応 NGC PyTorch コンテナをベースに、Colab 公式コンテナの主要な設定・拡張機能を再現し、WSL2 ホスト環境を汚さずに利用できるようにしています。

---

## 主な特徴

- **ARM64 / Blackwell (`sm_121`) / CUDA 13.5 ネイティブ対応**: `nvcr.io/nvidia/pytorch:26.11-py3` ベースで GPU パススルーおよび高速演算に対応
- **Google Colab 公式コンテナ準拠の使い勝手**:
  - `google.colab` および `google.colab._serverextension` を組み込み済み（Colab 画面右上の **RAM / Disk / GPU リソースモニタ**対応）
  - デフォルト作業ディレクトリを公式と同じ `/content` に統一（ホスト側 `./workspace` をマウント）
  - `ColabKernelApp`（ZMQ iopub HWM=0）・`iopub_data_rate_limit=1e10`・`matplotlib inline`・`debugpy`・`ipywidgets` / `anywidget` を構成済み
  - `https://colab.research.google.com` からの CORS および Private Network Access (PNA) に対応
- **NVIDIA 最適化ビルドの保護**:
  - ビルド時に `torch` / `torchvision` / `numpy` 等のバージョンを `/etc/pip/constraint.txt`（および `UV_CONSTRAINT`）に固定
  - ノートブック上で `!pip install` や `!uv pip install` を実行しても、誤って PyPI 版で NVIDIA 最適化 `torch` が上書き破壊されるのを防止
- **永続化 & セキュリティ**:
  - 作業ファイル（`./workspace:/content`）および Hugging Face / PyTorch / pip キャッシュをボリューム永続化
  - ポートは `127.0.0.1` のみに限定バインドし、起動ごとにランダムな認証トークンを発行（任意で固定も可能）

---

## 前提条件・動作確認済み環境

### 前提条件
- **ホスト環境**: Windows 11 on ARM + NVIDIA RTX Spark (N1X) 対応ドライバ
- **Docker Desktop for Windows**: インストール済み、かつ **Settings → Resources → WSL Integration** で対象の WSL2 ディストリビューション（Ubuntu 等）を有効化済み
- WSL2 上で以下が動作すること:
  ```bash
  nvidia-smi
  docker version
  ```
  > ※ `docker` 実行時に `permission denied ... /var/run/docker.sock` が出る場合は、WSL2 ターミナルを再起動するか `newgrp docker` を実行してください。

### 動作確認済み環境
- **GPU**: NVIDIA RTX Spark N1X (Blackwell / Compute Capability `12.1` / `sm_121`)
- **ドライバ / CUDA**: NVIDIA Driver `620.x` / CUDA `13.5`
- **OS / Docker**: Windows 11 on ARM + WSL2 Ubuntu 24.04 (`aarch64`) + Docker Desktop `4.100.x`

> **他バージョン環境での利用**: デフォルトの `BASE_IMAGE`（`nvcr.io/nvidia/pytorch:26.11-py3`）は CUDA 13.5 ベースです。ホスト側ドライバが旧バージョンの場合は、`.env` で `BASE_IMAGE` を対応する `nvcr.io/nvidia/pytorch:26.xx-py3` または `25.xx-py3` タグへ変更してビルドしてください。

---

## クイックスタート

### 1. ビルド & 起動

```bash
make up
```
（`make` を使わない場合: `mkdir -p workspace && docker compose up -d --build`）

起動が完了すると、以下のような接続用 URL が表示されます。

```text
http://127.0.0.1:9000/?token=<ランダムトークン>
```

後から URL を再確認したい場合:

```bash
make url
```

### 2. Google Colab から接続

1. ブラウザで [Google Colab](https://colab.research.google.com/) を開く
2. 画面右上の **「接続 ▼」→「ローカル ランタイムに接続」** をクリック
3. 先ほど表示された **URL（`?token=...` を含む全文）** を貼り付けて **「接続」**

### 3. 動作確認（セルフチェック）

コンテナ内部から GPU・CUDA (`sm_121`)・制約ファイル・`google.colab` 拡張を一括検証できます。

```bash
make check
```

---

## よく使うコマンド

| コマンド | 内容 |
|---|---|
| `make up` | イメージをビルドしてバックグラウンド起動し、接続 URL を表示 |
| `make url` | 現在の接続 URL を表示 |
| `make check` | GPU / PyTorch / `google.colab` 拡張のセルフチェックを実行 |
| `make logs` | コンテナのログをリアルタイム表示 |
| `make shell` | 稼働中コンテナ内で `bash` を開く |
| `make restart` | コンテナを再起動（`COLAB_TOKEN` 未設定時はトークン再生成） |
| `make down` | コンテナを停止・削除（`./workspace` とキャッシュボリュームは保持） |
| `make build` | イメージのみ再ビルド |
| `make clean` | コンテナとローカルビルド済みイメージを削除 |

---

## カスタマイズ（`.env`）

必要に応じて `.env.example` を `.env` にコピーして設定を変更できます。

```bash
cp .env.example .env
```

| 環境変数 | デフォルト | 説明 |
|---|---|---|
| `COLAB_PORT` | `9000` | ホスト側（`127.0.0.1`）に公開するポート番号 |
| `COLAB_TOKEN` | *(空 = 毎回ランダム生成)* | 固定トークンを使いたい場合に指定 |
| `COLAB_WORKSPACE` | `./workspace` | コンテナ内 `/content` にマウントするホスト側ディレクトリ |
| `BASE_IMAGE` | `nvcr.io/nvidia/pytorch:26.11-py3` | ベースとする NVIDIA NGC PyTorch イメージ |
| `TZ` | `Asia/Tokyo` | コンテナ内タイムゾーン |

---

## ノートブック内でのパッケージ追加

コンテナ内には `pip` に加えて高速な `uv` も導入済みです。`/etc/pip/constraint.txt` で `torch` / `torchvision` / `numpy` 等の NVIDIA 最適化ビルドが保護されているため、ノートブック上から通常の Colab 感覚で追加できます。

```python
!uv pip install transformers accelerate
# または
!pip install transformers accelerate
```

※ コンテナ再作成後も維持したい常用パッケージが増えてきた場合は、[Dockerfile](Dockerfile) のパッケージ一覧へ追記して `make up` で再ビルドしてください。

---

## WSL2 メモリ上限のチューニング（任意）

RTX Spark の大容量ユニファイドメモリを活かして大規模モデルを扱う場合、WSL2 のデフォルトのシステム RAM 上限がボトルネックになることがあります。必要に応じて Windows 側の `C:\Users\<ユーザー名>\.wslconfig` でメモリ上限を調整してください（変更後は PowerShell で `wsl --shutdown` が必要です）。

```ini
[wsl2]
memory=64GB
swap=16GB
```

---

## Colab 公式コンテナとの差分・注意事項

### 主な差分
- **ベース構成**: PyTorch（NGC `26.11-py3`, Python 3.12, CUDA 13.5）ベース。TensorFlow / JAX / RAPIDS / R / Julia / Spark / GCP SDK は Ph.1 では含めていません。
- **Google Drive マウント (`google.colab.drive`)**: クラウド専用機能のため利用できません。代わりにホスト側 `./workspace` が `/content` に直接マウントされているため、ローカルファイルをそのまま読み書きできます。
- **Colab 独自 LSP バイナリ (`language_service` / `kernel_manager_proxy`)**: 公式コンテナに含まれる `x86_64` 専用バイナリは ARM64 版が非公開のため非搭載です（Jupyter 標準の補完・実行・リソースモニタは動作します）。

### セキュリティ上の注意
ローカルランタイムに接続すると、Colab ノートブック上のコードが**コンテナ内の任意コマンド実行およびマウント先（`./workspace`）のファイル読み書き**を行えるようになります。信頼できるノートブックのみ実行し、`compose.yaml` の `127.0.0.1` バインド設定を不用意に `0.0.0.0` へ広げないでください。

---

## リポジトリ構成

```text
.
├── Dockerfile                       # NGC PyTorch ARM64 + Colab Core/拡張ビルド定義
├── compose.yaml                     # GPU 予約・ボリューム・ヘルスチェック定義
├── Makefile                         # 起動・URL取得・セルフチェック用ショートカット
├── .env.example                     # 環境変数テンプレート
├── docker/
│   ├── entrypoint.sh                # GPU 判定・トークン生成・Jupyter Server 起動
│   ├── jupyter_server_config.py     # CORS / PNA / iopub レート設定
│   ├── ipython_config.py            # google.colab 拡張・matplotlib inline 設定
│   ├── colab_kernel_launcher.py     # ZMQ iopub HWM=0 カスタムカーネルランチャー
│   ├── patch_colabtools.py          # IPython 9.x / 空カーネル時の互換パッチ
│   └── selfcheck.py                 # GPU / PyTorch / 拡張の自動検証スクリプト
├── LICENSE                          # Apache License 2.0
└── workspace/                       # /content にマウントされる作業ディレクトリ
```

---

## ライセンス・免責事項

- 本リポジトリのファイルは [Apache License 2.0](LICENSE) のもとで公開しています。
- 本リポジトリは Google および NVIDIA とは無関係の非公式プロジェクトです。
- ビルド時に参照するベースイメージ（`nvcr.io/nvidia/pytorch`）および含まれるソフトウェアは、NVIDIA のソフトウェア利用規約（NVIDIA Software License Agreement / Deep Learning Container License）に従います。ビルド済みイメージを再配布せず、各利用者の環境で `Dockerfile` からビルドしてご利用ください。
- `google-colab` 拡張機能は Apache License 2.0 で公開されている [googlecolab/colabtools](https://github.com/googlecolab/colabtools) をビルド時に取得して利用しています。
