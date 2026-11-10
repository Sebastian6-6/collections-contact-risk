"""Extrato da Receita: filtra os zips pelas raízes de CNPJ recebidas e documenta a origem."""

import hashlib
import io
import zipfile
from pathlib import Path

import duckdb
import pytest
from servidor_webdav import MODIFICADO, servidor

from ingestion import ErroDeIngestao
from ingestion.main import main
from ingestion.receita import (
    OrigemDeRaizes,
    ParametrosReceita,
    filtrar_zip,
    ler_parametros,
    montar_extrato,
    raizes_dos_cnpjs,
)
from ingestion.webdav import ArquivoRemoto

RAIZES = frozenset({"11111111", "33333333"})

# Uma raiz pedida, uma que não é e um registro de Estabelecimentos com quebra de linha dentro
# do campo; a continuação "parece" o começo de outro registro, mas está entre aspas.
REGISTROS = (
    b'"11111111";"0001";"A"\n'
    b'"22222222";"0001";"B"\n'
    b'"22222222";"0002";"RUA\n""11111111"";""X""\n"\n'
    b'"33333333";"0001";"C\nD"\n'
    b'"11111111";"0002";"\xc1GUA"\n'
)
SELECIONADOS = (
    b'"11111111";"0001";"A"\n'
    b'"33333333";"0001";"C\nD"\n'
    b'"11111111";"0002";"\xc1GUA"\n'
)


def _zip(conteudo: bytes, nome: str = "K3241.K03200Y0.D61010.ESTABELE") -> bytes:
    memoria = io.BytesIO()
    with zipfile.ZipFile(memoria, "w", zipfile.ZIP_DEFLATED) as arquivo:
        arquivo.writestr(nome, conteudo)
    return memoria.getvalue()


def _gravar(tmp_path: Path, conteudo: bytes, nome: str = "A.zip") -> Path:
    caminho = tmp_path / nome
    caminho.write_bytes(_zip(conteudo))
    return caminho


# =============================================================================
# filtrar_zip
# =============================================================================


def test_mantem_so_os_registros_das_raizes_pedidas_byte_a_byte_e_na_ordem(tmp_path):
    resultado = filtrar_zip(_gravar(tmp_path, REGISTROS), RAIZES)

    assert resultado.selecionado == SELECIONADOS
    assert resultado.registros == 5
    assert resultado.sem_raiz == 0
    assert resultado.por_raiz == {"11111111": 2, "33333333": 1}


def test_registra_o_tamanho_e_o_sha256_do_zip(tmp_path):
    caminho = _gravar(tmp_path, REGISTROS)

    resultado = filtrar_zip(caminho, RAIZES)

    assert resultado.bytes == caminho.stat().st_size
    assert resultado.sha256 == hashlib.sha256(caminho.read_bytes()).hexdigest()


def test_sem_raizes_o_arquivo_vai_inteiro_e_o_ultimo_registro_ganha_fim_de_linha(tmp_path):
    resultado = filtrar_zip(_gravar(tmp_path, b'"01";"A"\n"02";"B"'), None)

    assert resultado.selecionado == b'"01";"A"\n"02";"B"\n'
    assert resultado.registros == 2
    assert resultado.por_raiz == {}


def test_arquivo_vazio_nao_tem_registros(tmp_path):
    resultado = filtrar_zip(_gravar(tmp_path, b""), RAIZES)

    assert (resultado.registros, resultado.selecionado) == (0, b"")


def test_registro_sem_raiz_de_8_caracteres_e_contado_e_nao_some_calado(tmp_path):
    resultado = filtrar_zip(_gravar(tmp_path, b'"1111";"x"\n\n"11111111";"y"\n'), RAIZES)

    assert resultado.registros == 3
    assert resultado.sem_raiz == 2
    assert resultado.selecionado == b'"11111111";"y"\n'


def test_aspas_abertas_ate_o_fim_do_arquivo_e_erro_com_o_arquivo(tmp_path):
    caminho = _gravar(tmp_path, b'"11111111";"a"\n"22222222";"corta\n')

    with pytest.raises(ErroDeIngestao, match=r"A\.zip.*aspas.*registro 2"):
        filtrar_zip(caminho, RAIZES)


def test_zip_com_mais_de_um_arquivo_e_erro(tmp_path):
    memoria = io.BytesIO()
    with zipfile.ZipFile(memoria, "w") as arquivo:
        arquivo.writestr("a", b"x")
        arquivo.writestr("b", b"y")
    caminho = tmp_path / "A.zip"
    caminho.write_bytes(memoria.getvalue())

    with pytest.raises(ErroDeIngestao, match=r"A\.zip.*2 arquivos"):
        filtrar_zip(caminho, RAIZES)


