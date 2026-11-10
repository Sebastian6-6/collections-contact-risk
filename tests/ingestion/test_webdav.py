"""Cliente WebDAV: listagem de uma pasta e download com retomada, contra um servidor local."""

import pytest
from servidor_webdav import MODIFICADO, servidor

from ingestion import ErroDeIngestao
from ingestion.webdav import ArquivoRemoto, ClienteWebDav

CONTEUDO = bytes(range(256)) * 40


@pytest.fixture(autouse=True)
def sem_proxy(monkeypatch):
    monkeypatch.setenv("NO_PROXY", "127.0.0.1")
    monkeypatch.setenv("no_proxy", "127.0.0.1")


def test_lista_so_os_arquivos_da_pasta_com_tamanho_e_data():
    pastas = {"2026-10": {"B.zip": b"bb", "A.zip": b"a" * 5}}
    with servidor(pastas) as (url, _):
        arquivos = ClienteWebDav(url, "TOKEN").listar("2026-10")

    assert arquivos == [
        ArquivoRemoto("A.zip", 5, MODIFICADO),
        ArquivoRemoto("B.zip", 2, MODIFICADO),
    ]


def test_pasta_inexistente_e_erro_com_o_endereco():
    with servidor({}) as (url, _), pytest.raises(ErroDeIngestao, match=r"2026-11.*404"):
        ClienteWebDav(url, "TOKEN").listar("2026-11")


def test_token_errado_e_erro_de_autenticacao():
    with servidor({"p": {}}) as (url, _), pytest.raises(ErroDeIngestao, match=r"401"):
        ClienteWebDav(url, "OUTRO").listar("p")


def test_baixa_o_arquivo_inteiro(tmp_path):
    with servidor({"p": {"A.zip": CONTEUDO}}) as (url, _):
        cliente = ClienteWebDav(url, "TOKEN")
        destino = tmp_path / "A.zip"
        cliente.baixar("p", ArquivoRemoto("A.zip", len(CONTEUDO), MODIFICADO), destino)

    assert destino.read_bytes() == CONTEUDO
    assert not list(tmp_path.glob("*.parcial"))


def test_retoma_do_ponto_onde_a_conexao_caiu(tmp_path):
    with servidor({"p": {"A.zip": CONTEUDO}}) as (url, estado):
        estado.cortar_proximo_get_em = 3000
        cliente = ClienteWebDav(url, "TOKEN", pausa=0)
        destino = tmp_path / "A.zip"
        cliente.baixar("p", ArquivoRemoto("A.zip", len(CONTEUDO), MODIFICADO), destino)

    assert destino.read_bytes() == CONTEUDO
    gets = [faixa for metodo, _, faixa in estado.pedidos if metodo == "GET"]
    assert gets == [None, "bytes=3000-"]


def test_servidor_que_ignora_o_range_recomeca_do_zero(tmp_path):
    destino = tmp_path / "A.zip"
    destino.with_name("A.zip.parcial").write_bytes(CONTEUDO[:100])
    with servidor({"p": {"A.zip": CONTEUDO}}) as (url, estado):
        estado.ignorar_range = True
        ClienteWebDav(url, "TOKEN").baixar(
            "p", ArquivoRemoto("A.zip", len(CONTEUDO), MODIFICADO), destino
        )

    assert destino.read_bytes() == CONTEUDO


def test_tamanho_diferente_do_anunciado_e_erro_e_nao_deixa_o_arquivo_final(tmp_path):
    destino = tmp_path / "A.zip"
    with servidor({"p": {"A.zip": CONTEUDO}}) as (url, _):
        cliente = ClienteWebDav(url, "TOKEN", tentativas=2, pausa=0)
        with pytest.raises(ErroDeIngestao, match=r"A\.zip.*tamanho"):
            cliente.baixar("p", ArquivoRemoto("A.zip", len(CONTEUDO) + 1, MODIFICADO), destino)

    assert not destino.exists()


def test_arquivo_inexistente_no_servidor_e_erro(tmp_path):
    with servidor({"p": {}}) as (url, _), pytest.raises(ErroDeIngestao, match=r"A\.zip.*404"):
        ClienteWebDav(url, "TOKEN").baixar(
            "p", ArquivoRemoto("A.zip", 1, MODIFICADO), tmp_path / "A.zip"
        )
