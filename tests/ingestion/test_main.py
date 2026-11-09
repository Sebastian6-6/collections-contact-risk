"""Ingestão: lê tudo o que foi recebido e grava na bronze uma linha por linha recebida."""

import hashlib

import pytest
from apoio import entidade, faltam_linhas

from ingestion import conectores, leitores
from ingestion.leitores import Leitura, LinhaLida

COLUNAS_DE_RASTREABILIDADE = [
    "_arquivo",
    "_linha",
    "_hash_arquivo",
    "_linha_original",
    "_motivo_ilegivel",
]


def _config_simples(projeto, formato="csv", padrao="*.csv"):
    projeto.configurar({"fonte": {"pessoas": entidade(formato, ("dados", padrao))}})


def test_grava_uma_linha_por_linha_recebida_com_a_rastreabilidade(projeto):
    conteudo = "id,nome\n1,Ana\n2,\n"
    projeto.escrever("dados/a.csv", conteudo)
    _config_simples(projeto)

    assert projeto.rodar() == 0

    linhas = projeto.consultar("SELECT * FROM bronze_fonte.pessoas ORDER BY _linha")
    assert list(linhas[0]) == ["id", "nome", *COLUNAS_DE_RASTREABILIDADE]
    assert linhas == [
        {
            "id": "1", "nome": "Ana", "_arquivo": "dados/a.csv", "_linha": 2,
            "_hash_arquivo": hashlib.sha256(conteudo.encode()).hexdigest(),
            "_linha_original": "1,Ana", "_motivo_ilegivel": None,
        },
        {
            "id": "2", "nome": "", "_arquivo": "dados/a.csv", "_linha": 3,
            "_hash_arquivo": hashlib.sha256(conteudo.encode()).hexdigest(),
            "_linha_original": "2,", "_motivo_ilegivel": None,
        },
    ]  # fmt: skip


def test_o_registro_de_arquivos_diz_o_que_foi_lido(projeto):
    conteudo = "id,nome\n1,Ana\n2,Beto\n"
    projeto.escrever("dados/a.csv", conteudo)
    _config_simples(projeto)

    projeto.rodar()

    assert projeto.consultar("SELECT * FROM bronze_fonte.arquivos") == [
        {
            "arquivo": "dados/a.csv",
            "entidade": "pessoas",
            "hash_arquivo": hashlib.sha256(conteudo.encode()).hexdigest(),
            "bytes": len(conteudo.encode()),
            "linhas": 2,
            "cabecalho": "id,nome",
        }
    ]


def test_o_registro_de_arquivos_bate_com_as_linhas_da_tabela_por_arquivo(projeto):
    projeto.escrever("dados/a.csv", 'id,nome\n1,Ana\n2,"Be\n')
    projeto.escrever("dados/b.csv", 'id,nome\n3,"Caio\nCosta"\n\n4,Dani\n')
    projeto.escrever("dados/c.csv", "id,nome\n")
    _config_simples(projeto)

    projeto.rodar()

    divergencias = projeto.consultar(
        """
        SELECT a.arquivo, a.linhas AS no_registro, COUNT(t._arquivo) AS na_tabela
        FROM bronze_fonte.arquivos AS a
        LEFT JOIN bronze_fonte.pessoas AS t ON t._arquivo = a.arquivo
        GROUP BY a.arquivo, a.linhas
        HAVING a.linhas <> COUNT(t._arquivo)
        """
    )
    assert divergencias == []
    assert projeto.consultar("SELECT SUM(linhas) AS n FROM bronze_fonte.arquivos") == [{"n": 5}]


def test_toda_linha_fisica_do_arquivo_fica_coberta(projeto):
    texto = 'id,nome\r\n1,Ana\r\n2,"Be\r\nto"\r\n\r\n3,"trunc\r\n'
    projeto.escrever("dados/a.csv", texto)
    _config_simples(projeto)

    projeto.rodar()

    registros = projeto.consultar("SELECT _linha, _linha_original FROM bronze_fonte.pessoas")
    assert faltam_linhas(registros, "id,nome", texto) is None


def test_arquivo_so_com_cabecalho_e_registrado_com_zero_linhas(projeto):
    projeto.escrever("dados/a.csv", "id,nome\n1,Ana\n")
    projeto.escrever("dados/b.csv", "id,nome\n")
    _config_simples(projeto)

    projeto.rodar()

    assert projeto.consultar(
        "SELECT arquivo, linhas, cabecalho FROM bronze_fonte.arquivos ORDER BY arquivo"
    ) == [
        {"arquivo": "dados/a.csv", "linhas": 1, "cabecalho": "id,nome"},
        {"arquivo": "dados/b.csv", "linhas": 0, "cabecalho": "id,nome"},
    ]