def test_zip_corrompido_e_erro_com_o_arquivo(tmp_path):
    memoria = io.BytesIO()
    with zipfile.ZipFile(memoria, "w", zipfile.ZIP_STORED) as arquivo:
        arquivo.writestr("a", b'"11111111";"conteudo"\n')
    corrompido = bytearray(memoria.getvalue())
    corrompido[corrompido.index(b"conteudo")] ^= 0xFF
    caminho = tmp_path / "A.zip"
    caminho.write_bytes(bytes(corrompido))

    with pytest.raises(ErroDeIngestao, match=r"A\.zip.*CRC"):
        filtrar_zip(caminho, RAIZES)


def test_arquivo_que_nao_e_zip_e_erro_com_o_arquivo(tmp_path):
    caminho = tmp_path / "A.zip"
    caminho.write_bytes(b"isto nao e um zip")

    with pytest.raises(ErroDeIngestao, match=r"A\.zip.*zip"):
        filtrar_zip(caminho, RAIZES)


# =============================================================================
# montar_extrato
# =============================================================================


class ClienteFalso:
    """Mesma interface do cliente WebDAV, com os zips em memória e a contagem de downloads."""

    def __init__(self, arquivos: dict[str, bytes]):
        self.arquivos = arquivos
        self.baixados: list[str] = []

    def listar(self, pasta: str) -> list[ArquivoRemoto]:
        assert pasta == "2026-10"
        return [
            ArquivoRemoto(nome, len(dados), MODIFICADO)
            for nome, dados in sorted(self.arquivos.items())
        ]

    def baixar(self, pasta: str, arquivo: ArquivoRemoto, destino: Path) -> None:
        self.baixados.append(arquivo.nome)
        destino.write_bytes(self.arquivos[arquivo.nome])


def _remotos() -> dict[str, bytes]:
    return {
        "Cnaes.zip": _zip(b'"01";"AGRICULTURA"\n"02";"PECUARIA"\n', "CNAECSV"),
        "Empresas0.zip": _zip(b'"11111111";"ALFA"\n"22222222";"BETA"\n', "EMPRECSV"),
        "Empresas1.zip": _zip(b'"33333333";"GAMA"\n"44444444";"DELTA"\n', "EMPRECSV"),
        "Estabelecimentos0.zip": _zip(REGISTROS),
        "Simples.zip": _zip(b'"11111111";"S"\n', "SIMPLES"),
        "Socios0.zip": _zip(b'"22222222";"1"\n', "SOCIOCSV"),
    }


def _parametros(**trocas) -> ParametrosReceita:
    base = {
        "mes": "2026-10",
        "url_compartilhamento": "https://exemplo.gov.br/s/TOKEN",
        "url_webdav": "https://exemplo.gov.br/public.php/webdav",
        "token": "TOKEN",
        "cache": ".cache/receita",
        "completas": ["cnaes"],
        "filtradas": ["empresas", "estabelecimentos", "simples", "socios"],
        "raizes_de": [{"tabela": "silver_x.devedores", "coluna": "cnpj"}],
    }
    return ler_parametros({**base, **trocas})


def _montar(tmp_path, cliente=None, parametros=None, raizes=("11111111", "33333333", "55555555")):
    cliente = cliente or ClienteFalso(_remotos())
    destino = tmp_path / "dados_externos" / "receita" / "2026-10"
    escritos = montar_extrato(
        cliente, parametros or _parametros(), raizes, destino, tmp_path / ".cache"
    )
    return cliente, destino, escritos


def test_grava_um_arquivo_por_entidade_com_as_raizes_pedidas(tmp_path):
    _, destino, escritos = _montar(tmp_path)

    assert [arquivo.name for arquivo in escritos] == [
        "cnaes.csv",
        "empresas.csv",
        "estabelecimentos.csv",
        "simples.csv",
        "socios.csv",
        "ORIGEM.md",
    ]
    assert (destino / "cnaes.csv").read_bytes() == b'"01";"AGRICULTURA"\n"02";"PECUARIA"\n'
    assert (destino / "empresas.csv").read_bytes() == b'"11111111";"ALFA"\n"33333333";"GAMA"\n'
    assert (destino / "estabelecimentos.csv").read_bytes() == SELECIONADOS
    assert (destino / "simples.csv").read_bytes() == b'"11111111";"S"\n'
    assert (destino / "socios.csv").read_bytes() == b""


def test_entidade_particionada_junta_os_zips_na_ordem_numerica(tmp_path):
    remotos = _remotos()
    for numero in range(2, 11):
        remotos[f"Empresas{numero}.zip"] = _zip(f'"11111111";"E{numero}"\n'.encode(), "E")
    _, destino, _ = _montar(tmp_path, ClienteFalso(remotos))

    linhas = (destino / "empresas.csv").read_text(encoding="latin-1").splitlines()
    assert [linha.split(";")[1] for linha in linhas[:3]] == ['"ALFA"', '"GAMA"', '"E2"']
    assert linhas[-1] == '"11111111";"E10"'


