"""Prova que duas execuções da pipeline, do zero, dão exatamente o mesmo resultado.

Uso, a partir da raiz do repositório:
    python scripts/verificar_execucoes_identicas.py

Roda `python pipeline.py` duas vezes (cada uma apaga o banco e refaz tudo) e, depois de cada
rodada, resume todas as tabelas e views dos schemas `bronze_*`, `silver_*` e `gold_*` (um por
domínio, como `gold_devedores`): contagem de linhas e a soma dos hashes das linhas. A soma dos
hashes não depende da ordem das linhas, então equivale a comparar o conteúdo ordenado por todas as
colunas sem o custo de ordenar. Sai com código 1 e lista as tabelas que divergiram.
"""

import subprocess
import sys
import time
from collections.abc import Callable
from pathlib import Path

import duckdb

RAIZ = Path(__file__).resolve().parent.parent
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from ingestion.main import caminho_do_banco  # noqa: E402

PREFIXOS_COMPARADOS = ("bronze_", "silver_", "gold_")

Resumo = dict[str, tuple[int, int]]


def schema_comparado(schema: str) -> bool:
    """Diz se o schema entra na comparação (`bronze_*`, `silver_*` ou `gold_*`)."""
    return schema.startswith(PREFIXOS_COMPARADOS)


def resumir_banco(banco: Path) -> Resumo:
    """Devolve, por `schema.tabela`, a contagem de linhas e a soma dos hashes das linhas.

    O hash vem do texto da linha inteira, então qualquer coluna diferente muda o resultado.
    """
    conexao = duckdb.connect(str(banco), read_only=True)
    try:
        objetos = conexao.execute(
            "SELECT table_schema, table_name FROM information_schema.tables"
            " ORDER BY table_schema, table_name"
        ).fetchall()
        resumo: Resumo = {}
        for schema, tabela in objetos:
            if not schema_comparado(schema):
                continue
            contagem, soma = conexao.execute(
                "SELECT COUNT(*), COALESCE(SUM(CAST(hash(CAST(t AS VARCHAR)) AS HUGEINT)), 0)"
                f' FROM "{schema}"."{tabela}" AS t'
            ).fetchone()
            resumo[f"{schema}.{tabela}"] = (contagem, int(soma))
        return resumo
    finally:
        conexao.close()


def achar_divergencias(primeira: Resumo, segunda: Resumo) -> list[str]:
    """Lista, em ordem, as tabelas com resumo diferente ou presentes em só uma das rodadas."""
    return sorted(
        tabela for tabela in primeira.keys() | segunda.keys()
        if primeira.get(tabela) != segunda.get(tabela)
    )


def executar_pipeline(raiz: Path) -> bool:
    """Roda `python pipeline.py` num processo próprio, como o CI e quem desenvolve rodam."""
    return subprocess.run([sys.executable, "pipeline.py"], cwd=raiz, check=False).returncode == 0


def resumir_do_projeto(raiz: Path) -> Resumo:
    """Resume o banco que o `profiles.yml` do projeto aponta."""
    return resumir_banco(caminho_do_banco(raiz))


def main(
    raiz: Path = RAIZ,
    rodar_pipeline: Callable[[Path], bool] = executar_pipeline,
    resumir: Callable[[Path], Resumo] = resumir_do_projeto,
) -> int:
    """Roda a pipeline duas vezes e devolve 0 só se todas as tabelas forem idênticas."""
    resumos: list[Resumo] = []
    for numero in (1, 2):
        inicio = time.monotonic()
        print(f"[..] execução {numero} da pipeline")
        if not rodar_pipeline(raiz):
            print(f"[ERRO] a pipeline falhou na execução {numero}")
            return 1
        resumos.append(resumir(raiz))
        print(f"[OK] execução {numero} em {time.monotonic() - inicio:.0f} s")
    divergentes = achar_divergencias(*resumos)
    if divergentes:
        for tabela in divergentes:
            print(f"[ERRO] tabela diferente entre as execuções: {tabela}")
        return 1
    print(f"[OK] {len(resumos[0])} tabelas e views idênticas nas duas execuções")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
