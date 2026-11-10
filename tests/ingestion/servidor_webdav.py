"""Servidor WebDAV falso na máquina local, só com o que o cliente usa: PROPFIND e GET com Range."""

import base64
import threading
from collections.abc import Iterator
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import quote, unquote

RESPOSTA = """<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
{itens}
</d:multistatus>"""

PASTA = """<d:response><d:href>{href}</d:href><d:propstat><d:prop>
<d:resourcetype><d:collection/></d:resourcetype></d:prop>
<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>"""

ARQUIVO = """<d:response><d:href>{href}</d:href><d:propstat><d:prop>
<d:getlastmodified>{modificado}</d:getlastmodified>
<d:getcontentlength>{tamanho}</d:getcontentlength><d:resourcetype/></d:prop>
<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>"""

MODIFICADO = "Tue, 13 Oct 2026 22:00:00 GMT"
PREFIXO = "public.php/webdav"


class Estado:
    """O que o servidor guarda: arquivos por pasta, o usuário esperado e o que já recebeu."""

    def __init__(self, pastas: dict[str, dict[str, bytes]], usuario: str):
        self.pastas = pastas
        self.usuario = usuario
        self.pedidos: list[tuple[str, str, str | None]] = []
        self.cortar_proximo_get_em: int | None = None
        self.ignorar_range = False


class Manipulador(BaseHTTPRequestHandler):
    """Atende um pedido; `estado` é preenchido na subclasse criada por `servidor`."""

    estado: Estado

    def log_message(self, *argumentos):
        pass

    def _responder_vazio(self, codigo: int) -> None:
        self.send_response(codigo)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _autorizado(self) -> bool:
        esperado = base64.b64encode(f"{self.estado.usuario}:".encode()).decode()
        if self.headers.get("Authorization") == f"Basic {esperado}":
            return True
        self._responder_vazio(401)
        return False

    def _pasta_e_nome(self) -> tuple[str, str]:
        partes = unquote(self.path).strip("/").removeprefix(PREFIXO).strip("/").split("/")
        return "/".join(partes[:-1]), partes[-1]

    def do_PROPFIND(self):
        self.estado.pedidos.append(("PROPFIND", self.path, None))
        if not self._autorizado():
            return
        pasta = unquote(self.path).strip("/").removeprefix(PREFIXO).strip("/")
        if pasta not in self.estado.pastas:
            self._responder_vazio(404)
            return
        base = f"/{PREFIXO}/{quote(pasta)}/"
        itens = [PASTA.format(href=base)]
        itens += [
            ARQUIVO.format(href=base + quote(nome), modificado=MODIFICADO, tamanho=len(dados))
            for nome, dados in self.estado.pastas[pasta].items()
        ]
        corpo = RESPOSTA.format(itens="".join(itens)).encode()
        self.send_response(207)
        self.send_header("Content-Type", "application/xml")
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)

    def do_GET(self):
        faixa = self.headers.get("Range")
        self.estado.pedidos.append(("GET", self.path, faixa))
        if not self._autorizado():
            return
        pasta, nome = self._pasta_e_nome()
        dados = self.estado.pastas.get(pasta, {}).get(nome)
        if dados is None:
            self._responder_vazio(404)
            return
        self._enviar(dados, faixa)

    def _enviar(self, dados: bytes, faixa: str | None) -> None:
        inicio = 0
        if faixa and not self.estado.ignorar_range:
            inicio = int(faixa.removeprefix("bytes=").rstrip("-"))
            self.send_response(206)
            self.send_header("Content-Range", f"bytes {inicio}-{len(dados) - 1}/{len(dados)}")
        else:
            self.send_response(200)
        corpo = dados[inicio:]
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        corte, self.estado.cortar_proximo_get_em = self.estado.cortar_proximo_get_em, None
        if corte is None:
            self.wfile.write(corpo)
            return
        self.wfile.write(corpo[:corte])
        self.wfile.flush()
        self.close_connection = True


@contextmanager
def servidor(pastas: dict[str, dict[str, bytes]], usuario: str = "TOKEN") -> Iterator[tuple]:
    """Sobe o servidor numa porta livre e devolve (endereço do WebDAV, estado)."""
    estado = Estado(pastas, usuario)
    http = ThreadingHTTPServer(
        ("127.0.0.1", 0), type("ManipuladorDoTeste", (Manipulador,), {"estado": estado})
    )
    fio = threading.Thread(target=http.serve_forever, daemon=True)
    fio.start()
    try:
        yield f"http://127.0.0.1:{http.server_port}/{PREFIXO}", estado
    finally:
        http.shutdown()
        http.server_close()
        fio.join()
