"""Testes do gerador do dicionário de dados a partir do manifest e do catalog do dbt."""

from scripts.gerar_dicionario import gerar_markdown, juntar_tabelas

MANIFEST = {
    "nodes": {
        "model.p.gold_dim": {
            "resource_type": "model",
            "description": "Dimensão de devedores.",
            "columns": {"sk_devedor": {"description": "Chave | substituta."}},
        },
        "model.p.silver_alfa_x": {
            "resource_type": "model",
            "description": "",
            "columns": {},
        },
    },
    "sources": {
        "source.p.bronze_alfa.x": {
            "description": "Bruto.",
            "columns": {"_arquivo": {"description": "Caminho do arquivo."}},
        }
    },
}

CATALOG = {
    "nodes": {
        "model.p.gold_dim": {
            "metadata": {"schema": "gold", "name": "dim_devedor"},
            "columns": {
                "num_cpf": {"index": 2, "type": "VARCHAR"},
                "sk_devedor": {"index": 1, "type": "INTEGER"},
            },
        },
        "model.p.silver_alfa_x": {
            "metadata": {"schema": "silver_alfa", "name": "x"},
            "columns": {"a": {"index": 1, "type": "DATE"}},
        },
    },
    "sources": {
        "source.p.bronze_alfa.x": {
            "metadata": {"schema": "bronze_alfa", "name": "x"},
            "columns": {"_arquivo": {"index": 1, "type": "VARCHAR"}},
        }
    },
}


def test_junta_por_camada_e_ordena_colunas_pelo_indice():
    tabelas = juntar_tabelas(MANIFEST, CATALOG)
    assert [(t["schema"], t["nome"]) for t in tabelas] == [
        ("bronze_alfa", "x"),
        ("silver_alfa", "x"),
        ("gold", "dim_devedor"),
    ]
    gold = tabelas[2]
    assert [c["nome"] for c in gold["colunas"]] == ["sk_devedor", "num_cpf"]
    assert gold["colunas"][0]["tipo"] == "INTEGER"


def test_markdown_escapa_barra_e_marca_coluna_sem_descricao():
    texto = gerar_markdown(juntar_tabelas(MANIFEST, CATALOG), "Abertura.")
    assert texto.startswith("# Dicionário de dados")
    assert "Abertura." in texto
    assert r"Chave \| substituta." in texto
    assert "| `num_cpf` | `VARCHAR` | sem descrição |" in texto
    assert "## Camada gold" in texto
    assert "### `gold.dim_devedor`" in texto
