"""Ingestão: lê os arquivos recebidos sem transformar e grava cada linha na bronze do DuckDB."""


class ErroDeIngestao(Exception):  # noqa: N818 - o prefixo Erro é a convenção em português
    """Falha que a pessoa que roda a ingestão resolve: configuração, arquivo ou formato."""
