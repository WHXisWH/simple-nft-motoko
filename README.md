# Large File NFT System

大容量ファイル（最大10GB）をNFT化できるInternet Computer上のcanisterシステムです。
BIMデータなどの大規模ファイルを効率的に管理し、NFTとして扱うことができます。

## デプロイ済みCanister

- Canister ID: ``
- 環境: Motoko Playground

## 技術仕様

### ストレージ制限
- 最大ファイルサイズ: 10GB
- 最大チャンクサイズ: 2MB
- アップロードセッション有効期間: 24時間

### サポートされているストレージタイプ
- Internet Computer (IC)
- IPFS (計画中)
- Arweave (計画中)

## システムアーキテクチャ

### コアコンポーネント
1. **セッション管理**
   - アップロードセッションの作成と管理
   - チャンク単位でのアップロード処理
   - セッション有効期限の管理

2. **ストレージ管理**
   - チャンクベースのストレージ
   - 分散ストレージ対応
   - データ整合性の検証

3. **NFT管理**
   - メタデータ管理
   - 所有権管理
   - アセット参照管理

## API仕様

### アップロードセッション開始
```motoko
startUploadSession(
    expectedSize : Nat,    // 合計ファイルサイズ
    chunksCount : Nat,     // 予定チャンク数
    mimeType : Text        // ファイルタイプ
) : async Result<Nat, Text>
```

### チャンクアップロード
```motoko
uploadChunk(
    sessionId : Nat,    // セッションID
    chunk : Blob,       // チャンクデータ
    index : Nat         // チャンク順序
) : async Result<ChunkId, Text>
```

### NFT情報取得
```motoko
getNFT(tokenId : TokenId) : async ?NFT
```

## 実装詳細

### データ構造
- NFTMetadata: NFTの基本情報
- AssetReference: ファイル参照情報
- ChunkInfo: チャンク管理情報
- UploadSession: アップロード進行状況管理

### セキュリティ機能
- セッション所有者の検証
- チャンクサイズの制限
- アップロード期限の管理

## 使用方法

### 1. ファイルアップロード
1. アップロードセッションの開始
```bash
dfx canister call large_file_nft startUploadSession '(1024000, 10, "image/jpeg")'
```

2. チャンクのアップロード
```bash
dfx canister call large_file_nft uploadChunk '(0, vec {1;2;3}, 0)'
```

### 2. NFT情報の取得
```bash
dfx canister call large_file_nft getNFT '(0)'
```

## エラーハンドリング

主なエラーケースと対処方法：

1. **セッション関連**
- "Session not found": セッションIDの確認
- "Session expired": 新しいセッションの開始
- "Unauthorized": 認証情報の確認

2. **アップロード関連**
- "Chunk size exceeded": チャンクサイズの調整
- "File size exceeds limit": ファイルサイズの確認

## 開発環境のセットアップ

```bash
# リポジトリのクローン
git clone [repository-url]
cd large-file-nft

# プロジェクトの初期化
dfx start --clean --background
dfx deploy
```

## ライセンス
MIT License

## 今後の予定
- IPFS統合の実装
- Arweave統合の実装
- バッチアップロード機能の追加
- プログレスバーの実装
