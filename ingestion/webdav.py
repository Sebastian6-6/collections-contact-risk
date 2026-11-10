"""Cliente WebDAV mínimo para compartilhamentos públicos (Nextcloud): listar e baixar.

Só o que a ingestão precisa: `PROPFIND` para listar uma pasta com tamanho e data de cada
arquivo e `GET` com retomada (`Range`) para baixar. O usuário do acesso é o token do
compartilhamento e a senha é vazia. Usa só a biblioteca padrão, sem dependência nova.
"""

import base64
import shutil
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from email.utils import parsedate_to_datetime
from http.client import HTTPException
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote, unquote
from urllib.request import Request, urlopen

from ingestion import ErroDeIngestao

# =============================================================================
# Constantes
# =============================================================================

BLOCO_DE_CONTEUDO = 1024 * 1024
CORPO_DO_PROPFIND = (
    '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop>'
    "<d:getcontentlength/><d:getlastmodified/><d:resourcetype/></d:prop></d:propfind>"
)
ESPACO_DAV = "{DAV:}"
CODIGO_FAIXA_INVALIDA = 416
STATUS_PARCIAL = 206

# =============================================================================
# Tipos
# =============================================================================


@dataclass(frozen=True)
class ArquivoRemoto:
    """Um arquivo da listagem: nome, tamanho em bytes e a data de modificação do servidor."""

    nome: str
    bytes: int
    modificado: str


class ErroHttp(ErroDeIngestao):
    """Resposta de erro do servidor; guarda o código para quem precisar distinguir."""

    def __init__(self, mensagem: str, codigo: int):
        super().__init__(mensagem)
        self.codigo = codigo


# =============================================================================
# Cliente
# =============================================================================


class ClienteWebDav:
    """Acesso a uma árvore WebDAV pública, com `url_base` até a raiz do compartilhamento."""

    def __init__(
        self,
        url_base: str,
        token: str,
        timeout: float = 60.0,
        tentativas: int = 5,
        pausa: float = 5.0,
    ):
        self.url_base = url_base.rstrip("/")
        self.timeout = timeout
        self.tentativas = tentativas
        self.pausa = pausa
        credencial = base64.b64encode(f"{token}:".encode()).decode()
        self._autorizacao = f"Basic {credencial}"

    def _url(self, *partes: str) -> str:
        return "/".join([self.url_base, *(quote(parte, safe="/") for parte in partes)])

    def _abrir(
        self, url: str, metodo: str, cabecalhos: dict[str, str], corpo: bytes | None = None
    ):
        todos = {"Authorization": self._autorizacao, **cabecalhos}
        pedido = Request(url, data=corpo, method=metodo, headers=todos)
        try:
            return urlopen(pedido, timeout=self.timeout)
        except HTTPError as erro:
            raise ErroHttp(f"{metodo} {url}: HTTP {erro.code}", erro.code) from erro

    def listar(self, pasta: str) -> list[ArquivoRemoto]:
        """Lista os arquivos (não as subpastas) de `pasta`, em ordem de nome."""
        cabecalhos = {"Depth": "1", "Content-Type": "application/xml"}
        url = self._url(pasta) + "/"
        with self._abrir(url, "PROPFIND", cabecalhos, CORPO_DO_PROPFIND.encode()) as resposta:
            # O servidor é o da configuração; o expat atual limita a expansão de entidades.
            raiz = ET.fromstring(resposta.read())
        arquivos = []
        for item in raiz.findall(f"{ESPACO_DAV}response"):
            propriedades = item.find(f"{ESPACO_DAV}propstat/{ESPACO_DAV}prop")
            if propriedades is None or _e_pasta(propriedades):
                continue
            arquivos.append(_arquivo_remoto(url, item, propriedades))
        return sorted(arquivos, key=lambda arquivo: arquivo.nome)

    def baixar(self, pasta: str, arquivo: ArquivoRemoto, destino: Path) -> None:
        """Baixa `arquivo` para `destino`, retomando de onde parou se a conexão cair.

        O download vai para `<destino>.parcial` e só vira `destino` quando o tamanho bate com o
        anunciado na listagem; um arquivo incompleto nunca aparece com o nome final.
        """
        url = self._url(pasta, arquivo.nome)
        parcial = destino.with_name(destino.name + ".parcial")
        destino.parent.mkdir(parents=True, exist_ok=True)
        for tentativa in range(self.tentativas):
            baixados = parcial.stat().st_size if parcial.exists() else 0
            if baixados > arquivo.bytes:
                parcial.unlink()
                baixados = 0
            if baixados == arquivo.bytes:
                break
            if tentativa:
                time.sleep(self.pausa)
            try:
                self._baixar_a_partir_de(url, parcial, baixados)
            except ErroHttp as erro:
                if erro.codigo != CODIGO_FAIXA_INVALIDA:
                    raise
            except (OSError, HTTPException):
                continue
        tamanho = parcial.stat().st_size if parcial.exists() else 0
        if tamanho != arquivo.bytes:
            raise ErroDeIngestao(
                f"{arquivo.nome}: tamanho {tamanho} diferente do anunciado {arquivo.bytes} "
                f"depois de {self.tentativas} tentativa(s)"
            )
        parcial.replace(destino)

    def _baixar_a_partir_de(self, url: str, parcial: Path, baixados: int) -> None:
        faixa = {"Range": f"bytes={baixados}-"} if baixados else {}
        with self._abrir(url, "GET", faixa) as resposta:
            continua = bool(baixados) and resposta.status == STATUS_PARCIAL
            with parcial.open("ab" if continua else "wb") as saida:
                shutil.copyfileobj(resposta, saida, BLOCO_DE_CONTEUDO)


def _e_pasta(propriedades: ET.Element) -> bool:
    return propriedades.find(f"{ESPACO_DAV}resourcetype/*") is not None


def _arquivo_remoto(url: str, item: ET.Element, propriedades: ET.Element) -> ArquivoRemoto:
    href = item.findtext(f"{ESPACO_DAV}href", default="")
    nome = unquote(href.rstrip("/").rsplit("/", 1)[-1])
    tamanho = propriedades.findtext(f"{ESPACO_DAV}getcontentlength")
    modificado = propriedades.findtext(f"{ESPACO_DAV}getlastmodified")
    if not nome or tamanho is None or modificado is None:
        raise ErroDeIngestao(f"{url}: item '{href}' da listagem sem nome, tamanho ou data")
    try:
        parsedate_to_datetime(modificado)
    except (TypeError, ValueError) as erro:
        raise ErroDeIngestao(f"{url}: data '{modificado}' de '{nome}' ilegível") from erro
    return ArquivoRemoto(nome=nome, bytes=int(tamanho), modificado=modificado)
