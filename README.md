# Vimamsa (日本語版)

**Vimamsa**は、RubyとGTK4で構築された、Vi/Vimにインスパイアされた画期的な実験的GUIテキストエディタです。
オリジナルはLinux環境を前提に開発されていましたが、依存パッケージを適切にインストールすることで、macOSでもスムーズに動作させることができます。

---

## 🌟 開発者へ

本プロジェクトのオリジナル開発者である **Sami Sieranoja (SamiSieranoja)** 氏の素晴らしい設計と実装に、深い敬意と感謝の意を表します。
Rubyのみを用いて、GVimのような極めて軽快かつ直感的なキーバインド操作を実現した本エディタは、非常に画期的で素晴らしい成果物です。私たちはこの素晴らしい遺産を大切にし、macOSでも快適に動作するようにフォークして環境を整備しました。

---

## 📋 必要動作環境

- **Ruby 3.0以上**
- **GTK 4** (および各種依存ライブラリ)

---

## 🚀 macOSでのインストール・起動手順

macOS環境において、GTK4や各種Ruby拡張をコンパイル・起動するためには、以下の手順に従って依存パッケージをインストールしてください。

### 1. Homebrewを使用した依存ライブラリのインストール
ターミナルを開き、以下のHomebrewコマンドを実行して、必要なパッケージをシステムにインストールします。

```bash
brew install pkg-config glib gobject-introspection gtk4 gtksourceview5 gstreamer vte3 ruby
```

### 2. 環境変数の設定 (特にApple Silicon搭載Macの場合)
Homebrewでインストールした最新のRubyや `pkg-config` の情報をビルド時に正しく参照させるため、使用しているシェル（Zshなど）の設定ファイル（`~/.zshrc` や `~/.bash_profile`）に、以下の環境変数を追加してください。

```bash
# HomebrewでインストールしたRubyとpkg-configへのパスを優先する設定
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/ruby/lib"
export CPPFLAGS="-I/opt/homebrew/opt/ruby/include"
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/libffi/lib/pkgconfig"
```

追加後、設定を反映させます：
```bash
source ~/.zshrc
```

### 3. リポジトリのクローンと依存Gemのインストール
リポジトリをローカルにクローンし、Bundlerを使って依存Gem群をインストールします。
（※`YOUR_USERNAME` の箇所は、ご自身のGitHubアカウント名などに適宜置き換えてください。直接 `flzroche` を指定しても構いません）

```bash
git clone https://github.com/YOUR_USERNAME/vimamsa.git
cd vimamsa
bundle install
```

### 4. 拡張モジュールのビルドとインストール
C言語で書かれた高速化用の拡張モジュール (`vmaext`) をビルドし、ローカル環境にGemとしてインストールします。付属の `install.sh` を使用するのが最も簡単です。

```bash
chmod +x install.sh
./install.sh
```

手動でGemパッケージをビルドしてインストールする場合は、以下を実行します：
```bash
gem build vimamsa.gemspec
gem install --local vimamsa-0.1.26.gem
```

---

## 🏃 起動方法

インストールが正常に完了したら、以下のコマンドでVimamsaを起動できます：

```bash
vimamsa
```

開発中のソースコードから直接実行したい場合は、以下のコマンドを使用します：
```bash
bundle exec ruby exe/vimamsa
```

### オプション機能の有効化
より高度な機能を利用したい場合は、以下の外部パッケージをインストールすることをお勧めします。
```bash
# 高速なファイル内検索(ack-grep)を利用する場合
brew install ack
```

---

## ⚙️ カスタマイズ

キーバインドやエディタの挙動は、`~/.vimamsa/custom.rb` に記述することで自在にカスタマイズできます。

例えば、`Ctrl + N` で「新規ファイル作成」のアクションを実行できるようにしたい場合は、以下のように記述します。

```ruby
bindkey 'C ctrl-n', 'create_new_file()'
```

---

## ⌨️ キーバインド

Vimamsaのキーバインドは、Vimの操作体系を踏襲しています。詳細なバインド設定や一覧は、エディタ内のメニュー **[Help] -> [Show key bindings]** を選択するか、リポジトリ内の `lib/vimamsa/key_bindings_vimlike.rb` をご参照ください。

### コマンドモード（主要キー抜粋）
```text
j k l h w b p P G f F ; 0 $ v i o J * / a A I u ctrl-r x
zz dd dw gg <行番号>G r<文字>
```

### ビジュアルモード
```text
d y gU gu
```

### キー表記について
- `ctrl!` : Ctrlキーを単独で押して、すぐに離す操作。
- `ctrl-x` : Ctrlキーを押しながら、`x`キーを同時に押す操作。

---

## ⚠️ 既知の課題と制限事項

### 既知の課題
- **カーソルの消失**: ウィンドウのリサイズやドラッグを行った際に、稀にテキストカーソルが見えなくなる場合があります。これはGTK4の仕様によるもので、新しいGTKバージョン（4.18以上など）で改善されています。万が一消えてしまった場合は、**Ctrlキーを素早く2回押す**と再描画され、復帰します。

### 制限事項
- **UTF-8 エンコーディング専用**
- **改行コードは LF (`\n`) のみ対応**

---

## ⚖️ ライセンス

本プロジェクトは **MITライセンス** に基づいて提供されています。
オリジナル開発者の意図およびRuby/GTKコミュニティへの感謝とともに、オープンソースソフトウェアとしてどなたでも自由に変更、拡張、再配布いただけます。