def test_origem_documenta_arquivos_extrato_e_raizes(tmp_path):
    cliente, destino, _ = _montar(tmp_path)
    origem = (destino / "ORIGEM.md").read_text(encoding="utf-8")

    for nome, dados in cliente.arquivos.items():
        sha256 = hashlib.sha256(dados).hexdigest()
        identidade = f"| {nome} | {len(dados)} | {MODIFICADO} | {sha256} |"
        assert identidade in origem
    assert "https://exemplo.gov.br/public.php/webdav/2026-10/" in origem
    assert "https://exemplo.gov.br/s/TOKEN" in origem
    assert "2026-10" in origem
    raizes = "11111111\n33333333\n55555555"
    assert hashlib.sha256(raizes.encode()).hexdigest() in origem
    assert f"| {hashlib.sha256(SELECIONADOS).hexdigest()} |" in origem


def test_origem_diz_quais_raizes_a_receita_tem_e_quantos_registros_cada_uma(tmp_path):
    _, destino, _ = _montar(tmp_path)
    origem = (destino / "ORIGEM.md").read_text(encoding="utf-8")

    assert "| 11111111 | 1 | 2 | 1 | 0 |" in origem
    assert "| 33333333 | 1 | 1 | 0 | 0 |" in origem
    assert "| 55555555 | 0 | 0 | 0 | 0 |" in origem
    assert "2 de 3 raízes" in origem


def test_nada_depende_do_horario_nem_do_caminho_da_maquina(tmp_path):
    _, destino, _ = _montar(tmp_path)
    primeira = {p.name: p.read_bytes() for p in destino.iterdir()}

    segundo = tmp_path / "segundo"
    segundo.mkdir()
    _, destino2, _ = _montar(segundo)
    segunda = {p.name: p.read_bytes() for p in destino2.iterdir()}

    assert primeira == segunda
    assert str(tmp_path).encode() not in primeira["ORIGEM.md"]


def test_zip_ja_no_cache_com_o_tamanho_certo_nao_e_baixado_de_novo(tmp_path):
    cliente, _, _ = _montar(tmp_path)
    assert sorted(cliente.baixados) == sorted(cliente.arquivos)

    cliente.baixados.clear()
    _montar(tmp_path, cliente)

    assert cliente.baixados == []


def test_zip_no_cache_com_tamanho_diferente_e_baixado_de_novo(tmp_path):
    cliente, _, _ = _montar(tmp_path)
    (tmp_path / ".cache" / "2026-10" / "Cnaes.zip").write_bytes(b"truncado")

    cliente.baixados.clear()
    _montar(tmp_path, cliente)

    assert cliente.baixados == ["Cnaes.zip"]


def test_arquivo_fora_da_configuracao_e_erro_e_nao_grava_nada(tmp_path):
    remotos = {**_remotos(), "Novidade0.zip": _zip(b'"1";"x"\n')}

    with pytest.raises(ErroDeIngestao, match=r"Novidade0\.zip"):
        _montar(tmp_path, ClienteFalso(remotos))

    assert not (tmp_path / "dados_externos").exists()


def test_entidade_configurada_sem_arquivo_na_origem_e_erro(tmp_path):
    remotos = _remotos()
    del remotos["Simples.zip"]

    with pytest.raises(ErroDeIngestao, match="simples"):
        _montar(tmp_path, ClienteFalso(remotos))


def test_falha_em_um_zip_nao_deixa_extrato_pela_metade(tmp_path):
    remotos = {**_remotos(), "Socios0.zip": _zip(b'"22222222";"aberta\n')}

    with pytest.raises(ErroDeIngestao, match=r"Socios0\.zip"):
        _montar(tmp_path, ClienteFalso(remotos))

    assert not (tmp_path / "dados_externos").exists()


def test_sem_raizes_nao_baixa_nada(tmp_path):
    cliente = ClienteFalso(_remotos())

    with pytest.raises(ErroDeIngestao, match="nenhuma raiz"):
        _montar(tmp_path, cliente, raizes=())

    assert cliente.baixados == []


# =============================================================================
# Configuração e raízes
# =============================================================================


def test_parametros_desconhecidos_ou_ausentes_dizem_quais():
    with pytest.raises(ErroDeIngestao, match=r"desconhecido.*cor"):
        _parametros(cor="azul")
    with pytest.raises(ErroDeIngestao, match=r"ausente.*token"):
        ler_parametros({"mes": "2026-10"})


