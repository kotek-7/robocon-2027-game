# Godotでの編集

見た目・音・入力の設定は、シーン、Theme、Input Mapから変更できます。以下のシーンをFileSystemからダブルクリックして開いてください。`main.tscn` のインスタンス経由で子ノードを変更する場合は「Editable Children」を使えますが、共通の変更は元シーンを開く方が分かりやすくなります。

## SEを差し替える

1. `scenes/audio/audio.tscn` を開き、`Cues` の下から操作名を選びます。
2. 用意した `.wav`、`.ogg`、`.mp3` をプロジェクトに追加します。ファイル名は自由です。
3. 音声ファイルをInspectorの **Stream** にドラッグします。
4. **Volume dB** と **Pitch Scale** を調整します。Pitch Scale `1` が素材そのままです。
5. Inspectorの **試聴** で確認し、**停止** で止めます。保存してゲームを再起動すると反映されます。

**Enabled** をオフにすると、その操作の音だけ無効になります。Streamが空の場合も無音になります。**Event** はゲーム側との対応キーなので変更しないでください。同じ素材を使う別の操作には、Streamの差し替えは影響しません。ただし共有する音声ファイルそのものやImport設定を変更した場合は、その素材を使う全操作に反映されます。試聴は、そのノードの音量・ピッチとAudioバス設定を使います。ゲーム内の保存済みSE音量や遠隔ロボットの減衰は加わりません。

| ノード | 場面 | ノード | 場面 |
| --- | --- | --- | --- |
| `hover` | 名前入力 | `confirm` | 決定 |
| `back` | 戻る | `pause` | メニューを開く |
| `resume` | 再開 | `start` | 試合開始 |
| `switch` | ロボット切替 | | |
| `deny` | 操作不可 | `work` | 作業開始 |
| `pick` | 拾う | `drop` | 降ろす |
| `give` | 受け渡す | `place` | 積む |
| `flip` | 裏返す | `mustika` | ムスティカ獲得 |
| `mandate` | ムスティカ条件成立 | `score` | 得点 |
| `climb` | 階段開始 | `land` | 着地 |
| `retry` | リトライ | `bump` | 接触 |
| `brake` | 停止 | `camera` | 視点操作開始 |
| `overview` | 全体表示 | `fullscreen` | 全画面切替 |
| `tick` | カウントダウン | `warning` | 残り時間の通知 |
| `finish` | 試合終了 | `win` | 勝利 |
| `lose` | 敗北 | `draw` | 引き分け |
| `found` | マッチ成立 | `lost` | 接続切れ |
| `reconnected` | 再接続 | | |

`MenuMusic` と `MatchMusic` はBGM、`Motors` の4ノードは各ロボットの走行音です。こちらもStreamを差し替えます。BGMと走行音は、音声ファイルのImport設定でLoopを有効にしてください。Audioルートにはフェードアウト時間、遠隔音の減衰、速度による走行音ピッチ変化の設定があります。フェードインはありません。試合開始・RESET後のBGMは1秒後に開始し、待ち時間は `MatchStartDelay` のWait Timeで変更できます。`Voices` はSE再生用の12個のプレイヤーで、音の割り当てには使いません。

バスとリミッターは、下部の **Audio** パネルで編集します。設定は `default_bus_layout.tres` に保存されます。素材を変更したときは、タイトルのクレジットと `assets/audio/sources.json` も実際の素材に合わせて更新してください。

## 画面を編集する

| 編集したいもの | 開くシーン／リソース |
| --- | --- |
| タイトルの文字・ロゴ | `scenes/ui/title.tscn` のLabel／TextureRect |
| タイトルのボタン | `scenes/ui/menus/title.tscn` |
| プロフィール・音量スライダー | `scenes/ui/menus/profile.tscn` |
| オンライン選択・接続待ち | `scenes/ui/menus/online.tscn`、`search.tscn` |
| ポーズ・結果・エラー・クレジット | `scenes/ui/menus/` の対応シーン |
| メニューの背景・中央配置 | `scenes/ui/menu_panel.tscn` |
| スコア・時計・積載・名前表示 | `scenes/ui/hud.tscn` |
| タッチボタン・スティック・縦画面案内 | `scenes/ui/touch_controls.tscn` |
| 常設プロフィール・全画面ボタン | `scenes/ui/interface.tscn` |
| 共通の色・余白・フォント・枠 | `resources/ui/desktop.tres`、`mobile.tres` |
| 日本語フォントのフォールバック | `resources/ui/font.tres` |

HUDには `Desktop` と `Mobile` の2種類の配置があります。タッチボタンの当たり判定はButtonの配置・サイズに追従します。ルートのInspectorでスティックの半径、デッドゾーン、操作開始領域を変更できます。タッチの同時押しを扱うため、ButtonのMouse FilterはIgnoreのまま使ってください。

メニューのルートにはPC／モバイル用Themeとボタン高さの設定があります。画面を開くと端末に合う設定が選ばれます。メニューのノード名は動作との対応に使うので保ってください。スコア、プレイヤー名、接続状態などの動的な文字は試合状態から更新されます。

## 3Dと入力を編集する

- `main.tscn` の `Camera`: FOV、追従距離・速度、全体表示位置、タイトル周回の設定。
- `main.tscn` のルート: マウス／タッチ／ゲームパッドの視点感度、利用するメニューシーン。
- `scenes/robots/`: シャーシ・車輪・フォークなどの形状と素材。ルートに移動補間、傾き、上下動の設定。
- `scenes/objects/`: 競技物の形状と素材。ルートに補間と取得・設置時の拡縮設定。
- `scenes/world/stadium.tscn`: 会場の配置、風船の揺れ、観客の上下動。
- `scenes/world/confetti.tscn`: 標準のCPUParticles3Dで紙吹雪の寿命、速度、重力、形状を編集。発生位置・色・個数は試合イベントから渡されます。
- Project Settings → **Input Map**: 移動、視点操作、決定、ロボット切替、全体表示、ポーズのキー／ゲームパッド割り当て。

得点判定、AI、通信、保存、試合中の位置と状態の更新は引き続きGDScriptが担当します。競技物とロボットの初期配置・リトライ位置は試合モデル、歩行可能領域はCADデータを使用します。3Dの見た目を移動・拡縮しても、それだけではルールや通行判定は変わりません。

## Match feedback

`HUD/Feedback` consumes authoritative match events once and clears its history on restart/reconnect. Its `Bubble Seconds` and `Score Seconds` settings control display duration. Edit `scenes/ui/event_bubble.tscn` for the robot speech bubble (Japanese font fallback included), and `scenes/ui/score_popup.tscn` for the floating score delta and particles. Retry, Mandate and Mustika completion show リトライ！, マンデート！ and 奉納！ on the responsible robot. Positive score events include the team and exact delta; both teams receive visual feedback while score audio remains local-team-only.

Placement previews choose a compatible carried object for the nearest reachable tower, or Mustika for the pillar. The cargo highlight previews that choice; starting the placement updates the selected slot without a selection sound. BR CPU waiting for work never contributes to the stuck/retry timer; blocked movement toward real work still does.

Speech bubbles use Dela Gothic One from https://github.com/google/fonts/tree/main/ofl/delagothicone, distributed with `assets/DelaGothicOne-OFL.txt` (SIL OFL 1.1). The shared HUD font remains unchanged.