def test_entidade_so_com_arquivos_sem_linhas_cria_a_tabela_vazia(projeto):
    projeto.escrever("dados/a.csv", "id,nome\n")
    _config_simples(projeto)

    assert projeto.rodar() == 0

    assert projeto.consultar("SELECT COUNT(*) AS n FROM bronze_fonte.pessoas") == [{"n": 0}]


def test_csv_malformado_fica_com_o_texto_e_o_motivo(projeto):
    projeto.escrever("dados/a.csv", 'id,nome\n1,Ana\n2,"Be\n')
    _config_simples(projeto)

    projeto.rodar()

    linhas = projeto.consultar("SELECT * FROM bronze_fonte.pessoas ORDER BY _linha")
    assert [(x["id"], x["nome"]) for x in linhas] == [("1", "Ana"), (None, None)]
    assert linhas[1]["_linha_original"] == '2,"Be'
    assert "malformado" in linhas[1]["_motivo_ilegivel"]
    assert linhas[0]["_motivo_ilegivel"] is None


def test_jsonl_invalido_entra_como_texto_na_coluna_registro(projeto):
    projeto.escrever("dados/a.jsonl", '{"a": 1}\n{"a": "trunc\n')
    _config_simples(projeto, formato="jsonl", padrao="*.jsonl")

    assert projeto.rodar() == 0

    linhas = projeto.consultar("SELECT * FROM bronze_fonte.pessoas ORDER BY _linha")
    assert list(linhas[0]) == ["registro", *COLUNAS_DE_RASTREABILIDADE]
    assert [x["registro"] for x in linhas] == ['{"a": 1}', '{"a": "trunc']
    assert [x["_motivo_ilegivel"] for x in linhas] == [None, None]
    cabecalhos = projeto.consultar("SELECT cabecalho FROM bronze_fonte.arquivos")
    assert cabecalhos == [{"cabecalho": None}]


def test_byte_fora_do_encoding_interrompe_a_fonte_com_o_arquivo_e_a_linha(projeto, capsys):
    projeto.escrever("dados/a.csv", b"id,nome\n1,Ana\n2,Jos\xe9\n")
    projeto.escrever("outros/b.csv", "id\n7\n")
    projeto.configurar(
        {
            "ruim": {"pessoas": entidade("csv", ("dados", "*.csv"))},
            "boa": {"pessoas": entidade("csv", ("outros", "*.csv"))},
        }
    )

    assert projeto.rodar() == 1

    saida = capsys.readouterr().out
    assert "a.csv" in saida
    assert "linha 3" in saida
    esquemas = projeto.esquemas()
    assert "bronze_ruim" not in esquemas
    assert projeto.consultar("SELECT id FROM bronze_boa.pessoas") == [{"id": "7"}]


def test_une_os_cabecalhos_de_todos_os_arquivos_da_entidade(projeto):
    projeto.escrever("dados/a1.csv", "cpf,nome\n111,Ana\n")
    projeto.escrever("dados/a2.csv", "documento,nome,cargo\n222,Beto,Chefe\n")
    _config_simples(projeto)

    projeto.rodar()

    linhas = projeto.consultar("SELECT * FROM bronze_fonte.pessoas ORDER BY _arquivo")
    assert list(linhas[0])[:4] == ["cpf", "nome", "documento", "cargo"]
    assert [(x["cpf"], x["documento"], x["nome"], x["cargo"]) for x in linhas] == [
        ("111", None, "Ana", None),
        (None, "222", "Beto", "Chefe"),
    ]


def test_historico_e_entregas_de_locais_diferentes_vao_para_a_mesma_tabela(projeto):
    projeto.escrever("dados/historico.csv", "id\n1\n")
    projeto.escrever("dados/entregas/dia_2026-09-01.csv", "id\n2\n")
    projeto.escrever("dados/entregas/dia_2026-09-02.csv", "id\n3\n")
    projeto.configurar(
        {
            "fonte": {
                "pessoas": entidade(
                    "csv", ("dados", "historico.csv"), ("dados/entregas", "dia_*.csv")
                )
            }
        }
    )

    assert projeto.rodar() == 0

    linhas = projeto.consultar("SELECT _arquivo, id FROM bronze_fonte.pessoas ORDER BY _arquivo")
    assert linhas == [
        {"_arquivo": "dados/entregas/dia_2026-09-01.csv", "id": "2"},
        {"_arquivo": "dados/entregas/dia_2026-09-02.csv", "id": "3"},
        {"_arquivo": "dados/historico.csv", "id": "1"},
    ]


