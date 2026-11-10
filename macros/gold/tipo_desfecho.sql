{#
  Classe do desfecho de uma tentativa de contato (G2b), a partir do `resultado` da Cobrança. Fonte
  única das classes, usada pela régua (`dim_contato`) e pelo fato de tentativas:
    - `contato_confirmado`: `pagamento`, `promessa_pagamento`, `reclamacao` (a reclamação confirma
      que a pessoa certa foi alcançada);
    - `terceiro`: `numero_errado`, `nao_conhece_devedor`;
    - `opt_out`: `opt_out`;
    - `falecido`: `falecido`;
    - `sem_confirmacao`: `entregue`, `lido`, `sem_resposta` (`lido` não confirma quem leu).
  Um `resultado` fora da lista devolve NULL, e o teste `accepted_values` da `ft_tentativa_contato`
  reprova: o valor novo não cai numa classe por acaso.
#}
{% macro tipo_desfecho(resultado) -%}
  CASE
    WHEN {{ resultado }} IN ('pagamento', 'promessa_pagamento', 'reclamacao')
      THEN 'contato_confirmado'
    WHEN {{ resultado }} IN ('numero_errado', 'nao_conhece_devedor') THEN 'terceiro'
    WHEN {{ resultado }} = 'opt_out' THEN 'opt_out'
    WHEN {{ resultado }} = 'falecido' THEN 'falecido'
    WHEN {{ resultado }} IN ('entregue', 'lido', 'sem_resposta') THEN 'sem_confirmacao'
  END
{%- endmacro %}
