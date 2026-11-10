"""Apoio dos testes de ingestão: projeto temporário, consultas ao banco e conferência de linhas."""

import re
from pathlib import Path

import duckdb
import yaml

from ingestion.main import main

TERMINADOR = re.compile(r"\r\n|\n|\r")


class Projeto:
    """Raiz temporária com `fontes.yml`, arquivos de entrada e o banco gerado."""

    def __init__(self, raiz: Path):
        self.raiz = raiz
        self.config = raiz / "fontes.yml"
        self.banco = raiz / "database" / "teste.duckdb"

    def escrever(self, caminho: str, conteudo: bytes | str) -> Path:
        destino = self.raiz / caminho
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_bytes(conteudo if isinstance(conteudo, bytes) else conteudo.encode())
        return destino

    def configurar(self, fontes: dict) -> None:
        self.config.write_text(yaml.safe_dump(fontes, allow_unicode=True), encoding="utf-8")

    def rodar(self, *argumentos: str) -> int:
        return main(
            [
                *argumentos,
                "--config", str(self.config),
                "--raiz", str(self.raiz),
                "--banco", str(self.banco),
            ]
        )  # fmt: skip

    def consultar(self, consulta: str) -> list[dict]:
        return consultar(self.banco, consulta)

    def esquemas(self) -> set[str]:
        linhas = self.consultar("SELECT schema_name FROM duckdb_schemas()")
        return {linha["schema_name"] for linha in linhas}


def consultar(banco: Path, consulta: str) -> list[dict]:
    """Roda a consulta no banco, só leitura, e devolve uma linha por dicionário."""
    conexao = duckdb.connect(str(banco), read_only=True)
    try:
        cursor = conexao.execute(consulta)
        nomes = [coluna[0] for coluna in cursor.description]
        return [dict(zip(nomes, linha, strict=True)) for linha in cursor.fetchall()]
    finally:
        conexao.close()


def entidade(formato: str, *locais: tuple[str, str], **extras) -> dict:
    """Monta a configuração de uma entidade a partir de pares (caminho, padrão)."""
    return {
        "origem": "pasta",
        "formato": formato,
        "arquivos": [{"caminho": caminho, "padrao": padrao} for caminho, padrao in locais],
        **extras,
    }


def linhas_fisicas(texto: str) -> int:
    """Quantas linhas físicas o texto tem, contando a última mesmo sem terminador."""
    if not texto:
        return 0
    return len(TERMINADOR.findall(texto)) + (0 if texto.endswith(("\n", "\r")) else 1)


def linhas_do_registro(texto: str) -> int:
    """Quantas linhas físicas um registro ocupa (um campo entre aspas pode quebrar linha)."""
    return len(TERMINADOR.findall(texto)) + 1


def faltam_linhas(
    registros: list[dict], cabecalho: str | None, texto_do_arquivo: str
) -> str | None:
    """Diz onde as linhas físicas do arquivo não estão cobertas pelos registros, ou None.

    Os registros devem se encadear: cada um começa na linha em que o anterior terminou, e o
    último termina na última linha física do arquivo.
    """
    proxima = 1 + (linhas_do_registro(cabecalho) if cabecalho is not None else 0)
    for registro in sorted(registros, key=lambda r: r["_linha"]):
        if registro["_linha"] != proxima:
            return f"buraco antes da linha {registro['_linha']} (esperava {proxima})"
        proxima += linhas_do_registro(registro["_linha_original"])
    total = linhas_fisicas(texto_do_arquivo)
    if proxima - 1 != total:
        return f"cobertas {proxima - 1} linhas de {total}"
    return None
