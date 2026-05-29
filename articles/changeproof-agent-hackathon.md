---
title: "【Agent Hackathon】DNS変更作業をAIエージェントで証跡化する ChangeProof Agent を作った"
emoji: "🔖"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["csharp", "react", "ai", "azure"]
published: true
---

## tl;dr

- ChangeProof Agent は、DNS変更作業のリスク評価、承認文、実行手順、ロールバック手順、作業後報告書、Evidence Bundle を生成するAIエージェントです。
- AIにDNSを変更させるのではなく、人間が作業する前後の判断材料と証跡を揃えることを目的にしました。
- Azure OpenAI + Semantic Kernel + ASP.NET Core + React + SQLite + Azure Blob Storage + Azure App Service で構成しました。
- Agent pipeline は、Change Intake / DNS Risk Assessment / Approval Brief / Execution Plan / Rollback Plan / Evidence Report に分けました。
- 監査対応を保証するものではありませんが、小規模IT変更作業の「あとから説明できない」を減らすMVPとして実装しました。

## 作ったもの

- アプリ名: ChangeProof Agent
- URL: 一般非公開
- 動画: [説明動画](https://youtu.be/-To5cJ9L1hk)
- 使用技術: Azure App Service / Azure OpenAI / Microsoft Foundry / Semantic Kernel / ASP.NET Core 8 / React / TypeScript / SQLite / Azure Blob Storage / Application Insights
- 対象業務: DNS変更作業のリスク確認、承認文作成、実行手順作成、ロールバック手順作成、作業後報告書ドラフト作成、Evidence Bundle保存

## 対象ユーザーと課題・ソリューション

対象ユーザーは、小規模IT会社、Web制作会社、ひとり情シス、少人数で顧客サイトや社内システムを見ているチームを想定している。

この層では、DNS変更やサーバー切替のような小さな変更作業が、チケット管理や変更管理の重い仕組みに乗らないことがある。作業者は分かっているつもりでも、後から見ると「変更前は何だったか」「誰が承認したか」「失敗したらどう戻す予定だったか」が残っていない。

ChangeProof Agent では、DNS変更リクエストを入力すると、AIがリスク、未確認事項、承認文、実行手順、ロールバック手順、作業後報告書ドラフトを生成し、Evidence Bundleとして保存する。DNS変更を説明可能な業務プロセスに寄せるためのツールとして作った。

## なぜ「DNS変更」なのか

自分は、こういう小さいIT変更ほど、証跡が曖昧になりやすいと思っている。今回は時間も限られていたので、開発範囲をできるだけ絞って進めることにした。

大規模な本番リリースにはリリース判定会議や手順書がある。一方で、DNS変更、サーバー切替、メール関連レコードの修正みたいな作業は、経験者の頭の中で進むことが多い。

問題は、DNS変更そのものの難しさではない。

- 変更前の状態が残っていない
- 顧客承認が曖昧
- 何を確認してOKにしたのか残っていない
- 失敗時に戻す手順がない
- 作業後の報告書が後追いになる

このあたりが、事故時・監査時・引き継ぎ時に問題になる。

ISMSの観点で見ても、ここは意外と重要だと思っている。変更管理そのものよりも、「誰が、何を根拠に、どの範囲の変更を承認し、作業後に何を確認したのか」が残っていないと、後から説明できない。事故が起きたときだけでなく、監査や振り返りの場面でも困る。

そこで今回は、AIエージェントの役割を、準備・説明・記録の支援に置いた。

## 何を作ったか

Microsoft Agent Hackathon 2026 向けに、ChangeProof Agent というMVPを作った。

対象はDNS変更だけに絞った。たとえば、Webサイト切替のためにAレコードを旧IPアドレスから新IPアドレスへ変える、TTLを短くする、MX / TXT / SPF / DKIM / DMARC への影響を確認する、というような作業だ。

やることはシンプルで、サンプルの変更依頼を読み込み、Change Requestを作り、`Analyze` を押す。するとAIが以下を生成する。

- 影響範囲
- リスク
- 事前確認項目
- 顧客向けの承認依頼文
- 人間作業者向けの実行手順
- ロールバック手順
- 作業後報告書のドラフト
- Evidence Bundle

画面としては、左にChange Request一覧、中央にJSON入力、右にAI出力タブを置いた。派手なUIではなく、デモで流れが追えることを優先した。

![トップページ](/images/changeproof-agent-hackathon/TopPageCapture.png)

## このMVPでやらないこと

ChangeProof Agent は、DNS変更を自動実行しない。

今回のMVPでやらないことは以下。

- 実DNSレコードの変更
- 本番環境への自動反映
- AIによる承認判断
- 監査対応の保証
- 法的な証明力の保証

この線引きを明確にすることで、AIの役割を作業支援と記録作成に限定した。

## デモの流れ

1. `Load Sample` でDNS変更サンプルを読み込む
2. `Create` でChange Requestを作る
3. `Analyze` を押すと、登録された変更依頼に対してAgent pipelineが実行される。
4. Risk Assessmentを見る
5. Approval Briefを見る
6. Execution Plan / Rollback Planを見る
7. Evidence ReportとAudit Eventsを見る
8. JSON / MarkdownのEvidence Bundleをダウンロードする

サンプルでは、現在のAレコードが `198.51.100.20 TTL 3600`、変更後が `203.0.113.10 TTL 300` という形になっている。AIには、TTL、Web切替、メール系レコードの未確認事項が出ることを期待している。

ここで大事なのは、AIが「安全です」と断定しないことだ。入力から分かること、前提にしていること、未確認のことを分ける。

## アーキテクチャ

構成はかなり普通にした。

![システムアーキテクチャ図](/images/changeproof-agent-hackathon/architecture.png)

```text
Browser
  |
  v
Azure App Service
  |
  +--> ASP.NET Core Minimal API
  |     +--> Domain Service
  |     +--> Agent pipeline
  |     +--> SQLite
  |
  +--> React static assets
  |
  +--> Azure OpenAI / Semantic Kernel
  |
  +--> Azure Blob Storage
  |
  +--> Application Insights
```

BackendはASP.NET Core 8 Minimal API、FrontendはReact + TypeScript。ローカルDBはSQLite。Evidence BundleはAzure Blob Storageに保存する。ローカル開発ではLocalFile fallbackも持たせた。

Azure App Serviceには、Backendのpublish outputとReactのproduction buildをまとめてzip deployした。最初はQuickDeployでOryxが勝手にserver-side buildしようとして失敗した。オプションにチェックを入れると build をしないとに気づくのに時間がかかった。

## Microsoft技術をどう使ったか

| 技術 | 使い方 |
|---|---|
| Azure OpenAI / Microsoft Foundry | 役割別のAI処理による推論と構造化JSON生成 |
| Semantic Kernel | Azure OpenAI chat completion呼び出しの抽象化 |
| Azure App Service | ASP.NET Core APIとReact静的ファイルのホスティング |
| Azure Blob Storage | Evidence BundleのJSON / Markdown保存 |
| Application Insights | App Serviceのrequest / failure / latency確認 |
| ASP.NET Core | Change Request API、状態遷移、AuditEvent、Agent pipeline制御 |
| React | Change Request作成、AI出力確認、Evidence Bundleダウンロード用UI |

## Agent pipeline

1つの巨大プロンプトで全部を作るのはやめた。役割を分けて、順番に実行する。

```text
Agent pipeline
  -> Change Intake
  -> DNS Risk Assessment
  -> Approval Brief
  -> Execution Plan
  -> Rollback Plan
  -> Evidence Report
  -> Evidence Bundle
```

ここでいう各行は、Azure AI Agent Serviceで作成する管理対象リソースではなく、ChangeProof Agent内部の役割別prompt実行単位を指している。コード上は `IAgentOrchestrator` / `AgentOrchestrator` がこのAgent pipelineを制御する。UIは `POST /api/change-requests/{id}/analyze` を1回呼ぶだけだが、内部では複数のPromptRunが記録される。

それぞれのAI出力は、単なる文章ではなくJSONとして扱う。

```json
{
  "schemaVersion": "0.1.0",
  "agentRole": "dns_risk_assessor",
  "summary": "DNS変更によりWeb到達先が変更される可能性があります。",
  "assumptions": [],
  "unknowns": [],
  "result": {
    "overallRiskLevel": "MEDIUM",
    "impactScope": [],
    "risks": [],
    "prechecks": []
  },
  "warnings": []
}
```

JSON parseできない場合は、1回だけrepair promptを投げる。それでもダメなら失敗としてPromptRunとAuditEventに残す。今回の開発中にも `AGENT_PROMPT_FAILED` を見た。Azure OpenAIのendpoint形式やJSON modeの指定を見直して、最終的にはAIで生成できるところまで持っていった。

## Evidence Bundleを中心にした

このMVPでは、画面にAI結果を表示して終わりにしない。Change Request単位でEvidence Bundleを作る。

保存するものは大きく2つ。

- JSON: 構造化されたAI出力とメタデータ
- Markdown: 人間が読みやすいEvidence Report

Blob nameはこういう形にした。

```text
{changeRequestId}/v{bundleVersion:0000}/{evidenceBundleId}.json
{changeRequestId}/v{bundleVersion:0000}/{evidenceBundleId}.md
```

ここが、このMVPで一番プロダクトとして意味がある部分だと思っている。AIの回答を一過性のチャットで終わらせず、判断・承認・手順・報告を1つの成果物にまとめる。

もちろん、これで監査対応が完了するわけではない。WORM Storage、電子署名、タイムスタンプ、権限管理、改ざん検知などはまだない。なので、表現としては「監査準備に使える可能性がある」くらいに留めるのが正しい。

## 状態遷移は人間を残す

状態はこうした。

```text
DRAFT
  -> EXECUTION_READY
  -> APPROVED
  -> EXECUTED
  -> CLOSED
```

`Analyze` が成功すると `EXECUTION_READY` になる。そこから先は、人間が `Mark as Approved`、`Mark as Executed`、`Close` を押す。

ここもかなり意識した。AIが勝手に承認したり、実行していない作業を実行済みにしたりしない。実DNS変更APIも叩かない。

AIは判断材料を作る。承認と実行の責任は人間側に残す。

## ハッカソンの評価観点との対応

| 観点 | ChangeProof Agentでの対応 |
|---|---|
| ビジネスインパクト | 小規模IT会社・情シスの変更作業を説明可能にする |
| AIエージェントとしての有効性 | リスク評価、承認文、実行手順、ロールバック、証跡化をAgent pipelineで分担 |
| 技術実装 | Azure OpenAI、Semantic Kernel、ASP.NET Core、React、Azure Blob Storageを利用 |
| 完成度 | デモUI、Evidence Bundle出力、Audit Events保存まで実装 |

## 詰まったところ

Azureまわりは、思ったより詰まった。

まず、モデルがリージョンやプロジェクトで使えないことがある。Foundryの画面ではモデルが見えていても、自分のプロジェクトでデプロイできるとは限らない。クォータ、リージョン、モデル種別、Direct from Azureかどうかを見る必要があった。

App Serviceも、初回なのにVM quotaが0で作れないことがあった。Free F1では今回の構成には弱く、Basic B1に寄せた。

Deployments では、publish outputをアップロードしたつもりでも QuickDeploy が Oryx buildを走らせて、`.csproj`を検出できずに落ちた。画面にある、オプションの「Skip Server-Side Build (Pre Built App)」にチェックを入れれば解決した。

最後に、Azure OpenAI endpointも少しはまった。Foundry UIには `/openai/v1` 付きの endpoint が出ることがあるが、Semantic KernelのAzure OpenAI connectorではresource root形式を期待する。画面に出ている内容をそのまま設定してはいけないことに気づいたため、アプリ側では `/openai` 以降を正規化するようにした。

```text
https://<resource-name>.openai.azure.com/
```

こういう泥臭い部分も含めて、実際にAzure上で動くものを作るハッカソン実装らしいところだった。

## できたこと

できたことはこのあたり。

- DNS変更リクエスト作成
- Azure OpenAIによるRisk Assessment生成
- Approval Brief / Execution Plan / Rollback Plan / Evidence Report生成
- Evidence BundleのJSON / Markdown保存
- Audit Events保存
- Azure App Serviceへのデプロイ
- Azure Blob StorageへのEvidence保存
- React UIで一通りのデモフロー

## まだできていないこと

本番サービスとしては、まだ足りない。

- 認証
- 権限管理
- マルチテナント
- Evidenceの削除・保持ポリシー
- Key Vault / Managed Identity
- PromptRunの検索UI
- Azure DNS / Cloudflare / Route53 のread-only連携
- WORM Storage / Object Lock
- 手動承認ワークフローの本格化

逆に言うと、ここを入れなかったからMVPとして間に合った。

今回の範囲では、「AI出力を構造化して保存する」「人間承認を状態遷移として残す」という線だけは崩さないようにした。

## 今後の展開

DNS変更に絞ったMVPとして作ったが、同じ構造は他のIT変更作業にも展開できる。

- Webサイト公開前チェック
- Cloudflare / Route53 / Azure DNS のread-only連携
- WordPress / PHP / SSL証明書更新の変更証跡化
- Microsoft 365 / Entra ID設定変更の事前レビュー
- ISMS向けの変更管理証跡レポート

用途が変わっても、変更内容を整理し、確認項目と記録を残すという骨格は共通して使えると考えている。

## まとめ

AIエージェントというと、本番操作まで自動化したくなる。でも自分は、最初の実用ポイントはもう少し手前にあると思っている。

DNS変更のような小さいが事故ると痛い作業では、作業そのものよりも、判断・承認・ロールバック・報告が曖昧になりがちだ。そこをAIに埋めさせるのは、かなり現実的だと思う。

ChangeProof AgentはまだMVPだが、この方向性には自分の中で手応えがあった。

## ChangeProof Agent を一緒に育てるための実例を集めています

ChangeProof Agent は、DNS変更やWebサイト公開、Microsoft 365 / Entra ID設定変更、ISMS向けの変更管理証跡などを、あとから説明できる形にするためのMVPです。

現時点では、自社だけで大きく作り切るのではなく、実務の事例を集めながら、必要な機能を絞って育てたいと考えています。

まずは、以下のような実例を1つだけ教えてください。

- DNS変更で確認漏れが怖かった
- Web公開時に何を確認したか残っていなかった
- M365 / Entra ID の設定変更で承認や作業記録が曖昧だった
- ISMSや監査向けに変更作業の証跡を残すのが面倒だった

匿名・ざっくりで大丈夫です。

また、以下の形で関わっていただける方も歓迎しています。

- MVPを無償で試してフィードバックできる方
- DNS / Cloudflare / Route53 / Azure DNS / Microsoft 365 / Entra ID まわりの知見を共有できる方
- 技術レビューや軽い検証に協力できる方
- クラウド利用料・デモ環境費・スポンサー支援に関心がある方

匿名化した変更作業サンプルを使った検証については、別途相談とさせてください。

フォーム: https://forms.gle/TbxdjCB6MozdJWSy9