@pytest.mark.parametrize(
    ("troca", "trecho"),
    [
        ({"mes": "outubro"}, "mes"),
        ({"completas": ["cnaes"], "filtradas": ["cnaes"]}, "cnaes"),
        ({"filtradas": []}, "filtradas"),
        ({"raizes_de": []}, "raizes_de"),
        ({"raizes_de": [{"tabela": "x; DROP", "coluna": "c"}]}, "x; DROP"),
        ({"trabalhadores": 2}, "trabalhadores"),
    ],
)
def test_parametros_invalidos_dizem_qual(troca, trecho):
    with pytest.raises(ErroDeIngestao, match=trecho):
        _parametros(**troca)


def _banco_com_cnpjs(tmp_path, valores_a, valores_b) -> Path:
    banco = tmp_path / "banco.duckdb"
    conexao = duckdb.connect(str(banco))
    conexao.execute("CREATE SCHEMA silver_x")
    for tabela, valores in (("a", valores_a), ("b", valores_b)):
        conexao.execute(f"CREATE TABLE silver_x.{tabela} (cnpj VARCHAR)")
        for valor in valores:
            conexao.execute(f"INSERT INTO silver_x.{tabela} VALUES (?)", [valor])
    conexao.close()
    return banco


def _origens() -> list[OrigemDeRaizes]:
    return [OrigemDeRaizes("silver_x.a", "cnpj"), OrigemDeRaizes("silver_x.b", "cnpj")]


def test_raizes_saem_dos_8_primeiros_caracteres_sem_repetir_nem_nulos(tmp_path):
    banco = _banco_com_cnpjs(
        tmp_path,
        ["11111111000191", "11111111000272", None],
        ["3RT8XB51000136", "00000000000191"],
    )

    assert raizes_dos_cnpjs(banco, _origens()) == ["00000000", "11111111", "3RT8XB51"]


def test_cnpj_que_nao_tem_14_caracteres_e_erro_e_diz_qual(tmp_path):
    banco = _banco_com_cnpjs(tmp_path, ["11111111000191", "123"], [])

    with pytest.raises(ErroDeIngestao, match="123"):
        raizes_dos_cnpjs(banco, _origens())


def test_banco_inexistente_manda_rodar_a_pipeline(tmp_path):
    with pytest.raises(ErroDeIngestao, match="pipeline"):
        raizes_dos_cnpjs(tmp_path / "nao_existe.duckdb", _origens())


# =============================================================================
# Linha de comando, com o servidor WebDAV falso
# =============================================================================


def _projeto_para_baixar(tmp_path, url_webdav: str) -> Path:
    banco = _banco_com_cnpjs(tmp_path, ["11111111000191"], ["33333333000100"])
    config = tmp_path / "fontes.yml"
    config.write_text(
        f"""
receita:
  _baixar:
    origem: receita
    destino: dados_externos/receita/2026-10
    parametros:
      mes: "2026-10"
      url_compartilhamento: https://exemplo.gov.br/s/TOKEN
      url_webdav: {url_webdav}
      token: TOKEN
      cache: .cache/receita
      completas: [cnaes]
      filtradas: [empresas, estabelecimentos, simples, socios]
      raizes_de:
        - {{tabela: silver_x.a, coluna: cnpj}}
        - {{tabela: silver_x.b, coluna: cnpj}}
""",
        encoding="utf-8",
    )
    return banco


def test_baixar_receita_pela_linha_de_comando_grava_o_extrato(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv("NO_PROXY", "127.0.0.1")
    monkeypatch.setenv("no_proxy", "127.0.0.1")
    with servidor({"2026-10": _remotos()}) as (url, _):
        banco = _projeto_para_baixar(tmp_path, url)
        codigo = main(
            [
                "--baixar", "receita",
                "--config", str(tmp_path / "fontes.yml"),
                "--raiz", str(tmp_path),
                "--banco", str(banco),
            ]
        )  # fmt: skip

    destino = tmp_path / "dados_externos" / "receita" / "2026-10"
    assert codigo == 0
    assert (destino / "empresas.csv").read_bytes() == b'"11111111";"ALFA"\n"33333333";"GAMA"\n'
    assert "ORIGEM.md" in capsys.readouterr().out


def test_baixar_fonte_sem_bloco_baixar_e_erro(tmp_path, capsys):
    (tmp_path / "fontes.yml").write_text(
        "fonte:\n  pessoas:\n    origem: pasta\n    formato: csv\n"
        "    arquivos: [{caminho: d, padrao: '*'}]\n",
        encoding="utf-8",
    )

    codigo = main(
        ["--baixar", "fonte", "--config", str(tmp_path / "fontes.yml"), "--raiz", str(tmp_path)]
    )

    assert codigo == 1
    assert "_baixar" in capsys.readouterr().out
