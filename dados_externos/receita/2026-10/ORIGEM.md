# Origem do extrato dos dados abertos do CNPJ, mês 2026-10

Gerado por `python -m ingestion.main --baixar receita`; não edite à mão. Mesma origem
e mesmo mês dão os mesmos arquivos.

- Compartilhamento oficial da Receita Federal: https://arquivos.receitafederal.gov.br/index.php/s/YggdBLfdninEJX9
- Pasta baixada (WebDAV público): https://arquivos.receitafederal.gov.br/public.php/webdav/2026-10/
- Mês: 2026-10
- Licença: Creative Commons Attribution (campo de licença do conjunto no dados.gov.br, sem a versão; consultado em 2026-11-10)
- Layout das colunas: https://www.gov.br/receitafederal/dados/cnpj-metadados.pdf (02/12/2021)
- Formato dos arquivos: sem cabeçalho, separador `;`, campos entre aspas, ISO-8859-1
  (`latin-1`), quebra de linha dentro de campo em Estabelecimentos. Cada registro está
  byte a byte como a Receita publicou.

## Arquivos baixados (37 zips, 7808752942 bytes)

A Receita não publica checksum; o sha256 foi calculado aqui. `registros` é a contagem
de registros do arquivo (uma quebra de linha dentro de campo não conta como registro).

