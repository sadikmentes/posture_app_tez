import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-5-nano";
const perMinuteLimit = Number(Deno.env.get("AI_RATE_LIMIT_PER_MINUTE") ?? 3);
const dailyLimit = Number(Deno.env.get("AI_DAILY_LIMIT") ?? 50);

const safetyInstructions = `
Sen Postur Asistani'sin. Turkce konusan, kisa, net, guvenli ve postur odakli bir saglik destek asistanisin.

Davranis:
- Cevaplarin dogal Turkce olsun; ayni sablonu tekrar etme.
- Kullanici selam verirse kisa ve sicak karsilik ver.
- Kullanici genel bir soru sorarsa once kisa cevap ver, sonra postur/saglik tarafina bagla.
- Kullanici postur, boyun, omuz, sirt, bel, masa basi, egzersiz, rapor veya cihaz verisi sorarsa uygulamanin son 7 gunluk ozetini kullan.
- Cevaplari genelde 2-5 kisa paragraf veya 3-5 madde ile sinirla.
- Her cevapta uzun yasal uyari yazma.

Saglik sinirlari:
- Tani koyma, ilac veya doz onermeme, kesin tedavi plani verme.
- Siddetli agri, travma, gogus agrisi, nefes darligi, uyusma, guc kaybi, idrar/gaita kontrol kaybi veya ani kotulesme varsa acil tibbi destek ya da uzman degerlendirmesi oner.
- Egzersiz onerilerini genel, hafif, kontrollu ve agrisiz aralikta tut.
- Kod, yazilim, siyaset, finans, oyun, odev veya uygulama konusu disindaki isteklerde kisa cevap verip postur ve genel saglik alanina geri yonlendir.
`;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const openaiKey = Deno.env.get("OPENAI_API_KEY") ?? "";

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Supabase environment variables are missing.");
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      threadId,
      userId,
      message,
      postureContext = {},
      recentMessages = [],
    } = await req.json();

    if (!threadId || !userId || !message) {
      throw new Error("threadId, userId and message are required.");
    }

    const safetyLevel = safetyLevelFor(message);
    const limitStatus = await checkRateLimit(supabase, userId);
    if (!limitStatus.allowed) {
      const assistantText = limitAnswer(limitStatus.reason);
      await insertAssistantMessage(supabase, {
        threadId,
        userId,
        assistantText,
        safetyLevel: "general",
        postureContext,
        source: "blocked",
        diagnostic: limitStatus.reason,
      });
      return jsonResponse({
        content: assistantText,
        safetyLevel: "general",
        source: "blocked",
        model,
        diagnostic: limitStatus.reason,
      });
    }

    const scopeStatus = classifyScope(message);
    if (!scopeStatus.allowed) {
      const assistantText = outOfScopeAnswer(scopeStatus.reason, message);
      await insertAssistantMessage(supabase, {
        threadId,
        userId,
        assistantText,
        safetyLevel: "general",
        postureContext,
        source: "blocked",
        diagnostic: scopeStatus.reason,
      });
      return jsonResponse({
        content: assistantText,
        safetyLevel: "general",
        source: "blocked",
        model,
        diagnostic: scopeStatus.reason,
      });
    }

    let assistantText = "";
    let source: "openai" | "fallback" | "blocked" = "fallback";
    let diagnostic = "";

    if (!openaiKey) {
      diagnostic = "OPENAI_API_KEY secret eksik.";
      console.error("[ai-posture-chat] OPENAI_API_KEY is missing.");
    } else {
      const response = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${openaiKey}`,
        },
        body: JSON.stringify({
          model,
          instructions: safetyInstructions,
          input: [
            {
              role: "user",
              content:
                `Postur ozeti JSON: ${JSON.stringify(postureContext)}\n` +
                `Son mesajlar JSON: ${JSON.stringify(recentMessages)}\n` +
                `Kullanici mesaji: ${message}`,
            },
          ],
          reasoning: { effort: "minimal" },
          text: { verbosity: "low" },
          max_output_tokens: 1200,
        }),
      });

      if (response.ok) {
        const data = await response.json();
        assistantText = extractOutputText(data);
        if (assistantText.trim().length > 0) {
          source = "openai";
        } else {
          diagnostic = "OpenAI bos cevap dondurdu.";
          console.error(
            "[ai-posture-chat] Empty OpenAI response",
            JSON.stringify(data).slice(0, 2000),
          );
        }
      } else {
        const body = await response.text();
        diagnostic = `OpenAI hata verdi: HTTP ${response.status}.`;
        console.error("[ai-posture-chat] OpenAI error", {
          status: response.status,
          body: body.slice(0, 1200),
        });
      }
    }

    if (source !== "openai") {
      assistantText = fallbackAnswer(message, postureContext, diagnostic);
    }

    await insertAssistantMessage(supabase, {
      threadId,
      userId,
      assistantText,
      safetyLevel,
      postureContext,
      source,
      diagnostic,
    });

    return jsonResponse({
      content: assistantText,
      safetyLevel,
      source,
      model,
      diagnostic,
    });
  } catch (error) {
    console.error("[ai-posture-chat] Fatal error", error);
    return new Response(
      JSON.stringify({ error: String(error?.message ?? error) }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});

function jsonResponse(payload: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function checkRateLimit(supabase: any, userId: string) {
  const now = new Date();
  const oneMinuteAgo = new Date(now.getTime() - 60_000).toISOString();
  const dayStart = new Date(now);
  dayStart.setHours(0, 0, 0, 0);

  const minute = await supabase
    .from("ai_chat_messages")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("role", "user")
    .gte("created_at", oneMinuteAgo);

  if (minute.error) throw minute.error;
  if ((minute.count ?? 0) >= perMinuteLimit) {
    return { allowed: false, reason: "minute_limit" };
  }

  const daily = await supabase
    .from("ai_chat_messages")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("role", "user")
    .gte("created_at", dayStart.toISOString());

  if (daily.error) throw daily.error;
  if ((daily.count ?? 0) >= dailyLimit) {
    return { allowed: false, reason: "daily_limit" };
  }

  return { allowed: true, reason: "" };
}

async function insertAssistantMessage(
  supabase: any,
  params: {
    threadId: string;
    userId: string;
    assistantText: string;
    safetyLevel: "general" | "caution" | "urgent";
    postureContext: Record<string, unknown>;
    source: "openai" | "fallback" | "blocked";
    diagnostic: string;
  },
) {
  const { error: insertError } = await supabase
    .from("ai_chat_messages")
    .insert({
      thread_id: params.threadId,
      user_id: params.userId,
      role: "assistant",
      content: params.assistantText,
      safety_level: params.safetyLevel,
      posture_context: {
        ...params.postureContext,
        ai_source: params.source,
        ai_model: model,
        ai_diagnostic: params.diagnostic,
      },
    });

  if (insertError) throw insertError;

  await supabase
    .from("ai_chat_threads")
    .update({ last_message_at: new Date().toISOString() })
    .eq("id", params.threadId)
    .eq("user_id", params.userId);
}

function extractOutputText(data: any): string {
  if (typeof data?.output_text === "string") return data.output_text.trim();

  const parts = data?.output
    ?.flatMap((item: any) => item.content ?? [])
    ?.map((part: any) => part.text ?? part.content ?? "")
    ?.filter(Boolean);

  return Array.isArray(parts) ? parts.join("\n").trim() : "";
}

function safetyLevelFor(message: string): "general" | "caution" | "urgent" {
  const text = normalizeTurkish(message);
  const urgent = [
    "gogus",
    "nefes",
    "uyusma",
    "felc",
    "travma",
    "dusme",
    "guc kaybi",
    "idrar",
    "gaita",
    "dayanilmaz",
  ];
  if (urgent.some((token) => text.includes(token))) return "urgent";
  if (text.includes("agri") || text.includes("sizi")) return "caution";
  return "general";
}

function classifyScope(message: string) {
  const text = normalizeTurkish(message);

  if (text.length <= 20 && containsAny(text, [
    "merhaba",
    "selam",
    "slm",
    "hello",
    "hi",
    "tesekkur",
    "sag ol",
  ])) {
    return { allowed: true, reason: "" };
  }

  const healthTokens = [
    "postur",
    "duru",
    "boyun",
    "ense",
    "omuz",
    "sirt",
    "bel",
    "kalca",
    "agri",
    "sizi",
    "egzersiz",
    "hareket",
    "rutin",
    "fizyoterapi",
    "fizyoterapist",
    "ergonomi",
    "masa",
    "otur",
    "ayakta",
    "yuruyus",
    "kas",
    "eklem",
    "germe",
    "esneme",
    "rapor",
    "skor",
    "sensor",
    "cihaz",
    "bluetooth",
    "kalibrasyon",
    "saglik",
    "saglig",
  ];

  const blockedTokens = [
    "kod",
    "python",
    "javascript",
    "typescript",
    "flutter",
    "sql",
    "html",
    "css",
    "api yaz",
    "program yaz",
    "uygulama yaz",
    "hack",
    "crack",
    "exploit",
    "borsa",
    "kripto",
    "bitcoin",
    "yatirim",
    "siyaset",
    "secim",
    "oyun hilesi",
    "odev",
    "makale yaz",
    "kompozisyon",
  ];

  const hasHealth = containsAny(text, healthTokens);
  const hasBlocked = containsAny(text, blockedTokens);

  if (hasBlocked && !hasHealth) {
    return { allowed: false, reason: "blocked_topic" };
  }

  if (!hasHealth && text.length > 80) {
    return { allowed: false, reason: "out_of_scope" };
  }

  return { allowed: true, reason: "" };
}

function outOfScopeAnswer(reason: string, message: string) {
  const text = normalizeTurkish(message);
  if (reason === "blocked_topic") {
    return "Bu konuda yardimci olamam. Ben bu uygulamada postur, durus takibi, ergonomi, egzersiz ve genel saglik destegi icin varim.\n\nIstersen boyun, omuz, sirt, bel veya rapor yorumlama konusunda sorunu yazabilirsin.";
  }

  if (text.length <= 80) {
    return "Kisa cevap vereyim: Bu soru uygulamanin ana alani disinda kaliyor. Ben burada postur, durus, ergonomi, egzersiz ve genel saglik konularinda yardimci olabilirim.";
  }

  return "Bu konu uygulamanin saglik ve postur kapsaminda degil. Sorunu postur, boyun, omuz, sirt, bel, masa basi ergonomi, egzersiz veya rapor yorumu cercevesinde yazarsan yardimci olurum.";
}

function limitAnswer(reason: string) {
  if (reason === "minute_limit") {
    return "Cok hizli mesaj gonderiyorsun. AI kullanimini korumak icin kisa bir sure bekleyip tekrar deneyebilirsin.";
  }
  return "Bugunku AI kullanim limitine ulastin. Bu limit maliyeti ve sistemi korumak icin uygulanir. Daha sonra tekrar deneyebilirsin.";
}

function fallbackAnswer(
  message: string,
  context: Record<string, unknown>,
  diagnostic: string,
) {
  const text = normalizeTurkish(message);
  const avg = Number(context["avgScore"] ?? 0);
  const bad = Number(context["badPostureMinutes"] ?? 0);
  const tracking = Number(context["trackingMinutes"] ?? 0);
  const scoreLine = tracking > 0
    ? `Son 7 gun ozetin: ortalama skor ${avg}/100, kotu postur suren yaklasik ${bad} dakika.`
    : "Henuz yeterli sensor verin yok; yine de genel postur onerisi verebilirim.";

  const prefix =
    `Gercek AI baglantisi su an devrede degil (${diagnostic || "bilinmeyen neden"}). ` +
    "Bu cevap guvenli yerel moddan geliyor.\n\n";

  if (safetyLevelFor(message) === "urgent") {
    return prefix +
      "Anlattigin belirti acil degerlendirme gerektirebilir. Gogus agrisi, nefes darligi, uyusma, guc kaybi, travma sonrasi agri veya dayanilmaz agri varsa beklemeden tibbi destek al.";
  }

  if (containsAny(text, ["merhaba", "selam", "slm", "hello", "hi"])) {
    return prefix +
      "Merhaba. Ben Postur Asistani. Gercek AI anahtari duzeldiginde daha esnek cevap verecegim; simdilik postur verini yorumlama, kisa mola rutini ve guvenli egzersiz onerilerinde yardimci olabilirim.";
  }

  if (containsAny(text, ["rutin", "egzersiz", "program", "hareket"])) {
    return prefix +
      `${scoreLine}\n\nKisa masa basi rutini: 45 sn cene geriye cekme, 45 sn kurek kemigi sikistirma, 60 sn gogus acma, 60 sn omuz dairesi, 90 sn ayaga kalkip yurume. Agri artarsa dur.`;
  }

  if (containsAny(text, ["rapor", "yorum", "durusum", "posturum"])) {
    return prefix +
      `${scoreLine}\n\nIlk hedef tek bir skoru kovalamak degil, kotu postur dakikalarini azaltmak. Her 40 dakikada 2 dakika kalkmak genelde iyi bir baslangic olur.`;
  }

  if (containsAny(text, ["boyun", "omuz", "sirt", "bel", "agri", "sizi"])) {
    return prefix +
      `${scoreLine}\n\nBolgeyi zorlamadan, kucuk ve agrisiz aralikta hareket et. Agri yayiliyorsa, uyusma veya guc kaybi varsa fizyoterapist ya da hekime gorun.`;
  }

  return prefix +
    `${scoreLine}\n\nSorunu biraz daha net yazarsan daha iyi yonlendiririm: boyun, omuz/sirt, bel, rapor yorumu veya egzersiz rutini gibi.`;
}

function containsAny(text: string, tokens: string[]) {
  return tokens.some((token) => text.includes(token));
}

function normalizeTurkish(value: string) {
  return value
    .trim()
    .toLocaleLowerCase("tr")
    .replaceAll("ç", "c")
    .replaceAll("ğ", "g")
    .replaceAll("ı", "i")
    .replaceAll("ö", "o")
    .replaceAll("ş", "s")
    .replaceAll("ü", "u");
}
