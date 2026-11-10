{#
  Padronização de documento. Cada macro recebe uma expressão SQL (normalmente o nome de uma coluna
  de texto) e devolve uma expressão. Só ajustam o formato: nenhuma decide regra de negócio nem
  filtra linha. Entrada vazia, sem nenhum caractere útil ou só com zeros devolve NULL: um documento
  que não identifica ninguém é ausência de chave, não um valor (ausência é NULL, nunca zero).
  Só usam funções que existem com o mesmo comportamento no DuckDB e no PostgreSQL.
#}

{#
  Só os dígitos 0-9 do texto; NULL quando não sobra nenhum.
  Entrada '123.456.789-09' -> '12345678909'. Entrada '' ou 'abc' -> NULL.
#}
{% macro somente_digitos(expressao) -%}
  NULLIF(REGEXP_REPLACE(CAST({{ expressao }} AS VARCHAR), '[^0-9]', '', 'g'), '')
{%- endmacro %}

{#
  NULL quando o texto só tem zeros ('0', '000', '00000000000'); senão o próprio texto. Documento
  zerado é o preenchimento de quem não tem o dado: tratá-lo como valor juntaria pessoas
  diferentes sob a mesma chave.
#}
{% macro nulo_se_so_zeros(expressao) -%}
  CASE WHEN {{ expressao }} ~ '^0+$' THEN CAST(NULL AS VARCHAR) ELSE {{ expressao }} END
{%- endmacro %}

{#
  CPF só com dígitos, com os zeros à esquerda repostos até 11 posições (o alfa perde zeros:
  '1006543201' -> '01006543201'). Documento vazio ou só com zeros ('0', '000.000.000-00') dá NULL.
  Mais de 11 dígitos ficam como estão, sem truncar, para o teste de qualidade enxergar o valor.
  Não verifica o dígito verificador (ver `cpf_valido`) e não distingue CPF de outro documento: um
  RG do beta não deve passar por aqui.
#}
{% macro cpf_normalizado(expressao) -%}
  {%- set digitos = somente_digitos(expressao) -%}
  CASE
    WHEN {{ digitos }} ~ '^0+$' THEN CAST(NULL AS VARCHAR)
    WHEN LENGTH({{ digitos }}) <= 11 THEN LPAD({{ digitos }}, 11, '0')
    ELSE {{ digitos }}
  END
{%- endmacro %}

{#
  Soma ponderada dos 12 primeiros caracteres do texto, para o dígito verificador do CNPJ. Cada
  caractere vale o código ASCII menos 48 ('0' a '9' valem 0 a 9; 'A' a 'Z' valem 17 a 42), como
  no cálculo oficial do CNPJ alfanumérico. `pesos` tem um peso por posição. Uso interno de
  `cnpj_digitos_verificadores`.
#}
{% macro cnpj_soma_ponderada(texto, pesos) -%}
  {%- set termos = [] -%}
  {%- for peso in pesos -%}
    {%- do termos.append("(ASCII(SUBSTRING(" ~ texto ~ ", " ~ loop.index ~ ", 1)) - 48) * " ~ peso) -%}
  {%- endfor -%}
  ({{ termos | join(' + ') }})
{%- endmacro %}

{#
  Os dois dígitos verificadores do CNPJ dos 12 primeiros caracteres do texto, como texto de 2
  caracteres. Regra oficial da Receita Federal (manual do dígito verificador do CNPJ): cada
  caractere vale ASCII - 48; os pesos vão de 2 a 9 da direita para a esquerda e recomeçam em 2
  depois do 9; resto da divisão da soma por 11 igual a 0 ou 1 dá dígito 0, senão o dígito é 11
  menos o resto. O segundo dígito usa os 12 caracteres mais o primeiro dígito.
  Fonte: https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/documentos-tecnicos/cnpj/manual-dv-cnpj.pdf
  Conferido com 00.000.000/0001-91 (dígitos 91) e com o exemplo alfanumérico do manual
  12.ABC.345/01DE-35 (dígitos 35). Só usa ASCII, SUBSTRING, CASE e o resto inteiro (%), que existem
  nos dois motores.
#}
{% macro cnpj_digitos_verificadores(texto) -%}
  {%- set soma1 = cnpj_soma_ponderada(texto, [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) -%}
  {%- set digito1 = "(CASE WHEN " ~ soma1 ~ " % 11 < 2 THEN 0 ELSE 11 - " ~ soma1 ~ " % 11 END)" -%}
  {%- set soma2 = "(" ~ cnpj_soma_ponderada(texto, [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3]) ~ " + " ~ digito1 ~ " * 2)" -%}
  CAST({{ digito1 }} AS VARCHAR) || CAST(CASE WHEN {{ soma2 }} % 11 < 2 THEN 0 ELSE 11 - {{ soma2 }} % 11 END AS VARCHAR)
{%- endmacro %}

{#
  O texto é um CNPJ de 14 caracteres com os dígitos verificadores certos? BOOLEAN; NULL quando o
  texto é NULL. Os 12 primeiros caracteres são números ou letras maiúsculas e os 2 últimos, números.
  Recebe o CNPJ já sem máscara. Só informa: não filtra.
#}
{% macro cnpj_valido(expressao) -%}
  {%- set cnpj = "CAST(" ~ expressao ~ " AS VARCHAR)" -%}
  CASE
    WHEN {{ cnpj }} IS NULL THEN CAST(NULL AS BOOLEAN)
    WHEN {{ cnpj }} !~ '^[0-9A-Z]{12}[0-9]{2}$' THEN FALSE
    ELSE SUBSTRING({{ cnpj }}, 13, 2) = {{ cnpj_digitos_verificadores(cnpj) }}
  END
{%- endmacro %}

{#
  CNPJ só com letras e dígitos, em maiúsculas, sem máscara (aceita o formato alfanumérico,
  A7K2M9Q4000140); NULL quando não sobra nenhum caractere. É o passo que vem antes de
  `cnpj_normalizado`, que recebe esse resultado.
#}
{% macro cnpj_sem_mascara(expressao) -%}
  NULLIF(REGEXP_REPLACE(UPPER(CAST({{ expressao }} AS VARCHAR)), '[^0-9A-Z]', '', 'g'), '')
{%- endmacro %}

{#
  CNPJ do empregador padronizado, a partir do CNPJ já sem máscara (`cnpj_sem_mascara`, aplicado
  numa etapa anterior: o macro repete a expressão que recebe, e repetir a limpeza dezenas de vezes
  custaria o dobro do tempo e deixaria a consulta com 29 mil caracteres). Vazio dá NULL. Depois:
    1. 14 caracteres: fica como veio (a validade dos dígitos é conferida por teste, não aqui);
    2. menos de 14: completa com zeros à esquerda até 14 se o resultado tiver dígitos verificadores
       válidos ('191' -> '00000000000191'; '4182736500157' -> '04182736500157');
    3. exatamente 12 e a regra anterior não deu um CNPJ válido: o valor é a base sem os dois
       dígitos, que são calculados pela regra oficial (`cnpj_digitos_verificadores`);
    4. qualquer outro valor (mais de 14 caracteres, ou menos de 14 sem regra que o complete) fica
       como veio: é limitação da base, e nenhuma regra adivinha o CNPJ.
  Completar e calcular não inventam um empregador: só recompõem o que a origem escreveu sem os
  zeros à esquerda ou sem os dígitos verificadores.
#}
{% macro cnpj_normalizado(expressao) -%}
  {%- set limpo = expressao -%}
  {%- set completo = "LPAD(" ~ limpo ~ ", 14, '0')" -%}
  CASE
    WHEN LENGTH({{ limpo }}) = 14 THEN {{ limpo }}
    WHEN LENGTH({{ limpo }}) < 14 AND {{ cnpj_valido(completo) }} THEN {{ completo }}
    WHEN LENGTH({{ limpo }}) = 12 THEN {{ limpo }} || {{ cnpj_digitos_verificadores(limpo) }}
    ELSE {{ limpo }}
  END
{%- endmacro %}

{#
  Validade do dígito verificador do CPF, devolvendo BOOLEAN. Recebe um CPF já normalizado
  (`cpf_normalizado`). NULL quando a entrada é NULL; FALSE quando não tem 11 dígitos, quando
  todos os dígitos são iguais ou quando os dígitos verificadores não batem. Só informa: não filtra.
#}
{% macro cpf_valido(expressao) -%}
  {%- set cpf = "CAST(" ~ expressao ~ " AS VARCHAR)" -%}
  {%- set soma1 = [] -%}
  {%- for i in range(1, 10) -%}
    {%- do soma1.append("CAST(SUBSTRING(" ~ cpf ~ ", " ~ i ~ ", 1) AS INTEGER) * " ~ (11 - i)) -%}
  {%- endfor -%}
  {%- set soma2 = [] -%}
  {%- for i in range(1, 11) -%}
    {%- do soma2.append("CAST(SUBSTRING(" ~ cpf ~ ", " ~ i ~ ", 1) AS INTEGER) * " ~ (12 - i)) -%}
  {%- endfor -%}
  CASE
    WHEN {{ cpf }} IS NULL THEN CAST(NULL AS BOOLEAN)
    WHEN {{ cpf }} !~ '^[0-9]{11}$' THEN FALSE
    WHEN {{ cpf }} = REPEAT(SUBSTRING({{ cpf }}, 1, 1), 11) THEN FALSE
    ELSE
      (({{ soma1 | join(' + ') }}) * 10) % 11 % 10 = CAST(SUBSTRING({{ cpf }}, 10, 1) AS INTEGER)
      AND (({{ soma2 | join(' + ') }}) * 10) % 11 % 10 = CAST(SUBSTRING({{ cpf }}, 11, 1) AS INTEGER)
  END
{%- endmacro %}