def test_arquivo_que_casa_com_duas_entradas_gera_erro_e_nao_carrega_nada(projeto, capsys):
    projeto.escrever("dados/a.csv", "id\n1\n")
    projeto.configurar(
        {
            "fonte": {
                "uma": entidade("csv", ("dados", "a.csv")),
                "outra": entidade("csv", ("dados", "*.csv")),
            }
        }
    )

    assert projeto.rodar() == 1

    saida = capsys.readouterr().out
    assert "dados/a.csv" in saida
    assert "mais de uma" in saida
    assert not projeto.banco.exists()


def test_entidade_sem_arquivo_e_erro_e_nao_silencio(projeto, capsys):
    projeto.escrever("dados/a.txt", "x")
    _config_simples(projeto)

    assert projeto.rodar() == 1
    assert "nenhum arquivo" in capsys.readouterr().out


def test_pasta_inexistente_e_erro(projeto, capsys):
    _config_simples(projeto)

    assert projeto.rodar() == 1
    assert "dados" in capsys.readouterr().out


def test_pasta_fora_da_raiz_e_erro(projeto, tmp_path, capsys):
    (tmp_path / "raiz").mkdir()
    (tmp_path / "fora").mkdir()
    (tmp_path / "fora" / "a.csv").write_text("id\n1\n", encoding="utf-8")
    projeto.configurar({"fonte": {"pessoas": entidade("csv", ("../fora", "*.csv"))}})
    projeto.raiz = tmp_path / "raiz"

    assert projeto.rodar() == 1
    assert "fora da raiz" in capsys.readouterr().out


def test_coluna_com_nome_de_rastreabilidade_e_erro(projeto, capsys):
    projeto.escrever("dados/a.csv", "id,_linha\n1,2\n")
    _config_simples(projeto)

    assert projeto.rodar() == 1
    assert "_linha" in capsys.readouterr().out


def test_leitor_novo_funciona_sem_mexer_no_main(projeto, monkeypatch):
    monkeypatch.setattr(leitores, "LEITORES", dict(leitores.LEITORES))

    @leitores.leitor("psv")
    def ler_psv(caminho, encoding, separador):
        textos = caminho.read_text(encoding=encoding).splitlines()
        cabecalho, *registros = textos
        colunas = cabecalho.split("|")
        linhas = [
            LinhaLida(numero, texto, dict(zip(colunas, texto.split("|"), strict=True)), None)
            for numero, texto in enumerate(registros, start=2)
        ]
        return Leitura(colunas=colunas, cabecalho=cabecalho, linhas=linhas)

    projeto.escrever("dados/a.psv", "id|nome\n1|Ana\n")
    _config_simples(projeto, formato="psv", padrao="*.psv")

    assert projeto.rodar() == 0
    assert projeto.consultar("SELECT id, nome FROM bronze_fonte.pessoas") == [
        {"id": "1", "nome": "Ana"}
    ]


def test_conector_novo_funciona_sem_mexer_no_main(projeto, monkeypatch):
    monkeypatch.setattr(conectores, "CONECTORES", dict(conectores.CONECTORES))

    @conectores.conector("fixo")
    def listar_fixo(local, raiz):
        return [raiz / local.caminho / "z.csv", raiz / local.caminho / "a.csv"]

    projeto.escrever("dados/a.csv", "id\n1\n")
    projeto.escrever("dados/z.csv", "id\n2\n")
    projeto.configurar(
        {"fonte": {"pessoas": {**entidade("csv", ("dados", "ignorado")), "origem": "fixo"}}}
    )

    assert projeto.rodar() == 0
    assert projeto.consultar("SELECT id FROM bronze_fonte.pessoas ORDER BY _arquivo") == [
        {"id": "1"},
        {"id": "2"},
    ]


def test_separador_e_encoding_vem_da_configuracao(projeto):
    projeto.escrever("dados/a.csv", "id;nome\n1;João\n".encode("latin-1"))
    projeto.configurar(
        {
            "fonte": {
                "pessoas": entidade(
                    "csv", ("dados", "*.csv"), encoding="latin-1", separador=";"
                )
            }
        }
    )

    assert projeto.rodar() == 0
    assert projeto.consultar("SELECT nome FROM bronze_fonte.pessoas") == [{"nome": "João"}]


