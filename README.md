# 喵咪足球大戰 · Godot 4 2D 3v3 遊戲

這是一個可直接在 Godot 4 開啟的可玩 2D 足球遊戲，依照提供的 Q 版藍髮女僕貓咪與藍金色介面方向製作。專案也保留一份零依賴的瀏覽器版，方便快速試玩與比對玩法。

目前完成的可玩流程：

- 主選單 → 3v3 快速賽
- 主選單 → 點球挑戰（5 球制，守門員 AI 會讀取你的瞄準方向；Godot／瀏覽器版皆可玩）
- WASD／方向鍵或手機虛擬搖桿移動
- 自動碰球控球、短按／長按蓄力射門
- 傳球、衝刺、鏟球／搶球、喵力必殺技
- 簡易 CPU 狀態機（追球、回防、施壓、射門）
- 進球動畫、比分、倒數計時、比賽資料與結算

## Godot 執行（主要版本）

需要 Godot 4（本機驗證版本為 4.7.2）。在 Godot Project Manager 匯入此資料夾後，按 **Run Project**（F6/F5）即可開始；主場景已設定為 `Main.tscn`。

也可以在終端機執行：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

桌面版操作：

- `WASD`／方向鍵：移動喵白白
- 點擊／拖曳球場：以滑鼠或觸控移動喵白白
- `SPACE`：長按蓄力、放開射門
- `E`：傳球、`Q`：搶球、`SHIFT`：衝刺、`R`：喵力必殺
- `ESC`：暫停

點球挑戰：使用 `W/S` 或 `A/D` 調整球門落點，按 `SPACE`（或畫面上的射門鍵）出腳；也可直接點擊球門落點瞄準。5 球後顯示結果並可返回主選單。

## 瀏覽器試玩（替代版本）

在此資料夾啟動任意靜態伺服器即可，例如：

```bash
python3 -m http.server 8000
```

再開啟 <http://127.0.0.1:8000/>。直接雙擊 `index.html` 也能看到介面，但使用伺服器可避免瀏覽器限制本地資產載入。

## 檔案

- `project.godot`／`Main.tscn`：Godot 專案設定與主場景
- `main.gd`：Godot 版 UI、Canvas 球場、球物理、玩家輸入、CPU 與比賽狀態
- `index.html`／`styles.css`／`game.js`：零依賴瀏覽器替代版本
- `assets/maomao-mascot.png`：提供的角色參考圖（透明 PNG）
- `assets/generated/menu-stadium-background-v2.png`：主選單生成式球場背景
- `assets/generated/menu-hero-team-v3.png`：主選單三人英雄卡（藍髮隊長與兩位貓咪隊友）
- `assets/generated/roster-portrait-strip-v3.png`：三位先發角色名冊肖像條
- `assets/generated/hero-action-v2.png`：主角動作精靈（透明 PNG）
- `assets/generated/cat-teammates-v2.png`：隊友雙人展示精靈（透明 PNG）
- `assets/generated/calico-player-v2.png`／`assets/generated/white-player-v2.png`：比賽中的藍隊隊友精靈（透明 PNG）
- `assets/generated/special-shot-v2.png`：海浪射門必殺技圖示（透明 PNG）
- `assets/generated/goal-effect-v2.png`：進球特效圖（透明 PNG）
- `assets/generated/goal-celebration-card-v3.png`：進球彈窗慶祝插圖
- `assets/generated/match-stadium-background-v2.png`：比賽中的 Riverside Stadium 生成式背景
- `assets/generated/red-player-v2.png`：紅隊球員精靈（透明 PNG）
- `assets/generated/goalkeeper-dive-v2.png`：點球挑戰守門員撲救動作（透明 PNG）
- `assets/generated/character-maid-captain-v1.png`：喵白白藍髮隊長全身角色（透明 PNG）
- `assets/generated/character-calico-midfielder-v1.png`：喵布布花貓中場全身角色（透明 PNG）
- `assets/generated/character-white-goalkeeper-v1.png`：喵小白白貓守門員全身角色（透明 PNG）
- `assets/generated/character-red-rival-v1.png`：紅隊紅棕虎斑前鋒全身角色（透明 PNG）
- `assets/generated/trophy-badge-v2.png`：錦標賽按鈕獎盃圖示（透明 PNG）
- `assets/generated/mode-quick-match-v1.png`：快速賽主選單卡片插圖
- `assets/generated/mode-tournament-v1.png`：錦標賽主選單卡片插圖
- `assets/generated/mode-story-v1.png`：故事模式主選單卡片插圖
- `assets/generated/mode-penalty-challenge-v1.png`：點球挑戰主選單卡片插圖

Godot 版以單一 GDScript 維持球場、物理、CPU 與互動邏輯，搭配生成式背景、角色與特效素材；不需要額外外掛或套件。

## 平台匯出

專案內的 `export_presets.cfg` 已設定 Windows Desktop、macOS、Android 與 iOS 四個 Godot 匯出預設。桌面與 Android 可在終端機直接匯出：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" build/windows/MaomaoSoccer.exe
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" build/macos/MaomaoSoccer.app
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug "Android" build/android/MaomaoSoccer.apk
```

Android 的 Godot 匯出預設刻意不綁定開發者憑證；若要交付可安裝的測試 APK，請再以自己的 keystore 簽章。iOS 匯出會先建立 `build/ios/MaomaoSoccer.xcodeproj`，需要已接受 Xcode 授權、有效 Apple Team ID 與 provisioning profile 才能由 Xcode 產生可安裝或上架的 IPA。
