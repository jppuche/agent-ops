# agent-ops

![version](https://img.shields.io/badge/version-v0.11.0-blue) ![platform](https://img.shields.io/badge/platform-Windows-0078D6) ![license](https://img.shields.io/badge/license-MIT-green) ![built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-D97757)

[Read in English](README.md) | [Actualizar un proyecto (UPGRADING.md, en inglés)](UPGRADING.md) | [Changelog](CHANGELOG.md) | [Seguridad](SECURITY.md)

agent-ops es un kit de instrucciones, roles de subagentes, hooks y skills para llevar proyectos de Claude Code con orquestación multiagente y verificación explícita. No trabajas adentro de él: lo instalas una vez por máquina y creas cada proyecto nuevo desde él con un solo comando.

**Solo Windows.** Instalas una vez (`setup.ps1`) y después escribes `/init-project` en la carpeta de cada proyecto nuevo.

> **Idiomas:** esta guía existe en español y en inglés. El resto de los documentos del kit están en inglés a propósito: los consume Claude (el agente), y en inglés le cuestan menos tokens. No necesitas leerlos para usar el kit; Claude los lee por ti.

## Para quién es

Para quien ya usa Claude Code en trabajo que importa (código, pipelines de datos, investigación, recomendaciones) y ha visto cómo falla cuando nada lo revisa:

- varios agentes coinciden en algo falso, y la coincidencia se lee como confirmación;
- un resumen de investigación cita fuentes que nadie abrió, o una paráfrasis queda archivada como si fueran las palabras de la fuente;
- un subagente sin effort fijado hereda el más alto de la sesión y quema tokens en un trabajo chico;
- un modelo hace solo, en una sesión larga, lo que un revisor con contexto fresco habría atrapado en minutos.

El kit convierte cada una de esas fallas en una regla, un rol o un hook.

## Cuándo no usarlo

- **No estás en Windows.** Los hooks necesitan Windows PowerShell; en otro sistema solo funciona el método escrito.
- **El trabajo cabe en una sesión corta.** Los agentes extra compran tiempo de reloj y contexto limpio, no más acierto por token. El default del propio kit para trabajo chico y reversible es una sesión sin agentes.
- **Quieres adaptarlo a un repo que ya existe.** `/init-project` se detiene si la carpeta no está vacía. Hay un modo merge (pregunta antes de tocar cada archivo existente), pero el kit está hecho para carpetas nuevas.
- **Necesitas una ganancia medida.** El kit completo no se ha medido contra trabajar sin él (ver *Estado y límites*).

## Estado y límites

- Es el kit de trabajo de una persona, publicado tal cual.
- **Solo Windows y PowerShell.** En otro sistema operativo la capa que hace cumplir las reglas (gate de commit, líneas de cierre, captura de prompts, log de uso) no corre.
- Sigue a Claude Code y a los modelos a la fecha `last_verified` de [`system/model-playbook.md`](system/model-playbook.md), y envejece rápido. Si esa fecha tiene más de unas semanas, revisa su sección 1 contra las páginas actuales del proveedor antes de confiar en una fila de staffing.
- Lo medido es qué modelo y qué effort usa cada rol, en A/B chicos (k = 3 como mucho). Los fixtures y los evaluadores no están publicados: las cifras son un reporte, no algo auditable desde aquí.
- Nada se ha medido en el modelo Fable más nuevo; sus filas son guía del proveedor o inferencia.
- `--domain` es un punto de extensión. El repo no trae ningún kit de dominio.

## Requisitos

- Windows con PowerShell 5.1 o superior.
- Git for Windows. `init-project` copia archivos con `cp` y `mkdir -p`, así que Claude Code necesita Git Bash.
- Claude Code v2.1.321 o superior. Las versiones anteriores ignoran algunos settings sin aviso: el límite de escritura pide la v2.1.314, el effort por llamada la v2.1.292 y el alias `fable` la v2.1.321.
- Un plan pago de claude.ai o acceso por API. Fable (el modelo más alto) puede necesitar créditos de uso según tu plan, y en corridas con `claude -p` o con el Agent SDK los cobra sin pedir confirmación. El bloque *Environment* del `CLAUDE.md` de cada proyecto dice qué se puede gastar.
- Opcional: Python, solo para los hooks y tests de Cerbero (3.10 o superior) y su escáner de MCP (3.11 a 3.13); ver `skills/cerbero/setup-guide.md`. Los hooks propios del kit solo necesitan PowerShell.

Para revisar lo que tienes:

```powershell
$PSVersionTable.PSVersion
git --version
claude --version
```

## Instalar

Corre esto en Windows PowerShell. Sirve cualquier carpeta estable fuera de tus proyectos; aquí se usa `$HOME\agent-ops`.

Primero revisa que no tengas skills con los cuatro nombres del kit. **El setup las sobrescribe sin preguntar y sin respaldo:**

```powershell
Get-ChildItem "$HOME\.claude\skills" -Directory -ErrorAction SilentlyContinue | Where-Object Name -in 'init-project','agent-dispatch','cerebrate','cerbero'
```

Si aparece algo, muévelo a otro lado. Después:

```powershell
git clone https://github.com/jppuche/agent-ops.git "$HOME\agent-ops"
```

```powershell
cd "$HOME\agent-ops"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

`-ExecutionPolicy Bypass` aplica solo a ese proceso. No cambia la política de tu máquina, que en un Windows recién instalado bloquea `.\setup.ps1`. Reinicia Claude Code después de la primera instalación.

`main` puede traer cambios listados como *Unreleased* en el changelog. Para quedarte en una versión publicada, cambia a su tag (`git -C "$HOME\agent-ops" checkout v0.11.0`).

## Qué cambia

**En tu máquina (`setup.ps1`).** Copia cada carpeta de `skills/` (cuatro hoy) a `~/.claude/skills/`, sobrescribiendo los archivos con el mismo nombre, y escribe `~/.claude/agent-ops-home.txt` con la ruta del clon. Nada más: ni hooks, ni settings, ni cambios al PATH, ni red, ni permisos de administrador.

Las skills a nivel usuario se cargan en **todas** las sesiones de Claude Code de esa máquina, no solo en los proyectos del kit. Claude puede arrancar `agent-dispatch`, `cerebrate` e `init-project` por su cuenta cuando una tarea calza. `init-project` y `cerebrate` muestran su plan y esperan tu respuesta antes de escribir, pero esa espera es una instrucción al modelo, no un prompt de permisos: en modo auto o bypass es el único freno.

**En cada proyecto (`/init-project`).** Solo escribe dentro de la carpeta que le indicas. Instala `.claude/settings.json` con siete handlers de hooks sobre cuatro scripts de `system/scripts/`, cada uno corrido como `powershell -NoProfile -ExecutionPolicy Bypass -File <script>`. Se disparan al abrir sesión, antes de un `git commit` y alrededor de cada subagente; ninguno usa la red ni borra nada. Los logs van a `outputs/fanouts/`: `_dispatched-prompts.jsonl` guarda cada prompt de subagente tal cual y está en el gitignore; los logs de uso y de líneas de cierre guardan ids y conteos de tokens. El hook de uso lee los transcripts de subagentes en `~/.claude/projects/`, solo lectura. El mismo archivo activa el límite de escritura (ver *Los hooks*).

`.claude/settings.json` se commitea con el proyecto, así que cualquiera que lo clone y confíe en la carpeta corre los mismos hooks. Lee `system/scripts/` antes de activarlos, y revisa [SECURITY.md](SECURITY.md).

## Empezar un proyecto

1. Crea una carpeta vacía para el proyecto, fuera del kit.
2. Abre Claude Code ahí y escribe `/init-project`, o pide con palabras un proyecto nuevo de agent-ops. Te muestra los datos que recogió y no escribe nada hasta que los confirmes.
3. Responde sus preguntas: el nombre del proyecto, una línea de qué hace y quién lo consume, un stakeholder (nombre y rol, o el equipo dueño), la ruta absoluta de la carpeta y el tipo: `build` (código, pipeline de datos, automatización, API), `research` (responder una pregunta desde fuentes) o `advisory` (comparar opciones y recomendar). `build` instala siete roles; `research` y `advisory` instalan cinco (el nivel `core`, sin `executor` ni `operator`). También ofrece `git init` (por defecto no).

El resultado:

```text
mi-proyecto/
  CLAUDE.md               instrucciones del proyecto (edita primero su bloque Environment)
  .gitignore
  .claude/settings.json   hooks + límite de escritura
  .claude/agents/         5 o 7 archivos de roles
  system/                 docs del método + scripts de hooks, copiados tal cual
  docs/                   status, scratchpad, decisions, lessons-learned, dev-changelog, cerebrate-log/
  outputs/fanouts/        logs de los hooks
```

Después abre una sesión nueva de Claude Code en la carpeta del proyecto: los roles copiados a mitad de sesión no se pudieron despachar en la sesión que los copió (observado en una máquina, 2026-11-13; Claude Code v2.1.326 lista un fix para esto, todavía sin re-probar en el kit).

## Actualizar

**El kit**: `git -C "$HOME\agent-ops" pull`, y vuelve a correr `setup.ps1` (el mismo comando de *Instalar*) si el pull tocó `skills/`. Las skills actualizadas se recargan sin reiniciar. Los proyectos nuevos salen con la versión nueva.

**Un proyecto existente** no se actualiza solo: es una copia del kit al momento de su `/init-project`. Anota desde el primer día en su `docs/status.md` la versión del kit con la que arrancó (`git -C "$HOME\agent-ops" describe --tags`). Para traerlo al día, aplica [UPGRADING.md](UPGRADING.md) desde esa versión en adelante y abre una sesión nueva de Claude Code para que carguen los roles que cambiaron.

**Mejorar el kit**: cuando un proyecto muestre un patrón nuevo o un hueco del método, anótalo ahí (`docs/lessons-learned.md`, o el `/cerebrate` de cierre). Cuando se confirme dos o tres veces, abre un issue ([CONTRIBUTING.md](CONTRIBUTING.md)).

## Desinstalar

Borra las cuatro carpetas de skills en `~/.claude/skills/` y el archivo `~/.claude/agent-ops-home.txt`. Un proyecto creado con el kit sigue funcionando como archivos sueltos. Para apagar sus hooks, quita el bloque `hooks` de su `.claude/settings.json`; quita el bloque `permissions` para levantar el límite de escritura. Los hooks de Cerbero, si los instalaste, se quitan igual que como los puso `skills/cerbero/setup-guide.md`.

## Términos

- **Instancia**: un proyecto creado desde el kit; una copia, no un enlace.
- **Docs vivos**: `docs/status.md`, `decisions.md`, `lessons-learned.md` y compañía, que el agente mantiene al día.
- **Orquestador**: la sesión principal de Claude Code, la que integra y decide.
- **Fan-out**: varios subagentes despachados en paralelo sobre partes de una misma pregunta.
- **Gate**: un chequeo que un cambio tiene que pasar antes de salir. Un gate de validación completo lleva como mínimo `fidelity-verifier` + `domain-analyst` + `adversarial-reviewer`.
- **Effort**: el ajuste de profundidad de razonamiento de Claude Code (`low` a `max`); el kit lo fija por rol.
- **Hand-back**: el reporte final de un subagente.
- **Líneas de cierre**: las líneas `CHECKED:` / `NOT CHECKED:` con las que tiene que terminar el reporte de cada rol.
- **Fable**: el nivel de modelo más alto de Anthropic, por encima de Opus. **Advisor**: `/advisor`, consultar a un modelo más fuerte en momentos de decisión.
- **Nivel (tier)**: qué roles recibe un proyecto (`core` 5, `build` 7).
- **Kit de dominio** (`--domain`): una capa opcional de carpetas y docs extra para un tipo de trabajo; aquí no viene ninguno.

## Qué hay adentro

| Ruta | Qué es |
|---|---|
| `CLAUDE.md.template` | El `CLAUDE.md` que instancia cada proyecto (reglas, routing, convenciones; menos de 200 líneas) |
| `system/` | El método: orquestación, staffing de modelo y effort, el contrato de revisión, la plantilla de investigación, los scripts de hooks |
| `agents/` | Siete definiciones de subagentes, cada una con sus herramientas, familia de modelo y effort fijados |
| `skills/` | `init-project`, `agent-dispatch`, `cerebrate`, `cerbero` |
| `docs-seed/` | Las semillas de los docs vivos de cada proyecto (status, scratchpad, decisions, lessons, changelog) |
| `setup.ps1` | Instala las skills a nivel usuario y graba dónde vive el kit |
| `CLAUDE.md` | La guía para mantener el kit en sí. No corras un proyecto desde el clon: Claude seguiría estas instrucciones en vez de las del proyecto |

## Las ideas centrales

**El orquestador integra y decide.** Los agentes producen hallazgos; nunca editan el artefacto que revisan. La sesión principal aplica el arreglo.

**El 2x2 que dimensiona el rigor.** Antes de delegar, el agente ubica la tarea en dos ejes: el costo de un error (reversible o no, interno o de cara a alguien) y la necesidad de síntesis (alcanza una fuente, o hay varias que pueden contradecirse). Eso da cuatro modos. El rigor es una decisión; el vehículo (subagentes, un team, un workflow) y el modelo son otras. Ver [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

| | Alcanza una fuente | Hay que triangular fuentes |
|---|---|---|
| **Barato de deshacer** | DIRECT: sin agentes | AGENTS LIGHT: uno o dos en paralelo |
| **Caro de deshacer** | VERIFIED: un spot-check de un lector fresco | FULL SYSTEM: un fan-out más una ronda escéptica |

**El contrato de revisión.** Cada hallazgo que devuelve un agente revisor lleva un locator (`file:line`, una query, una sección), una etiqueta de procedencia (lo leyó, lo infirió, lo asumió) y una línea `falsified_by`: el chequeo barato que lo refutaría. El orquestador vuelve a verificar por su cuenta los hallazgos que deciden. Ver [`system/verification-contract.md`](system/verification-contract.md).

**La prueba de independencia.** Antes de sumar un paso de verificación, pregúntate: *¿este paso puede fallar independientemente del primero?* Otra fuente u otro razonador fresco se queda; el mismo modelo releyendo la misma evidencia ("revisa tu trabajo") se corta. Ver [`system/model-playbook.md`](system/model-playbook.md) sec 5.

**Datos exactos nunca a través de un modelo.** Hashes, ids, nombres de settings y números largos no viajan por un fetch que resume. En un caso de campo, 10 de 10 hashes leídos con WebFetch eran plausibles y falsos; `curl` más un parser lo atrapó. Ver [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

**Se divide por contexto, no por rol.** Un subagente o una sesión paralela recibe un pedazo que necesita poco del resto y devuelve algo compacto. Repartir una funcionalidad entre diseñador, implementador y tester convierte cada traspaso en un resumen que pierde detalle. Ver [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

**Nunca le topes la severidad a un revisor.** Si le dices "solo lo crítico", un modelo puede reportar menos. Se acota el dominio, no el umbral.

**Convergencia no es evidencia.** Agentes que coinciden pueden compartir una premisa y no una verdad. Los verificadores en paralelo reciben ángulos distintos, y solo un contraste con el artefacto (un grep, una query, un fetch) resuelve un claim. Ver [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 1 y 5.

**La configuración de trabajo.** Al arrancar, el agente propone en dos o tres líneas cómo debería correr el proyecto (modelo de la sesión principal, una sesión o agentes, qué gate pasa un cambio riesgoso) y lo anota en `docs/status.md`. Solo lo reevalúa ante seis eventos (un plan grande, un supuesto que se cayó, una acción irreversible, dos intentos fallidos, un contexto pesado, el cierre de un bloque) y no dice nada si la configuración sigue sirviendo. "Una sesión, sin agentes" es una respuesta válida. Ver [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

**Staffing medido por rol.** El modelo y el effort de cada rol están fijados en su definición, y las filas marcadas como medidas se apoyan en A/B chicos registrados con sus reglas, corridas y costos. Ver [`system/model-measurements.md`](system/model-measurements.md) y [`system/model-playbook.md`](system/model-playbook.md) sec 2.

## Los roles

Cada rol fija sus herramientas, su familia de modelo y su effort en su definición.

| Rol | Modelo, effort | Qué hace |
|---|---|---|
| `fidelity-verifier` | `haiku`, `high` | ¿El artefacto coincide con la verdad del proyecto (datos, código, configuración)? Solo lectura por instrucción: necesita `Bash` para correr chequeos |
| `domain-analyst` | `opus`, `medium` | ¿El cambio calcula lo que el dominio quiere decir, qué outputs mueve y qué decisión (con su dueño) autoriza cada uno? Solo lectura por construcción |
| `adversarial-reviewer` | `opus`, `medium` | Abogado del diablo sobre un artefacto escrito: hipótesis rivales, supuestos ocultos, sobreinterpretación. Solo lectura por construcción |
| `web-researcher` | `sonnet`, `high`, 30 turnos | Una pregunta acotada de la web, o una lista de claims externos a verificar; prefijo de investigación incluido, sin herramientas de archivos |
| `executor` (nivel `build`) | `opus`, `medium` | El único rol que escribe el producto de trabajo; persiste entre rondas de arreglo |
| `operator` (nivel `build`) | `haiku`, `high` | Checklists GO/NO-GO de pre-vuelo y post-vuelo; todo dato secundario tiene que salir de un comando que corrió |
| `extractor` | `haiku`, `high`, 40 turnos | Saca campos de archivos nombrados a una tabla con ubicación y una línea `COVERAGE:`; copia, nunca juzga |

Los tres primeros forman el mínimo de un gate de validación completo. Cada rol cierra con líneas fijas (`CHECKED:` / `NOT CHECKED:`); si faltan, el rol se devuelve a trabajar como mucho dos veces, y un rol en `haiku` que se niega o sigue incompleto después de eso se re-despacha en un modelo más fuerte, no se reanuda.

## Los hooks

`init-project` los instala en cada proyecto; los scripts viven en `system/scripts/` ([README](system/scripts/README.md)):

- **SessionStart**: `check-docs.ps1` le reporta al agente links rotos, fechas viejas y placeholders sin resolver.
- **Gate de commit**: el mismo script bloquea un `git commit` si hay un error crítico, tanto por la herramienta Bash como por la de PowerShell.
- **Captura de prompts**: cada prompt de subagente despachado, con su modelo y effort, va a un log de auditoría.
- **Log de uso**: los tokens por request de cada subagente que termina, para comparar lo que de verdad cuesta un rol.
- **Líneas de cierre**: un rol del kit cuyo reporte no trae sus líneas de cierre se devuelve a trabajar, como mucho dos veces.
- **Límite de escritura** (un setting, no un hook): `permissions.blockWritesOutsideWorkingDirectories` hace que Claude Code (v2.1.314 o superior) rechace ediciones de archivos fuera de los directorios de trabajo del proyecto. No cubre comandos de shell. También quita `EnterWorktree` y `ExitWorktree`, así que una sesión no puede moverse sola a un git worktree: arráncala con `claude --worktree`, o revisa el [README de los scripts](system/scripts/README.md) para las otras salidas.

## Las skills

- **`init-project`**: crea un proyecto desde el kit; escribe `/init-project` o pídelo con palabras.
- **`agent-dispatch`**: el procedimiento que Claude carga antes de delegar (si delegar, qué vehículo, modelo, effort, cómo redactar el prompt).
- **`cerebrate`**: la reflexión al cierre de un bloque. Destila lo que aprendió una sesión hacia los docs vivos. Puedes escribir `/cerebrate`, o el agente la arranca cuando cierra un bloque; en ambos casos muestra su plan y espera tu aprobación antes de escribir.
- **`cerbero`**: la revisión de seguridad que se corre antes de instalar cualquier servidor MCP o skill de terceros. `skills/cerbero/` se sincroniza desde [Cerbero](https://github.com/jppuche/Cerbero) (MIT, mismo autor); sus hooks se instalan aparte (`skills/cerbero/setup-guide.md`).

## Si algo se rompe

- **`setup.ps1` no se puede cargar / la ejecución de scripts está deshabilitada**: usa la forma `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1` de *Instalar*.
- **`/init-project` no aparece**: corre `setup.ps1` desde el kit y, si es la primera instalación, reinicia Claude Code (cierra todas las ventanas).
- **"Agent type not found" justo después de `/init-project`**: abre una sesión nueva de Claude Code en el proyecto; los roles copiados a mitad de sesión no se pudieron despachar en esa sesión.
- **Un commit se bloquea por un "broken ref"**: el gate encontró un link roto en un doc. Arregla el link.
- **`check-docs.ps1` se queja dentro del propio kit**: es esperado. El kit tiene semillas (`docs-seed/`), no docs vivos; el checker está hecho para un proyecto instanciado.
- **Los hooks corren scripts de otro proyecto**: la sesión se movió entre carpetas y conservó la ruta del proyecto original. Abre una sesión nueva en el proyecto.
- **Falta `EnterWorktree`**: el límite de escritura lo quita; ver *Los hooks*.

## Licencia

MIT, ver [LICENSE](LICENSE). `skills/cerbero/` viene de [Cerbero](https://github.com/jppuche/Cerbero), también MIT, del mismo autor. Reportes de seguridad: [SECURITY.md](SECURITY.md).

## Contribuir

Los issues son bienvenidos, y los pull requests pequeños también; no hay garantía de respuesta. Ver [CONTRIBUTING.md](CONTRIBUTING.md).
