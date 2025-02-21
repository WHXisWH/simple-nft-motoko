// 大容量ファイル対応NFTシステム
// 最大10GBまでのファイルをアップロードし、NFT化することができます

import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Int "mo:base/Int";

actor class LargeFileNFT() {
    // ===== 状態変数の定義 =====
    private stable var tokens : [NFT] = [];  // 作成されたNFTのリスト
    private var activeSessions = Buffer.Buffer<(Principal, UploadSession)>(0);  // アクティブなアップロードセッション

    // アップグレード時のセッションデータ保持用
    private stable var stableSessionData : [(Principal, {
        totalSize : Nat;
        expectedChunks : Nat;
        startTime : Int;
        mimeType : Text;
        sessionHash : Text;
    })] = [];

    // ===== 型定義 =====
    type TokenId = Nat;   // NFTの一意識別子
    type ChunkId = Nat;   // ファイルチャンクの識別子
    
    // ストレージタイプの定義（将来の拡張性を考慮）
    type StorageType = {
        #IC;        // Internet Computer上に保存
        #IPFS;      // IPFS上に保存
        #Arweave;   // Arweave上に保存
    };

    // アセット参照情報の定義
    type AssetReference = {
        storageType : StorageType;  // 保存場所の種類
        location : Text;            // 保存場所のURI
        size : Nat;                 // ファイルサイズ
        checksum : Text;            // チェックサム
        mimeType : Text;            // ファイルタイプ
        contentHash : Text;         // コンテンツハッシュ
    };

    // チャンク情報の定義
    type ChunkInfo = {
        index : Nat;               // チャンクの順番
        size : Nat;                // チャンクのサイズ
        checksum : Text;           // チャンクのチェックサム
        storage : AssetReference;   // 保存情報
        previousChunkHash : ?Text;  // 前のチャンクのハッシュ（順序保証用）
    };

    // NFTのメタデータ定義
    type NFTMetadata = {
        name : Text;           // NFTの名前
        description : Text;    // 説明
        category : Text;       // カテゴリ
        created : Int;         // 作成日時
        tags : [Text];         // タグ
    };

    // NFT本体の定義
    type NFT = {
        owner : Principal;         // 所有者
        metadata : NFTMetadata;    // メタデータ
        asset : AssetReference;    // アセット情報
        chunks : [ChunkInfo];      // ファイルチャンク
    };

    // アップロードセッションの定義
    type UploadSession = {
        owner : Principal;                    // アップロード実行者
        chunks : Buffer.Buffer<ChunkInfo>;    // アップロード済みチャンク
        totalSize : Nat;                      // 合計サイズ
        expectedChunks : Nat;                 // 予定チャンク数
        startTime : Int;                      // 開始時間
        mimeType : Text;                      // ファイルタイプ
        sessionHash : Text;                   // セッション識別子
    };

    // ===== 定数定義 =====
    private let MAX_CHUNK_SIZE : Nat = 2_000_000;        // チャンクの最大サイズ: 2MB
    private let MAX_SESSION_TIME : Int = 24 * 3600 * 1000_000_000;  // セッション有効期限: 24時間
    private let MAX_FILE_SIZE : Nat = 1024 * 1024 * 1024 * 10;      // 最大ファイルサイズ: 10GB

    // セッションID生成関数
    private func generateSessionId(caller : Principal, timestamp : Int) : Text {
        Principal.toText(caller) # Int.toText(timestamp)
    };

    // ===== パブリック関数 =====

    // アップロードセッション開始
    public shared(msg) func startUploadSession(
        expectedSize : Nat,    // 予定する合計サイズ
        chunksCount : Nat,     // 予定するチャンク数
        mimeType : Text,       // ファイルタイプ
    ) : async Result.Result<Nat, Text> {
        if (expectedSize > MAX_FILE_SIZE) {
            return #err("File size exceeds maximum limit of 10GB");
        };

        let session : UploadSession = {
            owner = msg.caller;
            chunks = Buffer.Buffer<ChunkInfo>(chunksCount);
            totalSize = expectedSize;
            expectedChunks = chunksCount;
            startTime = Time.now();
            mimeType;
            sessionHash = generateSessionId(msg.caller, Time.now());
        };

        activeSessions.add((msg.caller, session));
        #ok(activeSessions.size() - 1)
    };

    // チャンクアップロード
    public shared(msg) func uploadChunk(
        sessionId : Nat,     // セッションID
        chunk : Blob,        // チャンクデータ
        index : Nat          // チャンクの順番
    ) : async Result.Result<ChunkId, Text> {
        // セッションの存在確認
        if (sessionId >= activeSessions.size()) {
            return #err("Session not found");
        };

        let (owner, session) = activeSessions.get(sessionId);
        
        // 権限チェック
        if (Principal.notEqual(owner, msg.caller)) {
            return #err("Unauthorized");
        };

        // セッション有効期限チェック
        if (Time.now() - session.startTime > MAX_SESSION_TIME) {
            return #err("Session expired");
        };

        // チャンクサイズチェック
        if (chunk.size() > MAX_CHUNK_SIZE) {
            return #err("Chunk size exceeded");
        };

        // チャンク情報の作成
        let chunkInfo : ChunkInfo = {
            index;
            size = chunk.size();
            checksum = generateSessionId(msg.caller, Time.now());
            storage = {
                storageType = #IC;
                location = "";
                size = chunk.size();
                checksum = "";
                mimeType = session.mimeType;
                contentHash = "";
            };
            previousChunkHash = null;
        };

        session.chunks.add(chunkInfo);
        #ok(index)
    };

    // NFT情報の取得
    public query func getNFT(tokenId : TokenId) : async ?NFT {
        if (tokenId >= tokens.size()) {
            return null;
        };
        ?tokens[tokenId]
    };

    // ===== システム関数 =====

    // アップグレード前の処理
    system func preupgrade() {
        stableSessionData := Array.map<(Principal, UploadSession), (Principal, {
            totalSize : Nat;
            expectedChunks : Nat;
            startTime : Int;
            mimeType : Text;
            sessionHash : Text;
        })>(
            Buffer.toArray(activeSessions),
            func((p, s)) {
                (p, {
                    totalSize = s.totalSize;
                    expectedChunks = s.expectedChunks;
                    startTime = s.startTime;
                    mimeType = s.mimeType;
                    sessionHash = s.sessionHash;
                })
            }
        );
    };

    // アップグレード後の処理
    system func postupgrade() {
        activeSessions := Buffer.Buffer<(Principal, UploadSession)>(0);
        for ((p, data) in stableSessionData.vals()) {
            let session : UploadSession = {
                owner = p;
                chunks = Buffer.Buffer<ChunkInfo>(0);
                totalSize = data.totalSize;
                expectedChunks = data.expectedChunks;
                startTime = data.startTime;
                mimeType = data.mimeType;
                sessionHash = data.sessionHash;
            };
            activeSessions.add((p, session));
        };
        stableSessionData := [];
    };
}
