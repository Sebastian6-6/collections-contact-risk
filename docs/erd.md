# ERD

**Como ver os diagramas:** no [GitHub](https://github.com/Sebastian6-6/collections-contact-risk/blob/main/docs/erd.md); no VS Code 1.121+, pela pré-visualização do Markdown, que desenha Mermaid nativamente; no Cursor e no Antigravity, com a extensão [Markdown Preview Mermaid Support](https://open-vsx.org/extension/bierner/markdown-mermaid), que não deve ser usada no VS Code 1.121+, porque conflita com o nativo.

Diagramas em Mermaid das três camadas do banco. As colunas mostradas são as chaves e alguns atributos; a lista completa está em `models/gold/*/_modelos.yml` e no dicionário de dados.

## Gold: estrela de devedores (`models/gold/devedores`)

`dim_devedor` é o centro: uma linha por CPF. As demais tabelas apontam para ela por `sk_devedor`. Onde o devedor não é encontrado a chave fica `NULL` (não há linha "desconhecido"), por isso a chave estrangeira é opcional (`|o` no desenho) em todas as ligações.

```mermaid
erDiagram
  dim_devedor |o--o{ dim_endereco : "sk_devedor"
  dim_devedor |o--o{ dim_contato : "sk_devedor"
  dim_devedor |o--o{ ft_vinculo_empresa : "sk_devedor"
  dim_devedor |o--o{ ft_tentativa_contato : "sk_devedor"
  dim_empregador |o--o{ ft_vinculo_empresa : "sk_empregador"
  dim_contato |o--o{ ft_tentativa_contato : "sk_contato"

  dim_devedor {
    int sk_devedor PK
    text cpf UK
    text situacao_cpf
    text tipo_conflito_cadastral
    text nome_devedor
    date dt_nascimento
    int qt_provedores
  }
  dim_endereco {
    int sk_endereco PK
    int sk_devedor FK
    text situacao_endereco
    text logradouro
    text cidade
    text uf
    text cep
  }
  dim_contato {
    int sk_contato PK
    int sk_devedor FK
    text cpf
    text tipo_contato
    text contato
    text nivel_risco
    text situacao_compartilhamento
    int qt_tentativas
  }
  dim_empregador {
    int sk_empregador PK
    text cnpj UK
    text situacao_receita
    text desc_natureza_juridica
    text desc_porte
    text desc_situacao_cadastral
    text desc_cnae
  }
  ft_vinculo_empresa {
    int sk_devedor FK
    int sk_empregador FK
    text provedor
    text situacao_vinculo
    text cargo
    numeric vl_renda
    date dt_inicio_vinculo
  }
  ft_tentativa_contato {
    int sk_devedor FK
    int sk_contato FK
    text contato_id UK
    text canal
    text resultado
    text tipo_desfecho
    date dt_tentativa
  }
```

Grãos:

- `dim_devedor`: uma pessoa identificada por um CPF.
- `dim_endereco`: um devedor por endereço padronizado distinto.
- `dim_contato`: um contato normalizado por devedor e documento de origem (`cpf`, `documento_original`, `tipo_contato`, `contato`).
- `dim_empregador`: um CNPJ recebido, com os atributos da Receita por `LEFT JOIN`.
- `ft_vinculo_empresa`: um período contínuo do mesmo conteúdo de vínculo, por documento e provedor.
- `ft_tentativa_contato`: uma tentativa de contato recebida da Cobrança.

## Gold: monitoramento (`models/gold/monitoramento`)

Um fato isolado, sem dimensão: monitora a entrega dos arquivos de cada provedor, e a Cobrança não entra.

```mermaid
erDiagram
  ft_entrega_diaria {
    text provedor PK
    date dt_referencia PK
    text tipo_dia
    int qt_arquivos
    int qt_registros
    numeric qt_media_movel
    numeric tx_variacao_media
    text situacao_volume
    text situacao_cabecalho
  }
```

Grão: um provedor (`alfa`, `beta`, `gama`) por data de referência.

## Visão por camada

Cada fonte tem o seu schema nas três camadas: `bronze_<fonte>`, `silver_<fonte>` e `gold_devedores` e `gold_monitoramento`. A ingestão grava a bronze; a silver trabalha dentro de uma fonte; a gold une as fontes. Os modelos efêmeros (`*_padronizados`) e as etapas internas da gold não aparecem.

### Bronze para silver, por fonte

```mermaid
flowchart LR
  subgraph bronze_alfa
    b_alfa_dev[devedores]
    b_alfa_arq[arquivos]
  end
  subgraph silver_alfa
    s_alfa_hist[devedores_historico]
    s_alfa_dev[devedores]
    s_alfa_con[devedores_contatos]
    s_alfa_end[devedores_enderecos]
  end
  b_alfa_dev --> s_alfa_hist
  b_alfa_arq --> s_alfa_hist
  s_alfa_hist --> s_alfa_dev
  s_alfa_hist --> s_alfa_con
  s_alfa_hist --> s_alfa_end

  subgraph bronze_beta
    b_beta_dev[devedores]
    b_beta_arq[arquivos]
  end
  subgraph silver_beta
    s_beta_hist[devedores_historico]
    s_beta_hc[devedores_historico_contatos]
    s_beta_he[devedores_historico_enderecos]
    s_beta_dev[devedores]
    s_beta_con[devedores_contatos]
    s_beta_end[devedores_enderecos]
  end
  b_beta_dev --> s_beta_hist
  b_beta_arq --> s_beta_hist
  s_beta_hist --> s_beta_hc
  s_beta_hist --> s_beta_he
  s_beta_hist --> s_beta_dev
  s_beta_hist --> s_beta_con
  s_beta_hist --> s_beta_end
  s_beta_hc --> s_beta_con
  s_beta_he --> s_beta_end

  subgraph bronze_gama
    b_gama_dev[devedores]
    b_gama_arq[arquivos]
  end
  subgraph silver_gama
    s_gama_hist[devedores_historico]
    s_gama_hc[devedores_historico_contatos]
    s_gama_dev[devedores]
    s_gama_con[devedores_contatos]
    s_gama_end[devedores_enderecos]
  end
  b_gama_dev --> s_gama_hist
  b_gama_arq --> s_gama_hist
  s_gama_hist --> s_gama_hc
  s_gama_hist --> s_gama_dev
  s_gama_hist --> s_gama_con
  s_gama_hc --> s_gama_con
  s_gama_hist --> s_gama_end

  subgraph bronze_cobranca
    b_cob[contatos_realizados]
  end
  subgraph silver_cobranca
    s_cob[contatos_realizados]
    s_cob_prov[contatos_realizados_provedores]
  end
  b_cob --> s_cob
  s_cob --> s_cob_prov
```

### Receita (dados abertos)

A Receita é uma fonte como as outras. As tabelas de domínio passam para a silver sem derivar de outra tabela.

```mermaid
flowchart LR
  subgraph bronze_receita
    b_emp[empresas]
    b_est[estabelecimentos]
    b_sim[simples]
    b_soc[socios]
    b_dom["cnaes, motivos, municipios,<br/>naturezas, paises, qualificacoes"]
  end
  subgraph silver_receita
    s_emp[empresas]
    s_est[estabelecimentos]
    s_cs[estabelecimentos_cnaes_secundarios]
    s_sim[simples]
    s_soc[socios]
    s_dom["cnaes, motivos, municipios,<br/>naturezas, paises, qualificacoes"]
  end
  b_emp --> s_emp
  b_est --> s_est
  s_est --> s_cs
  b_sim --> s_sim
  b_soc --> s_soc
  b_dom --> s_dom
```

### Silver para gold

```mermaid
flowchart LR
  subgraph silver
    s_alfa["silver_alfa<br/>(devedores, contatos, enderecos, historico)"]
    s_beta["silver_beta<br/>(devedores, contatos, enderecos, historico)"]
    s_gama["silver_gama<br/>(devedores, contatos, enderecos, historico)"]
    s_cob["silver_cobranca<br/>(contatos_realizados)"]
    s_rec["silver_receita<br/>(estabelecimentos, empresas, simples, dominios)"]
  end
  subgraph bronze
    b_prov["bronze_alfa, bronze_beta, bronze_gama<br/>(devedores, arquivos)"]
  end
  subgraph gold
    d_dev[dim_devedor]
    d_end[dim_endereco]
    d_con[dim_contato]
    d_emp[dim_empregador]
    f_vin[ft_vinculo_empresa]
    f_ten[ft_tentativa_contato]
    f_ent[ft_entrega_diaria]
  end
  s_alfa --> d_dev
  s_beta --> d_dev
  s_gama --> d_dev
  s_alfa --> d_end
  s_beta --> d_end
  s_gama --> d_end
  s_alfa --> d_con
  s_beta --> d_con
  s_gama --> d_con
  s_cob --> d_con
  s_cob --> f_ten
  s_alfa --> f_vin
  s_beta --> f_vin
  s_gama --> f_vin
  s_alfa --> d_emp
  s_beta --> d_emp
  s_gama --> d_emp
  s_rec --> d_emp
  d_dev --> d_end
  d_dev --> f_vin
  d_emp --> f_vin
  d_dev --> f_ten
  d_con --> f_ten
  b_prov --> f_ent
```
