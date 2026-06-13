-- View completa para o dashboard: junta leads + última mensagem + janela 24h + pagamento
CREATE OR REPLACE VIEW leads_dashboard AS
SELECT
  le.messenger_id,
  le.nome,
  le.etapa_atual,
  le.status,
  le.canal,
  le.ultima_interacao,
  le.remarketing_count,
  le.ultimo_remarketing_em,
  le.proxima_envio_em,
  lm.ultima_msg,
  lm.ultima_msg_conteudo,
  lm.ultima_msg_tipo,
  lm.ultima_msg_direcao,
  lr.ultima_msg_recebida,
  COALESCE(cnt.total_mensagens, 0) AS total_mensagens,
  COALESCE(cnt.nao_lidas, 0) AS nao_lidas,
  COALESCE(pg.reivindicou_pagamento, false) AS reivindicou_pagamento
FROM leads_estado le
LEFT JOIN LATERAL (
  SELECT m.criado_em AS ultima_msg, m.conteudo AS ultima_msg_conteudo,
         m.tipo AS ultima_msg_tipo, m.direcao AS ultima_msg_direcao
  FROM mensagens m
  WHERE m.messenger_id = le.messenger_id
  ORDER BY m.criado_em DESC
  LIMIT 1
) lm ON true
LEFT JOIN LATERAL (
  SELECT MAX(m.criado_em) AS ultima_msg_recebida
  FROM mensagens m
  WHERE m.messenger_id = le.messenger_id AND m.direcao = 'recebida'
) lr ON true
LEFT JOIN LATERAL (
  SELECT COUNT(*) AS total_mensagens,
         COUNT(*) FILTER (WHERE m.direcao = 'recebida') AS nao_lidas
  FROM mensagens m
  WHERE m.messenger_id = le.messenger_id
) cnt ON true
LEFT JOIN LATERAL (
  SELECT EXISTS(
    SELECT 1 FROM mensagens m
    WHERE m.messenger_id = le.messenger_id AND m.direcao = 'recebida'
      AND (
        m.conteudo ILIKE '%paguei%' OR m.conteudo ILIKE '%ja paguei%' OR
        m.conteudo ILIKE '%fiz o pix%' OR m.conteudo ILIKE '%fiz o pagamento%' OR
        m.conteudo ILIKE '%comprovante%' OR m.conteudo ILIKE '%transferi%' OR
        m.conteudo ILIKE '%pagamento realizado%' OR m.conteudo ILIKE '%pix feito%' OR
        m.conteudo ILIKE '%pix enviado%' OR m.conteudo ILIKE '%acabei de pagar%'
      )
  ) AS reivindicou_pagamento
) pg ON true
WHERE le.canal = 'whatsapp';

GRANT SELECT ON leads_dashboard TO anon, authenticated;

-- recarrega o cache do PostgREST para a view aparecer na API
NOTIFY pgrst, 'reload schema';