| arquivo | bytes | modificado no servidor | sha256 | registros |
| --- | ---: | --- | --- | ---: |
| Cnaes.zip | 22078 | Tue, 13 Oct 2026 22:00:16 GMT | e3cee921b7055c2f77ecb92ab328603ac2adb099f883a94437382673133a36a9 | 1359 |
| Motivos.zip | 1180 | Tue, 13 Oct 2026 22:08:03 GMT | 0f9a0795f37a828d4f882800d39d4b5af3394276b34a6fba2bfa4d4ae83565eb | 63 |
| Municipios.zip | 43443 | Tue, 13 Oct 2026 22:08:04 GMT | e5521c91e7fa62879f441af8223e3ed07564c855105edc39939190c108411d4a | 5572 |
| Naturezas.zip | 1585 | Tue, 13 Oct 2026 22:08:05 GMT | c92728a7d9acc9535baa752a8fce1ebe100155909209df650af3771368e01986 | 92 |
| Paises.zip | 2745 | Tue, 13 Oct 2026 22:08:06 GMT | 9f2c4b89931626e1f15c3f4e78e58b525c10f4fbfe807f6dfe3dc4e6a78fbc7f | 255 |
| Qualificacoes.zip | 980 | Tue, 13 Oct 2026 22:08:07 GMT | 6e8600e3af8543be0fc2281bd24c08499bd81aa17dd76d7b8bffa58c1cbddba3 | 68 |
| Empresas0.zip | 570972127 | Tue, 13 Oct 2026 22:00:54 GMT | 0462e71efbf4e3d841c570176865b69c9ae7778a04014fa07145d99504327f7f | 30063698 |
| Empresas1.zip | 77901368 | Tue, 13 Oct 2026 22:01:01 GMT | 226713337ad77b876be58d7ac9cc92a7d9144f5780991515a0b3506b1a4a9900 | 4494860 |
| Empresas2.zip | 79125712 | Tue, 13 Oct 2026 22:01:07 GMT | d9ab5e05dd156bca6c207db7651c46e675600659c4301512c51dd89c08f4a55f | 4494860 |
| Empresas3.zip | 85102880 | Tue, 13 Oct 2026 22:01:14 GMT | 5b360ae214d61bc1392e053cc76dc751154e5d379ae962e640ce6ea919d57153 | 4494860 |
| Empresas4.zip | 90222463 | Tue, 13 Oct 2026 22:01:21 GMT | 7f7b726b0394112ee39bdda4e16b1a409cdd17dcadb2554e78b7508408deac25 | 4494860 |
| Empresas5.zip | 97310075 | Tue, 13 Oct 2026 22:01:28 GMT | 356cd0b1d33226204059054a4c59ef6a704fb8f68e182f02e5939dd8b89170f7 | 4494860 |
| Empresas6.zip | 94194819 | Tue, 13 Oct 2026 22:01:36 GMT | 9260ac6e25b6b11651fcf4b09ab57a03c2e9940edee4594fb2218837fe9898aa | 4494860 |
| Empresas7.zip | 98676055 | Tue, 13 Oct 2026 22:01:43 GMT | cacf2f5e184191aa6f5ced48c1ef727a745c343d73da5ad3836848fb36e9123e | 4494860 |
| Empresas8.zip | 98736571 | Tue, 13 Oct 2026 22:01:50 GMT | 2401492df8263624eef750e986d9e2e263a9f2b8802bf20a7a84bf77f030ced7 | 4494860 |
| Empresas9.zip | 94309858 | Tue, 13 Oct 2026 22:01:57 GMT | 366f667afb46474d040b9823217a092991b65e37cb3e62b0f3f07890e0493239 | 4494860 |
| Estabelecimentos0.zip | 2277696710 | Tue, 13 Oct 2026 22:04:26 GMT | d002212bd4bd4475ea7f963685c9a22de92a0915cfbe16f9699cfadc527244af | 31028464 |
| Estabelecimentos1.zip | 341948627 | Tue, 13 Oct 2026 22:04:51 GMT | 52cfe325265ea475d6e4b78a4d9e7624b039e28208e4cb13925bc698916536ec | 4753435 |
| Estabelecimentos2.zip | 336288966 | Tue, 13 Oct 2026 22:05:15 GMT | a5b1b86b944523a7ad906fe64b871f5b604edea40b5e028cf42a61a9784137ea | 4753435 |
| Estabelecimentos3.zip | 368597760 | Tue, 13 Oct 2026 22:05:40 GMT | ee333efe7fded32209b6722b19f7e155190a440c2eca5271b0829c468cbeff27 | 4753435 |
| Estabelecimentos4.zip | 340413465 | Tue, 13 Oct 2026 22:06:03 GMT | d5bda174a7683d2cf2045d981dc1c2a0c8070c356ad4e2dedcebaa8a81c575a6 | 4753435 |
| Estabelecimentos5.zip | 335452647 | Tue, 13 Oct 2026 22:06:26 GMT | 4f333a7f08ac505b7192be8ddf11ae133df61865f97388f856955afc31eaac22 | 4753435 |
| Estabelecimentos6.zip | 369782592 | Tue, 13 Oct 2026 22:06:50 GMT | 5fe17420df9aaae6d3b3814362bef693231bfe01221c28ad1e7bb64135b2100e | 4753435 |
| Estabelecimentos7.zip | 338419961 | Tue, 13 Oct 2026 22:07:14 GMT | d5bac9f97287f9739158197cc8d79425e5dd8da4aea8a3ef00b07ec415f3993f | 4753435 |
| Estabelecimentos8.zip | 343568209 | Tue, 13 Oct 2026 22:07:37 GMT | 97a50c93d70c048ee318b6d03ac65d6b4d5b59bc0ebd8923cd8773cf0ede5987 | 4753435 |
| Estabelecimentos9.zip | 364761032 | Tue, 13 Oct 2026 22:08:02 GMT | 732ad06ba3735de8c78b004f44c113e1329bd529f69a84d82127d11b683bb3f6 | 4753435 |
| Simples.zip | 310608217 | Tue, 13 Oct 2026 22:08:29 GMT | 1ce1aa57988265c1d554aacc6b1b6aae0da92b108d2940d34bdd43c51e99241e | 50806102 |
| Socios0.zip | 251430070 | Tue, 13 Oct 2026 22:08:47 GMT | 0c74c031ceb15ee26fb8ecb5bede7afc8b36c9babe5c92d8c569efabaf7633e6 | 10323611 |
| Socios1.zip | 49546399 | Tue, 13 Oct 2026 22:08:52 GMT | d914a9e516c7720bfe90fc2e4b161dc83a8d8d32e790e4fd8188272fba1a7e80 | 2019150 |
| Socios2.zip | 49056863 | Tue, 13 Oct 2026 22:08:56 GMT | d0549d15174fa1f06da778c993acad4b6844ba63291479d3ad68653acab51f5f | 2019150 |
| Socios3.zip | 49011621 | Tue, 13 Oct 2026 22:09:00 GMT | af60fb750c92a49f7d7f5c2bf40e745024568a079783d421f70efa1454c9eefb | 2019150 |
| Socios4.zip | 49560198 | Tue, 13 Oct 2026 22:09:04 GMT | 4546dc56d223874e56313c85136dbe0bec6d04dfef47e8a228d3013b828faf63 | 2019150 |
| Socios5.zip | 49063747 | Tue, 13 Oct 2026 22:09:08 GMT | 19a8fb3eb300f679d686afe555c3cd850c1f2d90202205187626cfe0acbd67eb | 2019150 |
| Socios6.zip | 49147194 | Tue, 13 Oct 2026 22:09:13 GMT | 69f7839460ee9d57a2ec77d9636d025586e5e9a5716c4a2d0284743d5086758d | 2019150 |
| Socios7.zip | 49212792 | Tue, 13 Oct 2026 22:09:17 GMT | 0c75bf39e835c513afccf126638f9dc40b298a10a1a748c2afa9de76db16d72a | 2019150 |
| Socios8.zip | 49447177 | Tue, 13 Oct 2026 22:09:21 GMT | 3deacf7bcdaad34af5ea297988c4799a8f7103fbd588ffd6bb46b29b4a906264 | 2019150 |
| Socios9.zip | 49114756 | Tue, 13 Oct 2026 22:09:25 GMT | 6db48faa857e1b6acb366a2a14e06a6ca7fa233aa49309f3a9c9bc3f0f7e50e0 | 2019150 |