def test_fonte_escolhida_na_linha_de_comando_carrega_so_ela(projeto):
    projeto.escrever("dados/a.csv", "id\n1\n")
    projeto.configurar(
        {
            "uma": {"pessoas": entidade("csv", ("dados", "*.csv"))},
            "outra": {"pessoas": entidade("csv", ("dados", "*.csv"))},
        }
    )

    assert projeto.rodar("--fonte", "uma") == 0

    esquemas = projeto.esquemas()
    assert "bronze_uma" in esquemas
    assert "bronze_outra" not in esquemas


def test_fonte_que_nao_existe_diz_quais_existem(projeto, capsys):
    _config_simples(projeto)

    assert projeto.rodar("--fonte", "nenhuma") == 1
    assert "fonte" in capsys.readouterr().out


def _com(**campos) -> dict:
    """Uma fonte válida com os campos da entidade trocados, para testar um erro de cada vez."""
    return {"fonte": {"pessoas": {**entidade("csv", ("dados", "*")), **campos}}}


@pytest.mark.parametrize(
    ("fontes", "trecho"),
    [
        ({"fonte": {"pessoas": {"origem": "pasta", "formato": "csv"}}}, "ausente(s): arquivos"),
        (_com(modo_carga="full"), "modo_carga"),
        (_com(formato="xml"), "xml"),
        (_com(origem="ftp"), "ftp"),
        (_com(arquivos=[]), "ao menos um local"),
        (_com(arquivos=[{"caminho": "d"}]), "'caminho' e 'padrao'"),
        (_com(encoding="nao-existe"), "nao-existe"),
        (_com(separador=";;"), "separador"),
        ({"fonte": {"arquivos": entidade("csv", ("dados", "*"))}}, "registro de cargas"),
        ({"Fonte Ruim": {"pessoas": entidade("csv", ("dados", "*"))}}, "Fonte Ruim"),
    ],
)
def test_configuracao_invalida_diz_qual_campo_e_nao_carrega_nada(projeto, capsys, fontes, trecho):
    projeto.configurar(fontes)

    assert projeto.rodar() == 1
    assert trecho in capsys.readouterr().out
    assert not projeto.banco.exists()


def test_duas_execucoes_geram_tabelas_identicas(projeto, tmp_path):
    projeto.escrever("dados/a.csv", 'id,nome\n1,Ana\n2,"Be\nto"\n3\n')
    projeto.escrever("dados/b.csv", "documento,nome\n9,Caio\n")
    projeto.escrever("dados/c.jsonl", '{"a": 1}\n{"a": "x\n')
    projeto.configurar(
        {
            "fonte": {
                "pessoas": entidade("csv", ("dados", "*.csv")),
                "eventos": entidade("jsonl", ("dados", "*.jsonl")),
            }
        }
    )

    projeto.rodar()
    primeira = _tudo(projeto)
    projeto.rodar()
    mesmo_banco = _tudo(projeto)
    projeto.banco = tmp_path / "outro.duckdb"
    projeto.rodar()
    outro_banco = _tudo(projeto)

    assert primeira
    assert mesmo_banco == primeira
    assert outro_banco == primeira


def test_nenhuma_tabela_guarda_caminho_absoluto_nem_horario(projeto, tmp_path):
    projeto.escrever("dados/a.csv", "id\n1\n")
    _config_simples(projeto)

    projeto.rodar()

    tabelas = _tudo(projeto)
    assert str(tmp_path) not in repr(tabelas)
    colunas = projeto.consultar(
        "SELECT column_name FROM duckdb_columns() WHERE schema_name LIKE 'bronze_%'"
    )
    nomes = [c["column_name"] for c in colunas]
    assert not [n for n in nomes if "process_time" in n or "hora" in n]


def _tudo(projeto) -> dict[str, list[tuple]]:
    """Todas as tabelas da bronze, com as linhas em ordem fixa, para comparar execuções."""
    tabelas = projeto.consultar(
        "SELECT schema_name, table_name FROM duckdb_tables() "
        "WHERE schema_name LIKE 'bronze_%' ORDER BY ALL"
    )
    return {
        f"{t['schema_name']}.{t['table_name']}": [
            tuple(linha.items())
            for linha in projeto.consultar(
                f"SELECT * FROM {t['schema_name']}.{t['table_name']} ORDER BY ALL"
            )
        ]
        for t in tabelas
    }
