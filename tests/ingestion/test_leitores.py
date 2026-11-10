"""Leitores: cada linha recebida vira um registro, e a ilegível guarda o motivo."""

import pytest

from ingestion import ErroDeIngestao, leitores
from ingestion.leitores import Leitura, ler_csv, ler_jsonl, obter_leitor


def _csv(tmp_path, conteudo: bytes | str):
    arquivo = tmp_path / "dados.csv"
    arquivo.write_bytes(conteudo if isinstance(conteudo, bytes) else conteudo.encode())
    return ler_csv(arquivo, encoding="utf-8", separador=",")


def _jsonl(tmp_path, conteudo: bytes | str):
    arquivo = tmp_path / "dados.jsonl"
    arquivo.write_bytes(conteudo if isinstance(conteudo, bytes) else conteudo.encode())
    return ler_jsonl(arquivo, encoding="utf-8", separador=",")


def test_csv_le_colunas_do_proprio_arquivo_em_texto(tmp_path):
    leitura = _csv(tmp_path, "id,nome\n1,Ana\n2,\n")

    assert leitura.colunas == ["id", "nome"]
    assert leitura.cabecalho == "id,nome"
    assert [(x.numero, x.campos, x.motivo_ilegivel) for x in leitura.linhas] == [
        (2, {"id": "1", "nome": "Ana"}, None),
        (3, {"id": "2", "nome": ""}, None),
    ]
    assert [x.texto for x in leitura.linhas] == ["1,Ana", "2,"]


def test_csv_crlf_sai_do_texto_mas_nao_dos_campos_internos(tmp_path):
    leitura = _csv(tmp_path, b'id,obs\r\n1,"a\r\nb"\r\n2,fim\r\n')

    assert [x.campos["obs"] for x in leitura.linhas] == ["a\r\nb", "fim"]
    assert [x.texto for x in leitura.linhas] == ['1,"a\r\nb"', "2,fim"]
    assert [x.numero for x in leitura.linhas] == [2, 4]


def test_csv_linha_truncada_vira_ilegivel_com_o_texto_original(tmp_path):
    leitura = _csv(tmp_path, 'id,nome,obs\n1,Ana,ok\n2,"Be\n')

    assert len(leitura.linhas) == 2
    truncada = leitura.linhas[1]
    assert truncada.campos is None
    assert truncada.texto == '2,"Be'
    assert "malformado" in truncada.motivo_ilegivel


def test_csv_aspas_abertas_no_meio_guardam_o_texto_de_todas_as_linhas_engolidas(tmp_path):
    leitura = _csv(tmp_path, 'id,nome\n1,Ana\n2,"Be\n3,Caio\n')

    assert len(leitura.linhas) == 2
    assert leitura.linhas[1].texto == '2,"Be\n3,Caio'
    assert leitura.linhas[1].campos is None


def test_csv_linha_curta_e_linha_longa_sao_ilegiveis(tmp_path):
    leitura = _csv(tmp_path, "id,nome\n1\n2,Ana,extra\n3,Caio\n")

    assert [bool(x.motivo_ilegivel) for x in leitura.linhas] == [True, True, False]
    assert [x.texto for x in leitura.linhas] == ["1", "2,Ana,extra", "3,Caio"]


def test_csv_cabecalho_repetido_no_meio_continua_sendo_linha_comum(tmp_path):
    leitura = _csv(tmp_path, "id,nome\n1,Ana\nid,nome\n2,Caio\n")

    assert len(leitura.linhas) == 3
    assert leitura.linhas[1].campos == {"id": "id", "nome": "nome"}
    assert leitura.linhas[1].motivo_ilegivel is None


def test_csv_linha_em_branco_nao_some(tmp_path):
    leitura = _csv(tmp_path, "id,nome\n1,Ana\n\n2,Caio\n")

    assert [x.numero for x in leitura.linhas] == [2, 3, 4]
    assert leitura.linhas[1].motivo_ilegivel == "linha em branco"
    assert leitura.linhas[1].texto == ""


def test_csv_sem_final_de_linha_e_arquivo_vazio(tmp_path):
    assert [x.texto for x in _csv(tmp_path, "id\n1\n2").linhas] == ["1", "2"]

    vazio = _csv(tmp_path, "")
    assert vazio.colunas == []
    assert vazio.cabecalho is None
    assert vazio.linhas == []


def test_csv_so_com_cabecalho_tem_colunas_e_nenhuma_linha(tmp_path):
    leitura = _csv(tmp_path, "id,nome\n")

    assert leitura.colunas == ["id", "nome"]
    assert leitura.cabecalho == "id,nome"
    assert leitura.linhas == []


def test_csv_cabecalho_duplicado_e_erro_claro(tmp_path):
    with pytest.raises(ErroDeIngestao, match="duplicad"):
        _csv(tmp_path, "id,id\n1,2\n")


def test_csv_byte_fora_do_encoding_interrompe_com_o_arquivo_e_a_linha(tmp_path):
    with pytest.raises(ErroDeIngestao, match=r"dados\.csv.*utf-8.*linha 3"):
        _csv(tmp_path, b"id,nome\n1,Ana\n2,Jos\xe9\n3,Caio\n")


def test_csv_byte_invalido_depois_de_campo_com_quebra_de_linha_conta_a_linha_fisica(tmp_path):
    with pytest.raises(ErroDeIngestao, match=r"linha 4"):
        _csv(tmp_path, b'id,obs\n1,"a\nb"\n2,x\xe9\n')


def test_csv_respeita_separador_configurado(tmp_path):
    arquivo = tmp_path / "dados.csv"
    arquivo.write_text("id;nome\n1;Ana, a boa\n", encoding="utf-8")

    leitura = ler_csv(arquivo, encoding="utf-8", separador=";")

    assert leitura.linhas[0].campos == {"id": "1", "nome": "Ana, a boa"}


