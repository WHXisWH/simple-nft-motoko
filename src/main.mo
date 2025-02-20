import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";

actor {
    type TokenId = Nat;
    
    // ChunkId for file uploading
    type ChunkId = Nat;
    
    // Asset data type
    type Asset = {
        contentType : Text;    // MIMEタイプ
        chunks : [Blob];       // ファイルチャンク
    };

    // NFT type with asset
    type NFT = {
        owner : Principal;
        metadata : Text;
        asset : ?Asset;        // オプショナルなアセット
    };
    
    private stable var tokens : [NFT] = [];
    private var chunks = Buffer.Buffer<Blob>(0);

    // ファイルアップロード用の一時保存領域
    private var uploadingChunks = Buffer.Buffer<Blob>(0);
    
    // チャンクをアップロードする関数
    public func uploadChunk(chunk : Blob) : async ChunkId {
        uploadingChunks.add(chunk);
        return uploadingChunks.size() - 1;
    };

    // アップロードされたチャンクでNFTを作成
    public shared(msg) func mintWithAsset(
        metadata : Text,
        contentType : Text
    ) : async TokenId {
        let asset : Asset = {
            contentType = contentType;
            chunks = uploadingChunks.toArray();
        };
        
        let newNFT : NFT = {
            owner = msg.caller;
            metadata = metadata;
            asset = ?asset;
        };
        
        tokens := Array.append(tokens, [newNFT]);
        uploadingChunks.clear();  // 一時保存領域をクリア
        
        return Array.size(tokens) - 1;
    };

    // 基本的なNFTの作成（アセットなし）
    public shared(msg) func mint(metadata : Text) : async TokenId {
        let newNFT : NFT = {
            owner = msg.caller;
            metadata = metadata;
            asset = null;
        };
        tokens := Array.append(tokens, [newNFT]);
        return Array.size(tokens) - 1;
    };
    
    // NFTの所有者を取得
    public query func getOwner(tokenId : TokenId) : async ?Principal {
        if (tokenId >= tokens.size()) {
            return null;
        };
        ?tokens[tokenId].owner;
    };
    
    // NFTのメタデータを取得
    public query func getMetadata(tokenId : TokenId) : async ?Text {
        if (tokenId >= tokens.size()) {
            return null;
        };
        ?tokens[tokenId].metadata;
    };

    // アセット情報を取得
    public query func getAsset(tokenId : TokenId) : async ?Asset {
        if (tokenId >= tokens.size()) {
            return null;
        };
        tokens[tokenId].asset;
    };

    // チャンクを取得
    public query func getChunk(tokenId : TokenId, chunkId : ChunkId) : async ?Blob {
        if (tokenId >= tokens.size()) {
            return null;
        };
        
        switch (tokens[tokenId].asset) {
            case (null) { null };
            case (?asset) {
                if (chunkId >= asset.chunks.size()) {
                    return null;
                };
                ?asset.chunks[chunkId];
            };
        };
    };

    // システム関数
    system func preupgrade() {
        // アップグレード前の処理
    };

    system func postupgrade() {
        // アップグレード後の処理
        uploadingChunks.clear();
    };
}