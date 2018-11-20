import asyncdispatch, httpclient, strutils, json
{.passL: "-s".}
const open_elevation_url* = "https://api.open-elevation.com/api/v1/lookup" ## Open Elevation API URL

type
  OpenElevationBase*[HttpType] = object ## Base object.
    timeout*: byte  ## Timeout Seconds for API Calls, byte type, 0~255.
    proxy*: Proxy  ## Network IPv4 / IPv6 Proxy support, Proxy type.
  OpenElevation* = OpenElevationBase[HttpClient]           ##  Sync Open Elevation API Client.
  AsyncOpenElevation* = OpenElevationBase[AsyncHttpClient] ## Async Open Elevation API Client.

template clientify(this: OpenElevation | AsyncOpenElevation): untyped =
  ## Build & inject basic HTTP Client with Proxy and Timeout.
  var client {.inject.} =
    when this is AsyncOpenElevation: newAsyncHttpClient(
      proxy = when declared(this.proxy): this.proxy else: nil, userAgent="")
    else: newHttpClient(
      timeout = when declared(this.timeout): this.timeout.int * 1_000 else: -1,
      proxy = when declared(this.proxy): this.proxy else: nil, userAgent="")
  client.headers = newHttpHeaders({"dnt": "1", "accept":
    "application/json", "content-type": "application/json"})

proc lookup*(this: OpenElevation | AsyncOpenElevation, lat, lon: float32): Future[JsonNode] {.multisync.} =
  ## Open Elevation GET Endpoint for simple query of individual points (lat, lon).
  clientify(this)
  let
    url = open_elevation_url & "?locations=" & $lat & "," & $lon
    responses =
      when this is AsyncOpenElevation: await client.get(url=url)
      else: client.get(url=url)
  result = parse_json(await responses.body)

proc lookup*(this: OpenElevation | AsyncOpenElevation, locations: JsonNode): Future[JsonNode] {.multisync.} =
  ## Open Elevation POST Endpoint for bulk query of several points (locations JSON).
  assert locations.hasKey("locations"), "locations must have a 'locations' array"
  assert locations["locations"].len > 0, "locations must be a non-empty array"
  clientify(this)
  let
    responses =
      when this is AsyncOpenElevation: await client.post(url=open_elevation_url, body= $locations)
      else: client.post(url=open_elevation_url, body= $locations)
  result = parse_json(await responses.body)


when is_main_module and not defined(js):
  import parseopt, terminal, random
  {.passL: "-s", passC: "-flto -ffast-math", optimization: size.}
  const helpy = """
  Get the Elevation in Meters of any specific place in the world (0=Sea level),
  using the Open Elevation for OpenStreetMap API online services.

  For Uglyfied JSON use --ugly (does not reduce bandwith usage).
  This requires at least basic skills with JSON and OpenStreeMap.
  For more information and help check the Documentation.

  Para JSON Minificado afeado usar --fea (no reduce uso de ancho de banda).
  Requiere por lo menos conocimientos basicos de JSON y OpenStreeMap.
  Para mas informacion y ayuda ver la Documentacion.

  👑 https://github.com/juancarlospaco/nim-open-elevation#nim-open-elevation 👑

  Use:
  ./open_elevation --color --lower --timeout=9 --lat=42.5 --lon=55.75
  ./open_elevation --color --lower --timeout=9 '{"locations":[{"latitude":9,"longitude":10},{"latitude":41.68,"longitude":-8.58}]}'

  Uso (Spanish):
  ./open_elevation --color --minusculas --timeout=9 --lat=42.5 --lon=55.75
  ./open_elevation --color --minusculas --timeout=9 '{"locations":[{"latitude":9,"longitude":10},{"latitude":41.68,"longitude":-8.58}]}'
  """
  var
    lat, lon: float32
    taimaout = 99.byte
    minusculas, fea: bool
    json_query: JsonNode
  for tipoDeClave, clave, valor in getopt():
    case tipoDeClave
    of cmdShortOption, cmdLongOption:
      case clave
      of "version":             quit("0.1.5", 0)
      of "license", "licencia": quit("MIT", 0)
      of "help", "ayuda":       quit(helpy, 0)
      of "minusculas", "lower": minusculas = true
      of "ugly", "fea":         fea = true
      of "timeout":             taimaout = valor.parseInt.byte # HTTTP Timeout.
      of "lat", "latitude", "latitud":    lat = valor.parseFloat.float32
      of "lon", "longitude", "longuitud": lon = valor.parseFloat.float32
      of "color":
        randomize()
        setBackgroundColor(bgBlack)
        setForegroundColor([fgRed, fgGreen, fgYellow, fgBlue, fgMagenta, fgCyan, fgWhite].rand)
    of cmdArgument:
      json_query = clave.string.parseJson
    of cmdEnd: quit("Wrong Parameters, see Help with --help", 1)
  let
    clientito = OpenElevation(timeout: taimaout)
    respuesta = if json_query != nil: clientito.lookup(json_query) else: clientito.lookup(lat, lon)
    resultadito = if fea: $respuesta else: respuesta.pretty
  if minusculas: echo resultadito.toLowerAscii else: echo resultadito