def test_jsonl_guarda_o_texto_da_linha(tmp_path):
    leitura = _jsonl(tmp_path, '{"a": 1}\r\n{"a": 2}\n')

    assert leitura.colunas == ["registro"]
    assert leitura.cabecalho is None
    assert [(x.numero, x.texto, x.campos, x.motivo_ilegivel) for x in leitura.linhas] == [
        (1, '{"a": 1}', {"registro": '{"a": 1}'}, None),
        (2, '{"a": 2}', {"registro": '{"a": 2}'}, None),
    ]


def test_jsonl_entra_sempre_como_texto_sem_validar_o_json(tmp_path):
    leitura = _jsonl(tmp_path, '{"a": 1}\n{"a": "trunc\n[1, 2]\n\n{"a": 3}')

    assert [x.texto for x in leitura.linhas] == [
        '{"a": 1}',
        '{"a": "trunc',
        "[1, 2]",
        "",
        '{"a": 3}',
    ]
    assert [x.campos["registro"] for x in leitura.linhas] == [x.texto for x in leitura.linhas]
    assert {x.motivo_ilegivel for x in leitura.linhas} == {None}


def test_jsonl_byte_fora_do_encoding_interrompe_com_o_arquivo_e_a_linha(tmp_path):
    with pytest.raises(ErroDeIngestao, match=r"dados\.jsonl.*linha 2"):
        _jsonl(tmp_path, b'{"a": 1}\n{"a": "Jos\xe9"}\n')


def test_leitor_novo_se_registra_pelo_nome(monkeypatch):
    monkeypatch.setattr(leitores, "LEITORES", dict(leitores.LEITORES))

    @leitores.leitor("psv")
    def ler_psv(caminho, encoding, separador):
        return Leitura(colunas=["x"], cabecalho=None, linhas=[])

    assert obter_leitor("psv") is ler_psv
    assert obter_leitor("csv") is ler_csv


def test_formato_desconhecido_diz_quais_existem():
    with pytest.raises(ErroDeIngestao, match="csv"):
        obter_leitor("formato_inexistente")


# =============================================================================
# CSV sem cabeçalho (arquivos da Receita): colunas, encoding e separador da configuração
# =============================================================================


def _sem_cabecalho(tmp_path, conteudo: bytes, colunas):
    arquivo = tmp_path / "dados.csv"
    arquivo.write_bytes(conteudo)
    return ler_csv(arquivo, encoding="latin-1", separador=";", colunas=colunas)


def test_csv_sem_cabecalho_usa_as_colunas_da_configuracao_desde_a_primeira_linha(tmp_path):
    conteudo = '"01";"ÁGUA"\n"02";""\n'.encode("latin-1")

    leitura = _sem_cabecalho(tmp_path, conteudo, ["codigo", "descricao"])

    assert leitura.colunas == ["codigo", "descricao"]
    assert leitura.cabecalho is None
    assert [(x.numero, x.campos, x.motivo_ilegivel) for x in leitura.linhas] == [
        (1, {"codigo": "01", "descricao": "ÁGUA"}, None),
        (2, {"codigo": "02", "descricao": ""}, None),
    ]
    assert [x.texto for x in leitura.linhas] == ['"01";"ÁGUA"', '"02";""']


def test_csv_sem_cabecalho_respeita_quebra_de_linha_dentro_de_campo_entre_aspas(tmp_path):
    conteudo = b'"1";"RUA A\nCASA 2";"SP"\n"2";"RUA B";"RJ"\n'

    leitura = _sem_cabecalho(tmp_path, conteudo, ["id", "rua", "uf"])

    assert [x.numero for x in leitura.linhas] == [1, 3]
    assert leitura.linhas[0].campos["rua"] == "RUA A\nCASA 2"
    assert leitura.linhas[0].texto == '"1";"RUA A\nCASA 2";"SP"'


def test_csv_sem_cabecalho_linha_com_campos_a_mais_ou_a_menos_e_ilegivel(tmp_path):
    leitura = _sem_cabecalho(tmp_path, b'"1";"a"\n"2"\n"3";"c";"d"\n', ["id", "nome"])

    assert [x.motivo_ilegivel for x in leitura.linhas] == [
        None,
        "1 campos, o cabeçalho tem 2",
        "3 campos, o cabeçalho tem 2",
    ]
    assert [x.texto for x in leitura.linhas[1:]] == ['"2"', '"3";"c";"d"']


def test_csv_sem_cabecalho_vazio_devolve_as_colunas_e_nenhuma_linha(tmp_path):
    leitura = _sem_cabecalho(tmp_path, b"", ["id", "nome"])

    assert leitura.colunas == ["id", "nome"]
    assert leitura.linhas == []


def test_csv_sem_cabecalho_byte_fora_do_encoding_continua_interrompendo(tmp_path):
    arquivo = tmp_path / "dados.csv"
    arquivo.write_bytes(b'"1";"Jos\xe9"\n')

    with pytest.raises(ErroDeIngestao, match=r"dados\.csv.*linha 1"):
        ler_csv(arquivo, encoding="utf-8", separador=";", colunas=["id", "nome"])


@pytest.mark.parametrize(
    ("colunas", "trecho"),
    [([], "ao menos uma coluna"), (["id", "id"], "duplicadas"), (["id", ""], "sem nome")],
)
def test_csv_sem_cabecalho_recusa_colunas_invalidas(tmp_path, colunas, trecho):
    with pytest.raises(ErroDeIngestao, match=trecho):
        _sem_cabecalho(tmp_path, b'"1"\n', colunas)
