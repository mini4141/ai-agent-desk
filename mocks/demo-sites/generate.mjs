// Renders the static demo help sites (FAQ pages) that the ingestion job crawls.
// Run: node mocks/demo-sites/generate.mjs
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));

const sites = {
  mirai: {
    lang: "ja",
    name: "ミライ電機 ヘルプセンター",
    pages: {
      delivery: ["配送・お届け", [
        ["注文した商品はいつ届きますか？", "通常、ご注文から2〜3営業日でお届けします。離島や一部地域は5営業日ほどかかる場合があります。ご注文番号をお伝えいただければ、配送状況をお調べします。"],
        ["配送料はいくらですか？", "3,000円以上のご注文は送料無料です。3,000円未満の場合は全国一律550円です。"],
        ["配達日時を指定できますか？", "はい。ご注文時にお届け日と、午前中・14〜16時・16〜18時・18〜20時の時間帯を指定できます。"],
        ["配送状況を確認するには？", "マイページの注文履歴から追跡番号を確認できます。ご注文番号（例: A-1023）をお知らせいただければサポートでも確認します。"],
        ["不在で受け取れなかった場合は？", "不在票が投函されます。再配達はヤマト運輸または佐川急便のサイトや電話で24時間受付しています。"],
        ["海外への配送は可能ですか？", "申し訳ありませんが、現在は日本国内のみの配送です。"],
        ["大型家電の設置はしてもらえますか？", "冷蔵庫・洗濯機・エアコンは設置サービス（5,500円〜）をお選びいただけます。ご注文時に選択してください。"],
        ["配送先を変更したいです", "出荷前であればマイページから変更できます。出荷後の変更は配送業者へ直接ご連絡ください。"]]],
      returns: ["返品・交換", [
        ["返品はできますか？", "商品到着から14日以内で、未使用・未開封の場合に返品を承ります。マイページから申請してください。"],
        ["返品の送料は誰が負担しますか？", "お客様都合の返品は送料をご負担いただきます。初期不良や誤配送の場合は当社が負担します。"],
        ["商品が壊れて届きました", "到着後7日以内にサポートへご連絡ください。写真を確認のうえ、無償で交換いたします。"],
        ["交換の手続きを教えてください", "マイページの「返品・交換」から申請すると、返送用の伝票をメールでお送りします。"],
        ["返金はいつされますか？", "返品商品の検品完了後、5〜7営業日でご返金します。"],
        ["返金方法は選べますか？", "ご注文時のお支払い方法へ返金します。コンビニ払い・代金引換の場合は銀行振込です。"],
        ["セール品も返品できますか？", "セール品も返品可能です。ただし、福袋とアウトレット品は返品の対象外です。"],
        ["開封済みの商品は返品できますか？", "開封済みの場合、お客様都合の返品はお受けできません。初期不良は保証の対象です。"]]],
      payment: ["お支払い", [
        ["使える支払い方法は？", "クレジットカード、コンビニ払い、銀行振込、PayPay、代金引換がご利用いただけます。"],
        ["分割払いはできますか？", "クレジットカードで3・6・12・24回払いが可能です。分割手数料はカード会社の規定によります。"],
        ["コンビニ払いの支払期限は？", "ご注文から5日以内にお支払いください。期限を過ぎるとご注文は自動キャンセルされます。"],
        ["領収書は発行できますか？", "マイページの注文履歴から領収書をダウンロードできます。宛名の変更も可能です。"],
        ["請求はいつ確定しますか？", "クレジットカードは商品の出荷時に決済が確定します。ご注文時点では与信枠の確保のみです。"],
        ["クレジットカードが使えません", "カード会社へ限度額や有効期限をご確認ください。解決しない場合は別の支払い方法をお試しください。"],
        ["代金引換の手数料は？", "代金引換の手数料は一律330円です。"],
        ["支払い方法を変更したい", "出荷前であればマイページから変更できます。出荷後は変更できません。"]]],
      warranty: ["保証・修理", [
        ["メーカー保証の期間は？", "ご購入日から1年間です。保証書の代わりに、マイページの注文履歴をご利用いただけます。"],
        ["延長保証はありますか？", "3年・5年の延長保証をご用意しています。ご購入時または購入後30日以内にお申し込みください。"],
        ["修理を依頼するには？", "サポート窓口に症状と注文番号をお伝えください。送付用の伝票をお送りします。"],
        ["修理にはどれくらいかかりますか？", "到着から約1〜2週間です。部品の取り寄せが必要な場合は3週間ほどかかります。"],
        ["保証書をなくしてしまいました", "注文履歴が保証書の代わりになりますので、ご安心ください。"],
        ["水に濡れて故障した場合は？", "水濡れや落下による故障は保証対象外ですが、有償で修理できる場合があります。"],
        ["バッテリーの交換はできますか？", "対象機種のバッテリー交換を一律8,800円で承ります。"],
        ["出張修理はありますか？", "冷蔵庫・洗濯機などの大型家電のみ、出張修理に対応しています。"]]],
      account: ["アカウント・会員", [
        ["会員登録の方法は？", "メールアドレスとパスワードで無料登録できます。登録後すぐにお買い物とポイント利用ができます。"],
        ["パスワードを忘れました", "ログイン画面の「パスワードをお忘れの方」から再設定用のメールを送信できます。"],
        ["メールアドレスを変更したい", "マイページの「会員情報」から変更できます。確認メールのリンクを開くと反映されます。"],
        ["ポイントはどれくらい貯まりますか？", "100円（税込）のお買い物ごとに1ポイント、1ポイントは1円として使えます。"],
        ["ポイントの有効期限は？", "最後にポイントが付与された日から1年間です。"],
        ["退会するにはどうすればよいですか？", "マイページの「退会手続き」から手続きできます。未使用のポイントは失効します。"],
        ["会員ランクはありますか？", "年間のお買い上げ金額に応じて、ブロンズ・シルバー・ゴールドの3つのランクがあります。"],
        ["個人情報はどう扱われますか？", "個人情報は配送・サポートの目的にのみ利用し、第三者に提供しません。"]]],
      products: ["商品について", [
        ["在庫を確認できますか？", "商品ページに在庫状況が表示されます。店舗在庫はサポートでもご案内します。"],
        ["売り切れの商品は再入荷しますか？", "商品ページの「再入荷通知」に登録すると、入荷時にメールでお知らせします。"],
        ["商品の詳しい仕様を知りたい", "各商品ページの「仕様」タブに寸法・消費電力・保証内容を掲載しています。"],
        ["他の機器との互換性は？", "対応機種は商品ページに記載しています。ご不明な場合は型番を添えてお問い合わせください。"],
        ["型落ち品はありますか？", "アウトレットコーナーで型落ち品を最大50%オフで販売しています。"],
        ["新商品の予約はできますか？", "予約受付中の商品は、商品ページから予約できます。発売日に順次出荷します。"],
        ["法人でまとめて購入できますか？", "10台以上のご購入は法人窓口で特別価格をご案内します。見積書も発行できます。"],
        ["商品選びの相談はできますか？", "チャットまたは店舗で、スタッフがご予算と用途に合わせて提案します。"]]],
      campaigns: ["キャンペーン・クーポン", [
        ["クーポンの使い方を教えてください", "お支払い画面の「クーポン」欄にコードを入力してください。1回のご注文につき1枚使えます。"],
        ["クーポンは併用できますか？", "クーポン同士の併用はできませんが、ポイントとは併用できます。"],
        ["初回購入の割引はありますか？", "初めてのご注文で使える10%オフクーポンを、会員登録後にお送りします。"],
        ["ブラックフライデーはありますか？", "毎年11月下旬に最大30%オフのセールを開催します。メールマガジンで先行案内します。"],
        ["メールマガジンの配信を止めたい", "メール下部の配信停止リンク、またはマイページの設定から停止できます。"],
        ["学割はありますか？", "学生証をご提示いただくと、対象商品が5%オフになります。"],
        ["下取りサービスはありますか？", "対象家電を下取りし、新商品の購入代金から最大20,000円を値引きします。"],
        ["ギフト包装はできますか？", "1点につき220円でギフト包装とメッセージカードをお付けできます。"]]],
      support: ["サポート窓口", [
        ["サポートの営業時間は？", "オペレーターの対応は平日9:00〜18:00です。AIチャットは24時間ご利用いただけます。"],
        ["電話で問い合わせできますか？", "お問い合わせフォームから折り返しのお電話をご予約いただけます。電話番号と希望時間をお知らせください。"],
        ["チャットで担当者と話せますか？", "営業時間内であれば、チャットで「人と話したい」とお伝えいただくと担当者におつなぎします。"],
        ["折り返し電話を依頼したい", "お電話番号と希望の時間帯をお知らせください。担当者が折り返しご連絡します。"],
        ["実店舗はありますか？", "東京・大阪・福岡に直営店があります。営業時間は10:00〜20:00です。"],
        ["苦情や要望を伝えたい", "お問い合わせフォームまたはチャットでお寄せください。内容は品質改善に活用します。"],
        ["法人のお客様の窓口は？", "法人窓口では見積・請求書払い・まとめ買いのご相談を承ります。"],
        ["システムの障害情報はどこで確認できますか？", "障害・メンテナンス情報はヘルプセンターのトップに掲載します。"]]]
    }
  },
  harbor: {
    lang: "en",
    name: "Harbor Outdoor Help Center",
    pages: {
      shipping: ["Shipping", [
        ["How long does shipping take?", "Standard shipping takes 3 to 5 business days. Express shipping arrives in 1 to 2 business days."],
        ["How much does shipping cost?", "Orders over $75 ship free. Otherwise standard shipping is a flat $6.95."],
        ["Where is my order?", "Open Order History in your account for a tracking link, or give us your order number, for example H-2001, and we will look it up."],
        ["Do you ship internationally?", "We ship to Canada, the UK and Australia. Duties and taxes are collected at checkout."],
        ["Can I change my delivery address?", "You can change the address until the order ships, from the Order History page."],
        ["What if my package is lost?", "If tracking has not moved for 7 days, contact us and we will send a replacement or refund."]]],
      returns: ["Returns", [
        ["What is your return policy?", "Unused gear can be returned within 60 days for a full refund to the original payment method."],
        ["How do I start a return?", "Start in Order History, choose the items and print the prepaid label."],
        ["When will I get my refund?", "Refunds are issued within 5 business days after the returned items are inspected."],
        ["Can I exchange an item for another size?", "Yes. Choose Exchange when you start the return and we ship the new size at no extra cost."],
        ["Are sale items returnable?", "Sale items can be returned within 30 days. Final-clearance items are not returnable."],
        ["My item arrived damaged", "Contact us within 14 days with a photo and we will replace it for free."]]],
      orders: ["Orders and payment", [
        ["Which payment methods do you accept?", "We accept Visa, Mastercard, American Express, PayPal and Apple Pay."],
        ["Can I cancel my order?", "Orders can be cancelled until they ship. After that, use the return process."],
        ["When is my card charged?", "Your card is charged when the order ships, not when you place it."],
        ["Do you offer gift cards?", "Digital gift cards from $25 to $500 are delivered by email instantly."],
        ["How do promo codes work?", "Enter one code at checkout. Codes cannot be combined with other offers."],
        ["Can I get an invoice?", "Invoices are available as PDFs in Order History."]]],
      care: ["Gear care and warranty", [
        ["How long is the warranty?", "Tents and packs carry a 5-year warranty against manufacturing defects."],
        ["How do I wash my down jacket?", "Wash gently in a front-loading machine with down-specific soap and tumble dry low with dryer balls."],
        ["Can you repair my backpack?", "We repair zippers and straps for free within the warranty and for a small fee afterwards."],
        ["How do I waterproof my tent?", "Clean the fly, let it dry fully and apply a spray-on waterproofing treatment every season."],
        ["Does the warranty cover normal wear?", "No. Normal wear and accidental damage are not covered, but we offer repairs at cost."],
        ["How do I make a warranty claim?", "Send us your order number and photos of the problem and we will approve a replacement or repair."]]],
      account: ["Account and support", [
        ["How do I reset my password?", "Use Forgot password on the sign-in page and follow the emailed link."],
        ["What are your support hours?", "Our team is available Monday to Friday, 9am to 6pm Pacific. The AI assistant is available 24/7."],
        ["Can I talk to a person?", "Yes. Ask the chat for a human and a teammate will join during support hours."],
        ["Can I book a callback?", "Share your phone number and a preferred time and we will call you back."],
        ["Do you have retail stores?", "We have stores in Seattle, Portland and Denver, open 10am to 8pm daily."],
        ["How do I delete my account?", "Email privacy from your account page and we will remove your data within 30 days."]]]
    }
  }
};

const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");

for (const [slug, site] of Object.entries(sites)) {
  const dir = join(root, slug);
  mkdirSync(dir, { recursive: true });
  const links = [];
  for (const [page, [title, qas]] of Object.entries(site.pages)) {
    const body = qas.map(([q, a]) => `  <section>\n    <h2>${esc(q)}</h2>\n    <p>${esc(a)}</p>\n  </section>`).join("\n");
    writeFileSync(join(dir, `${page}.html`), `<!doctype html>\n<html lang="${site.lang}">\n<head><meta charset="utf-8"><title>${esc(title)}</title></head>\n<body>\n  <h1>${esc(title)}</h1>\n${body}\n</body>\n</html>\n`);
    links.push(`<li><a href="${page}.html">${esc(title)}</a></li>`);
  }
  writeFileSync(join(dir, "index.html"), `<!doctype html>\n<html lang="${site.lang}"><head><meta charset="utf-8"><title>${esc(site.name)}</title></head>\n<body><h1>${esc(site.name)}</h1><ul>${links.join("")}</ul></body></html>\n`);
}
console.log("demo sites generated");