## Extrato gravado nesta pasta

Tabelas de domínio inteiras (`cnaes`, `motivos`, `municipios`, `naturezas`, `paises`, `qualificacoes`); das demais, só os registros das raízes
de CNPJ listadas abaixo.

| arquivo | registros | bytes | sha256 |
| --- | ---: | ---: | --- |
| cnaes.csv | 1359 | 88215 | c25537f3f6da0069c7bc21c8b7898594d8ed8efc4569359520f13e525ea6a457 |
| motivos.csv | 63 | 2944 | ce7362420f9796920c1fb690762ba48c9273b202ebc2ca48dac544fb85fc8949 |
| municipios.csv | 5572 | 120435 | 2c78954e2eb93ee587d86917e95a028f6ef09386dafb76d359e0e3e0d7e81aad |
| naturezas.csv | 92 | 4215 | 8678a86a34e02f499c62a485ece32655ecaaec973108b02f6843a2f6b47d4113 |
| paises.csv | 255 | 5444 | cf3371ad48f6e78fa5ea2c44748e0112941eede63e8ac143eff3340e955d43ed |
| qualificacoes.csv | 68 | 2355 | 1bf54905b0370aa9b1473619e2d3b4036499e681eb5f375f79af40c89439d251 |
| empresas.csv | 10 | 705 | 8b2cb78d9cbaf984e9f5800b9a45617dd734bf7519a58ef1ece10883c2a60987 |
| estabelecimentos.csv | 32411 | 7554311 | 85485140f1b429549058f16b88b6cf786723c531c8757f17120801441ad6a6a5 |
| simples.csv | 4 | 252 | 5013b77b8fa58c633f2ea3b423b6ff90f2f0ae480a34a4ea7d83553cc32c8fa8 |
| socios.csv | 356 | 36295 | 69294264d0b77723ffe1d27294f6dab634344ade76679c696e9e9567676f7337 |

Registros sem raiz de 8 caracteres, fora do extrato: 0.

## Raízes de CNPJ recebidas (13)

sha256 da lista (raízes em ordem, uma por linha, sem linha final): 1f3c762d92c01c2355efa331c2eb822c78ad3bac10287dd7e7279f2319bfcd20

Encontradas na Receita: 10 de 13 raízes (as que têm ao menos um
registro no extrato). Registros por raiz e tabela:

| raiz | empresas | estabelecimentos | simples | socios |
| --- | ---: | ---: | ---: | ---: |
| 00000000 | 1 | 7903 | 1 | 41 |
| 00360305 | 1 | 6293 | 1 | 39 |
| 04182736 | 1 | 1 | 1 | 0 |
| 07526557 | 1 | 119 | 0 | 7 |
| 33000167 | 1 | 669 | 0 | 8 |
| 33592510 | 1 | 384 | 0 | 6 |
| 3RT8XB51 | 0 | 0 | 0 | 0 |
| 47960950 | 1 | 1916 | 0 | 5 |
| 51930487 | 1 | 1 | 1 | 0 |
| 60701190 | 1 | 5126 | 0 | 142 |
| 60746948 | 1 | 9999 | 0 | 108 |
| A7K2M9Q4 | 0 | 0 | 0 | 0 |
| Z0P4LC22 | 0 | 0 | 0 | 0 |
