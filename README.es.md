# agent-ops

![version](https://img.shields.io/badge/version-v0.11.0-blue) ![platform](https://img.shields.io/badge/platform-Windows-0078D6) ![license](https://img.shields.io/badge/license-MIT-green) ![built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-D97757)

[Read in English](README.md) | [Changelog](CHANGELOG.md) | [Actualizar un proyecto (en inglés)](UPGRADING.md) | [Seguridad](SECURITY.md)

**Un manual que le das a Claude Code para que organice el trabajo serio como lo haría un líder de equipo con experiencia:** decide cuándo un trabajo necesita ayudantes y cuándo no, elige qué modelo de Claude y cuánto razonamiento recibe cada parte, y revisa los resultados antes de decirte que están listos.

Es un conjunto de archivos de texto para Claude Code en Windows: instrucciones, unas cuantas definiciones de ayudantes y algunos chequeos automáticos pequeños. Lo hizo una persona para su propio trabajo y lo publica tal cual. Esta página va del lenguaje sencillo al detalle técnico; detente cuando tengas lo que necesitas.

> **Idiomas:** esta guía existe en español y en inglés. El resto de los documentos del kit están en inglés a propósito: los consume Claude, y en inglés le cuestan menos tokens. No necesitas leerlos para usar el kit.

---

## En un minuto

**El problema.** Claude Code es capaz, y ahora puede lanzar agentes ayudantes, correr sesiones en paralelo y cambiar entre modelos de distinto costo y potencia. Pero por su cuenta se apoya en lo que recuerda de esas opciones, y esa memoria envejece en semanas. También puede gastar de más en un trabajo chico, o revisar de menos uno grande. Y cuando varios agentes coinciden, la coincidencia puede parecer una prueba sin serlo.

**Qué hace el kit.** Le da a Claude un método escrito y actualizado con frecuencia, y lo pone donde Claude lo va a encontrar en el momento justo. Piensa en entregarle a un colega capaz el manual del equipo en su primer día. Cada proyecto conserva la copia con la que empezó hasta que le pidas a Claude actualizarlo. Ante una tarea, Claude puede decirte en concreto:

- *"Esto es chico. Lo hago yo."*
- *"Esto pide cuatro investigadores en un modelo intermedio con effort alto (más razonamiento por paso), y dos revisores en el modelo más fuerte. Este es el porqué, y esto cuesta frente a hacerlo solo."*
- *"Esto merece sesiones paralelas que se hablen: una para la base de datos, otra para la API, y una líder que coordina."*

**Qué no hace.** No vuelve más inteligente a Claude ni le da permisos nuevos: todo sigue corriendo en tu sesión, bajo tus ajustes de permisos de Claude Code. Algunos chequeos pequeños sí corren solos: al abrir sesión, antes de un commit y alrededor de cada ayudante (ver [Qué cambia](#qué-cambia)).

## ¿Es para ti?

**Probablemente sí** si usas Claude Code en trabajo que importa (código, datos, investigación, recomendaciones) y quieres que:

- elija la forma de trabajar de cada tarea con información actual y no de memoria;
- revise su trabajo de maneras que de verdad atrapen errores;
- deje un registro de decisiones y de estado que sobreviva de una sesión a otra.

**Probablemente no** si:

- **No estás en Windows.** Los chequeos automáticos necesitan Windows PowerShell; en otro sistema solo funciona el método escrito.
- **Tus tareas son cortas.** Los agentes extra compran velocidad y un espacio de trabajo limpio, no más respuestas correctas por token. Para trabajo rápido, el consejo del propio kit es una sesión sin ayudantes. Te cuesta poco, pero suma poco.
- **Tu sesión principal corre en Sonnet o Haiku.** El método está escrito para una sesión principal en Opus o Fable. Funciona en modelos más chicos, pero llenan la ficha de planificación con menos constancia.
- **Quieres meterlo en un repo que ya existe.** Está hecho para carpetas de proyecto nuevas. Hay un modo merge, pero no es el camino principal.
- **Necesitas prueba de que ayuda, o soporte.** Se ha probado en corridas chicas, no medido a escala (ver [Estado y límites](#estado-y-límites)), y los issues pueden no tener respuesta.

**Lo que cuesta.** Cada sesión en un proyecto del kit carga unos 4K tokens de instrucciones y estado, y las cuatro skills del kit suman unos cientos de tokens de descripciones a todas las sesiones de Claude Code de tu máquina. Planificar una tarea con el kit costó unos 40K tokens más que sin él en las pruebas del mantenedor, cerca de 1,7 veces. Un gate de validación completo corre tres revisores, dos de ellos en Opus. Lo que eso compró: sin el kit, Claude eligió niveles de effort que la guía actual de Anthropic contradice. Las pruebas son chicas y no están publicadas, así que tómalo como un reporte ([Estado y límites](#estado-y-límites)).

---

## Cómo se usa

**Lo que repites es la conversación.** La instalación se hace una vez, y Claude puede hacer casi toda por ti (sección siguiente). En el día a día hablas con Claude en la carpeta de tu proyecto como siempre. Estos pedidos son los que ponen el kit a trabajar:

| Quieres... | Di algo como | Qué hace Claude |
|---|---|---|
| Empezar un proyecto nuevo | *"/init-project"*, o *"arranca aquí un proyecto nuevo de agent-ops"* | Hace unas preguntas (nombre, propósito, para quién es, tipo), te muestra el plan y arma la carpeta del proyecto cuando confirmas |
| Resolver una tarea chica | Solo pídela | La hace directo. El kit le dice que no haga ceremonia con trabajo chico y reversible |
| Planificar una tarea grande | *"¿Cómo organizarías esto y cuánto costaría?"* | Propone un vehículo (una sesión, ayudantes, sesiones paralelas o un workflow), el modelo y el effort de cada parte, el chequeo que correría y el costo frente a hacerlo solo. Espera tu visto bueno |
| Investigar algo en la web | *"Investiga X en la web y verifica los datos de los que depende mi decisión."* | Manda a un investigador sin acceso a tus archivos, recibe datos etiquetados por fuente y confianza, y después re-verifica él mismo los decisivos en las páginas originales |
| Asegurarte de que algo está bien antes de entregarlo | *"Revísalo bien antes de entregarlo."* | Ajusta el chequeo a lo que está en juego: nada para un cambio chico y reversible, un revisor fresco para uno riesgoso, y para uno de alto impacto tres revisores independientes desde ángulos distintos (¿coincide con los datos?, ¿significa lo que debe?, ¿qué se pasó por alto?). Claude pondera lo que encuentran, aplica los arreglos y vuelve a revisar, como mucho tres rondas antes de preguntarte |
| Saber dónde estamos | *"¿Dónde estamos?"* | Lee el archivo de estado del proyecto, que mantiene al día |
| Cerrar un tramo de trabajo | *"/cerebrate"* | Destila lo aprendido hacia las notas del proyecto, y te muestra el plan antes de escribir nada |
| Traer un proyecto a un kit más nuevo | *"Actualiza el kit y pon este proyecto al día."* | Actualiza el kit, vuelve a correr su instalación y aplica las notas de actualización para la versión de tu proyecto |

No necesitas aprender el vocabulario del método: pide con palabras normales. Los términos están en [Términos](#términos) si los quieres.

**Lo que pasa sin que lo pidas.**
- Al abrir sesión, Claude recibe un informe corto de salud de los docs del proyecto: links rotos, fechas viejas, un kit desactualizado.
- Un `git commit` se bloquea si ese chequeo encuentra un error crítico, como un link roto.
- Claude propone otra forma de trabajar por su cuenta solo en unos pocos momentos: antes de un plan grande o difícil de deshacer, cuando se cae un supuesto, antes de un paso irreversible, después de dos intentos fallidos y al cerrar un bloque de trabajo. El resto del tiempo no dice nada al respecto.

---

## Para empezar

### Qué necesitas

- Windows con PowerShell 5.1 o superior, y Git for Windows (Claude Code usa su Git Bash).
- Claude Code v2.1.321 o superior.
- Un plan pago de claude.ai o acceso por API. Fable (el modelo más alto) puede necesitar créditos de uso según tu plan, y en corridas con `claude -p` o con el Agent SDK los cobra sin pedir confirmación.
- Opcional: Python, solo para los hooks y tests de Cerbero (3.10 o superior) y su escáner de MCP (3.11 a 3.13). Los hooks propios del kit solo necesitan PowerShell.

```powershell
$PSVersionTable.PSVersion
git --version
claude --version
```

### Deja que Claude lo instale

Abre Claude Code en cualquier carpeta y pega:

> Instala el kit agent-ops desde https://github.com/jppuche/agent-ops en una carpeta llamada agent-ops dentro de mi perfil de usuario. Lee setup.ps1 y dime en dos líneas qué hace. Luego revisa si ya tengo skills llamadas init-project, agent-dispatch, cerebrate o cerbero en .claude\skills dentro de mi perfil de usuario; si es así, detente y muéstramelas. Si no, corre setup.ps1 con powershell -NoProfile -ExecutionPolicy Bypass -File, y dime qué cambió.

Claude Code te pide permiso antes de clonar el repositorio y antes de correr el script. Es lo esperado: aprueba cada uno cuando hayas leído qué va a hacer.

Después reinicia Claude Code una vez, crea una carpeta vacía para tu primer proyecto, abre Claude Code ahí y di *"/init-project"*. Cuando termine:

- Lee el bloque *Environment* del `CLAUDE.md` del proyecto: dice qué puede gastar el proyecto (por ejemplo, si puede usar créditos de uso). Edítalo, o pídeselo a Claude.
- Abre una sesión nueva de Claude Code en la carpeta del proyecto antes de pedir cualquier ayudante: un ayudante agregado durante una sesión puede no encontrarse hasta la siguiente.

### O instálalo tú

<details>
<summary>Los pasos manuales</summary>

Córrelos en Windows PowerShell. Sirve cualquier carpeta estable fuera de tus proyectos; aquí se usa `$HOME\agent-ops`.

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

</details>

**Qué versión recibes.** El clon sigue a `main`, que es lo que describe esta página. La última versión publicada, v0.11.0, es anterior a la ficha de planificación y a los chequeos de frescura. `main` avanza entre versiones, y la corrida semanal de mantenimiento del kit puede mergear actualizaciones de documentación en él (ver [Se mantiene al día](#se-mantiene-al-día)).

### Cómo queda un proyecto nuevo

`/init-project` pregunta:
- el nombre del proyecto;
- una línea sobre qué hace y quién lo consume;
- un stakeholder (nombre y rol, o el equipo dueño);
- la ruta absoluta de la carpeta;
- el tipo: `build` (código, pipeline de datos, automatización, API), `research` (responder una pregunta desde fuentes) o `advisory` (comparar opciones y recomendar).

`build` instala siete roles ayudantes; los otros dos tipos instalan cinco. También ofrece `git init`.

```text
mi-proyecto/
  CLAUDE.md               instrucciones del proyecto (edita primero su bloque Environment)
  .gitignore
  .claude/settings.json   hooks + límite de escritura
  .claude/agents/         5 o 7 archivos de roles
  system/                 docs del método + scripts de hooks, copiados tal cual
  docs/                   status (con la versión del kit de la que salió), scratchpad, decisions,
                          lessons-learned, dev-changelog, cerebrate-log/
  outputs/fanouts/        logs de los hooks
```

---

## Cómo funciona

### Tres decisiones, separadas

En cada tarea Claude resuelve tres cosas, y el kit las mantiene separadas porque mezclarlas es de donde sale el desperdicio:

1. **Cuánta revisión** pide la tarea. Es el *2x2*: lo que costaría un error, frente a cuántas fuentes hay que conciliar.
2. **Qué vehículo** lleva el trabajo: una sesión, agentes ayudantes, sesiones paralelas, un workflow, un agent team.
3. **Qué modelo y qué effort** usa cada parte.

| | Alcanza una fuente | Hay que triangular fuentes |
|---|---|---|
| **Barato de deshacer** | DIRECT: sin agentes | AGENTS LIGHT: uno o dos en paralelo |
| **Caro de deshacer** | VERIFIED: un spot-check de un lector fresco | FULL SYSTEM: un fan-out más una ronda escéptica |

La respuesta queda escrita como una **ficha de configuración** en el `docs/status.md` del proyecto. La ficha nombra el vehículo, y el modelo, effort y alcance de la sesión principal y de cada worker, además del chequeo y el costo frente a la alternativa.

Un proyecto arranca con un default anotado: una sesión con el effort por defecto del modelo principal. Una tarea que se resuelve en un puñado de llamadas no lleva ficha. La ficha se reevalúa solo ante los cinco eventos de *Lo que pasa sin que lo pidas*. Ver [`system/agent-orchestration.md`](system/agent-orchestration.md) sec 2.

### Cuándo pagan los ayudantes

El kit sigue las mediciones de la propia Anthropic. Delegar rindió en dos situaciones: trabajo rutinario con una cola larga de costo, y trabajo más grande que una ventana de contexto. Para una cadena de pasos dependientes, o para trabajo que cabe en un contexto, el modelo principal solo y con menos effort lo hizo mejor.

Los ayudantes también se ganan su lugar para correr en paralelo, para sacar del camino salidas ruidosas y para dar una revisión independiente. Proteger la ventana de contexto ya no es razón por sí sola.

### Revisión que de verdad atrapa errores

- **Convergencia no es evidencia.** Agentes que coinciden pueden compartir una premisa y no una verdad. Solo un contraste con el artefacto (un grep, una query, la página original) resuelve un dato.
- **La prueba de independencia.** Un paso de verificación se queda solo si puede fallar independientemente del primero (otra fuente, un revisor fresco). "Revisa tu trabajo" se corta. Ver [`system/model-playbook.md`](system/model-playbook.md) sec 5.
- **El contrato de revisión.** Cada hallazgo dice:
  - dónde está (`file:line`, una query, una sección);
  - cómo se sabe (leído, inferido, asumido);
  - qué chequeo barato lo refutaría.

  La sesión principal re-verifica los hallazgos que deciden algo. Ver [`system/verification-contract.md`](system/verification-contract.md).
- **Datos exactos nunca a través de un modelo.** Hashes, ids, nombres de settings y números largos se leen con una herramienta determinista, no con un fetch que resume. En un caso de campo, 10 de 10 hashes leídos a través de un resumen eran plausibles y falsos. Una re-prueba posterior acertó 4 de 4; es una sola corrida, así que la regla se queda.
- **Nunca le topes la severidad a un revisor.** Si le dices "solo lo crítico", un modelo puede reportar menos. Acota el tema, no el umbral.

### La web se trata como hostil

Las páginas pueden traer instrucciones dirigidas a agentes. La respuesta del kit es sobre todo de fronteras:

- **El rol `web-researcher`** no tiene herramientas de archivos ni de shell y arranca sin las instrucciones del proyecto. Una corrida secuestrada no tiene nada local que leer ni escribir. Lo que podría filtrar (su prompt de tarea, la ruta de la carpeta, la rama y los nombres de commits recientes) solo puede salir por un fetch o una búsqueda, así que su prompt no lleva nada privado que la pregunta no necesite.
- **Nada de la tarea en las URL.** Al investigador se le dice que nunca ponga nada de la tarea, de su prompt ni de un archivo local en una URL o una búsqueda.
- **Los intentos de inyección se reportan aparte**, en una sección propia, nunca como un siguiente paso.
- **Los datos decisivos se re-verifican** en la página cruda.

El prefijo de investigación que lleva cada tarea web compra auditabilidad: datos etiquetados, fuentes y chequeos de refutación. En la prueba del mantenedor (24 corridas, intentos únicos que no se adaptaban) ningún modelo cayó, con o sin el prefijo, así que la prueba no pudo mostrar que añada resistencia. La guía de Anthropic pone la protección real en fronteras como las de arriba. Ver [`system/templates/research-template.md`](system/templates/research-template.md).

### Se mantiene al día

Los modelos y Claude Code cambian cada pocas semanas, así que el método lleva fechas y una forma de notar cuándo envejece.

- **En el kit maestro**, una corrida programada semanal lee las páginas oficiales y el changelog de Anthropic y los compara con lo que dice el kit. Abre un pull request con lo que cambió, filtrado por un script:
  - un cambio limitado a los docs del método, el changelog, las notas de actualización y los README puede mergearse sin una persona;
  - los cambios a roles, skills, plantillas o semillas esperan al mantenedor (`maintenance/freshness/`).
- **En cada proyecto**, el chequeo al abrir sesión avisa:
  - cuando los datos de modelos tienen más de 45 días;
  - cuando el kit maestro avanzó más allá de la versión de la que salió el proyecto;
  - cuando las skills instaladas difieren de las del kit.

---

## Referencia

### Qué cambia

**En tu máquina (`setup.ps1`).** Copia cada carpeta de `skills/` (cuatro hoy) a `~/.claude/skills/`, sobrescribiendo los archivos con el mismo nombre, y escribe `~/.claude/agent-ops-home.txt` con la ruta del clon. Nada más: ni hooks, ni settings, ni cambios al PATH, ni red, ni permisos de administrador.

Las skills a nivel usuario se cargan en **todas** las sesiones de Claude Code de esa máquina, no solo en los proyectos del kit. Claude puede arrancar `agent-dispatch`, `cerebrate` e `init-project` por su cuenta cuando una tarea calza. `init-project` y `cerebrate` muestran su plan y esperan tu respuesta antes de escribir, pero esa espera es una instrucción al modelo, no un prompt de permisos: en modo auto o bypass es el único freno.

**En cada proyecto (`/init-project`).** Solo escribe dentro de la carpeta que le indicas. Instala `.claude/settings.json` con siete handlers de hooks sobre cuatro scripts de `system/scripts/`, cada uno corrido como `powershell -NoProfile -ExecutionPolicy Bypass -File <script>`. Se disparan al abrir sesión, antes de un `git commit` y alrededor de cada subagente; ninguno usa la red ni borra nada.

Los logs van a `outputs/fanouts/`:
- `_dispatched-prompts.jsonl` guarda cada prompt de subagente tal cual y está en el gitignore;
- los logs de uso y de líneas de cierre guardan ids y conteos de tokens.

El hook de uso lee los transcripts de subagentes en `~/.claude/projects/`, solo lectura.

`.claude/settings.json` se commitea con el proyecto, así que cualquiera que lo clone y confíe en la carpeta corre los mismos hooks. Lee `system/scripts/` antes de activarlos, y revisa [SECURITY.md](SECURITY.md).

### Estado y límites

- Es el kit de trabajo de una persona, publicado tal cual.
- **Solo Windows y PowerShell.** En otro sistema operativo la capa que hace cumplir las reglas (gate de commit, líneas de cierre, captura de prompts, log de uso) no corre.
- Sigue a Claude Code y a los modelos a la fecha `last_verified` de [`system/model-playbook.md`](system/model-playbook.md), y envejece rápido.
- **Lo medido**, todo solo en modelos de Anthropic:
  - qué modelo y qué effort usa cada rol, en A/B chicos (k = 3 como mucho);
  - dos rondas del kit completo, en tres tareas y tres modelos: una corrida por celda más una corrida sin el kit en la primera ronda, dos corridas por celda en la segunda;
  - una ronda del ala de investigación contra páginas locales con inyecciones plantadas.

  Los resultados están en [`system/model-measurements.md`](system/model-measurements.md). Los fixtures y los evaluadores no están publicados, así que las cifras son un reporte, no algo auditable aquí.
- Nada se ha medido en el modelo Fable más nuevo; sus filas son guía del proveedor o inferencia.
- `--domain` es un punto de extensión. El repo no trae ningún kit de dominio.

### Los roles

Cada rol fija sus herramientas, su familia de modelo y su effort en su definición.

| Rol | Modelo, effort | Qué hace |
|---|---|---|
| `fidelity-verifier` | `haiku`, `high` | ¿El artefacto coincide con la verdad del proyecto (datos, código, configuración)? Solo lectura por instrucción: necesita `Bash` para correr chequeos |
| `domain-analyst` | `opus`, `medium` | ¿El cambio calcula lo que el dominio quiere decir, qué outputs mueve y qué decisión (con su dueño) autoriza cada uno? Solo lectura por construcción |
| `adversarial-reviewer` | `opus`, `medium` | Abogado del diablo sobre un artefacto escrito: hipótesis rivales, supuestos ocultos, sobreinterpretación. Solo lectura por construcción |
| `web-researcher` | `sonnet`, `high`, 30 turnos | Una pregunta acotada de la web, o una lista de datos externos a verificar; prefijo de investigación incluido, sin herramientas de archivos |
| `executor` (nivel `build`) | `opus`, `medium` | El único rol que escribe el producto de trabajo; persiste entre rondas de arreglo |
| `operator` (nivel `build`) | `haiku`, `high` | Checklists GO/NO-GO de pre-vuelo y post-vuelo; todo dato secundario tiene que salir de un comando que corrió |
| `extractor` | `haiku`, `high`, 40 turnos | Saca campos de archivos nombrados a una tabla con ubicación y una línea `COVERAGE:`; copia, nunca juzga |

Los tres primeros forman el mínimo de un gate de validación completo. Cada rol cierra con líneas fijas (`CHECKED:` / `NOT CHECKED:`). Si faltan, el rol se devuelve a trabajar, como mucho dos veces. Un rol en `haiku` que se niega, o sigue incompleto después de eso, se re-despacha en un modelo más fuerte, no se reanuda.

<details>
<summary><b>Los hooks</b></summary>

`init-project` los instala en cada proyecto; los scripts viven en `system/scripts/` ([README](system/scripts/README.md)):

- **Al abrir sesión**: `check-docs.ps1` le reporta al agente links rotos, fechas viejas, placeholders sin resolver y los avisos de frescura.
- **Gate de commit**: el mismo script bloquea un `git commit` si hay un error crítico, tanto por la herramienta Bash como por la de PowerShell.
- **Captura de prompts**: cada prompt de subagente despachado, con su modelo y effort, va a un log de auditoría.
- **Log de uso**: los tokens por request de cada subagente que termina, para comparar lo que de verdad cuesta un rol.
- **Líneas de cierre**: un rol del kit cuyo reporte no trae sus líneas de cierre se devuelve a trabajar, como mucho dos veces.
- **Límite de escritura** (un setting, no un hook): `permissions.blockWritesOutsideWorkingDirectories` hace que Claude Code (v2.1.314 o superior) rechace ediciones de archivos fuera de los directorios de trabajo del proyecto. No cubre comandos de shell. También quita `EnterWorktree` y `ExitWorktree`, así que una sesión no puede moverse sola a un git worktree: arráncala con `claude --worktree`, o revisa el [README de los scripts](system/scripts/README.md) para las otras salidas.

</details>

### Las skills

- **`init-project`**: crea un proyecto desde el kit; escribe `/init-project` o pídelo con palabras.
- **`agent-dispatch`**: el procedimiento que Claude carga antes de organizar o delegar trabajo (si delegar, qué vehículo, modelo, effort, cómo redactar el prompt). Termina en la ficha de configuración.
- **`cerebrate`**: la reflexión al cierre de un bloque. Destila lo que aprendió una sesión hacia los docs vivos, y muestra su plan y espera tu aprobación antes de escribir.
- **`cerbero`**: la revisión de seguridad que se corre antes de instalar cualquier servidor MCP o skill de terceros. `skills/cerbero/` se sincroniza desde [Cerbero](https://github.com/jppuche/Cerbero) (MIT, mismo autor); sus hooks se instalan aparte (`skills/cerbero/setup-guide.md`).

### Actualizar y desinstalar

**Actualizar el kit**: `git -C "$HOME\agent-ops" pull`, y vuelve a correr `setup.ps1` si el pull tocó `skills/`. Las skills actualizadas se recargan sin reiniciar. Los proyectos nuevos salen con la versión nueva.

**Actualizar un proyecto existente**: no se actualiza solo; es una copia del kit al momento de su `/init-project`. Su `docs/status.md` registra de qué versión salió; un proyecto creado antes de que existiera esa línea compara su fecha de creación con [CHANGELOG.md](CHANGELOG.md). Aplica [UPGRADING.md](UPGRADING.md) desde esa versión en adelante y abre una sesión nueva de Claude Code para que carguen los roles que cambiaron. O pídeselo a Claude.

**Mejorar el kit**: cuando un proyecto muestre un patrón nuevo o un hueco del método, anótalo ahí (`docs/lessons-learned.md`, o el `/cerebrate` de cierre). Cuando se confirme dos o tres veces, abre un issue ([CONTRIBUTING.md](CONTRIBUTING.md)).

**Desinstalar**: borra las cuatro carpetas de skills en `~/.claude/skills/` y el archivo `~/.claude/agent-ops-home.txt`. Un proyecto creado con el kit sigue funcionando como archivos sueltos. Para apagar sus hooks, quita el bloque `hooks` de su `.claude/settings.json`; quita el bloque `permissions` para levantar el límite de escritura. Los hooks de Cerbero, si los instalaste, se quitan igual que como los puso `skills/cerbero/setup-guide.md`.

<details>
<summary><b>Qué hay adentro</b></summary>

| Ruta | Qué es |
|---|---|
| `CLAUDE.md.template` | El `CLAUDE.md` que instancia cada proyecto (reglas, routing, convenciones; menos de 200 líneas) |
| `system/` | El método: orquestación, staffing de modelo y effort, el contrato de revisión, la plantilla de investigación, los scripts de hooks |
| `agents/` | Siete definiciones de subagentes, cada una con sus herramientas, familia de modelo y effort fijados |
| `skills/` | `init-project`, `agent-dispatch`, `cerebrate`, `cerbero` |
| `docs-seed/` | Las semillas de los docs vivos de cada proyecto (status, scratchpad, decisions, lessons, changelog) |
| `setup.ps1` | Instala las skills a nivel usuario y graba dónde vive el kit |
| `maintenance/freshness/` | La corrida semanal de frescura del kit maestro. Herramienta del mantenedor, nunca se copia a un proyecto |
| `CLAUDE.md` | La guía para mantener el kit en sí. No corras un proyecto desde el clon: Claude seguiría estas instrucciones en vez de las del proyecto |

</details>

<details>
<summary><b>Si algo se rompe</b></summary>

- **`setup.ps1` no se puede cargar / la ejecución de scripts está deshabilitada**: usa la forma `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1`.
- **`/init-project` no aparece**: corre `setup.ps1` desde el kit y, si es la primera instalación, reinicia Claude Code (cierra todas las ventanas).
- **"Agent type not found" justo después de `/init-project`**: abre una sesión nueva de Claude Code en el proyecto. Los roles copiados a mitad de sesión no se pudieron despachar en esa sesión (observado una vez, 2026-11-13; Claude Code v2.1.326 lista un fix, todavía sin re-probar).
- **Un commit se bloquea por un "broken ref"**: el gate encontró un link roto en un doc. Arregla el link.
- **`check-docs.ps1` se queja dentro del propio kit**: es esperado. El kit tiene semillas (`docs-seed/`), no docs vivos; el checker está hecho para un proyecto instanciado.
- **Los hooks corren scripts de otro proyecto**: la sesión se movió entre carpetas y conservó la ruta del proyecto original. Abre una sesión nueva en el proyecto.
- **Falta `EnterWorktree`**: el límite de escritura lo quita; ver los hooks arriba.

</details>

### Términos

<details>
<summary>Ver los términos</summary>

- **Instancia**: un proyecto creado desde el kit; una copia, no un enlace.
- **Docs vivos**: `docs/status.md`, `decisions.md`, `lessons-learned.md` y compañía, que el agente mantiene al día.
- **Orquestador**: la sesión principal de Claude Code, la que integra y decide.
- **Fan-out**: varios subagentes despachados en paralelo sobre partes de una misma pregunta.
- **Gate**: un chequeo que un cambio tiene que pasar antes de salir.
- **Effort**: el ajuste de profundidad de razonamiento de Claude Code (`low` a `max`); el kit lo fija por rol.
- **Ficha de configuración**: la respuesta escrita a "cómo se organiza este trabajo", en `docs/status.md`.
- **Hand-back**: el reporte final de un subagente. **Líneas de cierre**: las líneas `CHECKED:` / `NOT CHECKED:` con las que tiene que terminar.
- **Fable**: el nivel de modelo más alto de Anthropic, por encima de Opus. **Advisor**: `/advisor`, consultar a un modelo más fuerte en momentos de decisión.
- **Nivel (tier)**: qué roles recibe un proyecto (`core` 5, `build` 7).
- **Kit de dominio** (`--domain`): una capa opcional de carpetas y docs extra para un tipo de trabajo; aquí no viene ninguno.

</details>

## Licencia

MIT, ver [LICENSE](LICENSE). `skills/cerbero/` viene de [Cerbero](https://github.com/jppuche/Cerbero), también MIT, del mismo autor. Reportes de seguridad: [SECURITY.md](SECURITY.md).

## Contribuir

Los issues son bienvenidos, y los pull requests pequeños también; no hay garantía de respuesta. Ver [CONTRIBUTING.md](CONTRIBUTING.md).
