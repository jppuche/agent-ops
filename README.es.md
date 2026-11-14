# agent-ops: guía de uso

![version](https://img.shields.io/badge/version-v0.10.1-blue) ![platform](https://img.shields.io/badge/platform-Windows-0078D6) ![license](https://img.shields.io/badge/license-MIT-green) ![built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-D97757)

[Read in English](README.md) | [Actualizar una instancia (UPGRADING.md, en inglés)](UPGRADING.md) | [Changelog](CHANGELOG.md)

Un kit para trabajar con Claude Code: un método de agentes, governance de docs, roles de orquestación reutilizables y skills transversales, versionado como producto e instanciado en cada proyecto nuevo.

> **Idiomas:** esta guía existe en español y en inglés. El resto de los documentos del kit están en inglés a propósito: los consume Claude (el agente), y el inglés le cuesta menos tokens y le resulta más directo. No necesitas leer esos archivos para usar el kit; Claude los lee por ti.

---

## En una frase

El kit es una **copia maestra read-mostly**. No trabajas adentro de él: cuando empiezas un proyecto, lo **instancias** desde el kit con una skill (`/init-project`), que te copia el método, siembra los docs vivos, instala los hooks y arma el `CLAUDE.md`. Después mejoras el kit con el uso y lo actualizas con `git pull`.

La analogía: el kit es el molde; cada proyecto es una pieza fundida desde el molde. Mejoras el molde una vez y todas las piezas nuevas salen mejores.

---

## Estado y límites

- Es el kit de trabajo de una persona, publicado tal cual.
- **Solo Windows + PowerShell.** Los hooks llaman a `powershell`; en otro sistema operativo no corren, así que la capa que hace cumplir las reglas (gate de commit, líneas de cierre, captura de prompts, log de uso) no existe y queda solo el método escrito.
- Sigue a Claude Code y a los modelos de una fecha dada (2026-11-10, el `last_verified` de `system/model-playbook.md`) y envejece rápido. Si el kit tiene más de unas semanas, revisa `system/model-playbook.md` sec 1 contra las páginas actuales del proveedor.
- Lo medido es qué modelo y qué effort usa cada rol, en A/B chicos (k = 3 como mucho). El método completo (kit contra sin kit) no se ha medido. Nada se ha medido en el modelo Fable más nuevo. Los fixtures y los evaluadores de esas pruebas no están publicados: las cifras son un reporte, no algo auditable desde este repo.
- `--domain` es un punto de extensión: el kit no trae ningún kit de dominio.

---

## 1. Requisitos e instalación (una vez por máquina)

Requisitos:
- Windows con PowerShell 5.1 o superior.
- Git for Windows (la skill `init-project` usa `cp` y `mkdir -p`, así que Claude Code necesita Git Bash).
- Python 3.10 o superior (hooks y tests de Cerbero).
- Claude Code v2.1.321 o superior. Los hooks y los roles funcionan en versiones anteriores, pero ahí algunos settings se ignoran sin aviso: el límite de escritura pide la v2.1.314, el effort por llamada la v2.1.292 y el alias `fable` la v2.1.321.
- Un plan de claude.ai o acceso por API. El kit corre en cualquier plan pago; el advisor y una sesión principal en Fable dependen de lo que incluya tu plan, y el bloque *Environment* del `CLAUDE.md` de cada proyecto es donde dices qué se puede gastar.

Clona el repo en una carpeta estable, separada de tus proyectos, y corre el setup desde ahí:

```powershell
git clone https://github.com/jppuche/agent-ops.git <path-to>/agent-ops
cd <path-to>/agent-ops
.\setup.ps1
```

Si PowerShell no deja correr el script: `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1`.

Eso hace dos cosas:
1. Instala las 4 skills (`init-project`, `cerebrate`, `cerbero`, `agent-dispatch`) en `~/.claude/skills/` (nivel usuario, disponibles en cualquier proyecto). **Sobrescribe sin preguntar los archivos de cualquier skill que ya tengas con esos cuatro nombres.**
2. Graba la ruta del kit en `~/.claude/agent-ops-home.txt`, para que `init-project` encuentre el kit sin importar dónde lo tengas.

**La primera vez, reinicia Claude Code** (para que tome el directorio de skills nuevo). Después de un `git pull` que toque una skill, vuelve a correr `setup.ps1`: eso se recarga en caliente, sin reiniciar.

**Desinstalar:** borra las cuatro carpetas de skills en `~/.claude/skills/` y el archivo `~/.claude/agent-ops-home.txt`. Un proyecto creado con el kit sigue funcionando como archivos sueltos; para apagar sus hooks, quita el bloque `hooks` de su `.claude/settings.json`.

---

## 2. Empezar un proyecto nuevo

1. **Crea una carpeta** para el proyecto, separada del kit.
2. **Abre Claude Code en esa carpeta** y escribe **`/init-project`**, o pide con palabras un proyecto nuevo de agent-ops. En ambos casos te muestra los datos que recogió y no escribe nada hasta que los confirmes.
3. La skill te pide lo básico (nombre, una línea de qué hace, quién lo consume, el path) y el **tipo de proyecto**: `build` (código, pipeline de datos, automatización, API), `research` (responder una pregunta desde fuentes) o `advisory` (comparar opciones y recomendar un curso). El tipo define los defaults de trabajo y el **nivel** de roles: `core` instala 5 roles; `build` suma `executor` y `operator`. Todo lo demás (método, docs vivos, hooks) es igual en ambos niveles. Con eso:
   - Arma la estructura (`system/ docs/ .claude/agents/`).
   - Instancia el `CLAUDE.md` desde la plantilla (sustituye los placeholders).
   - Copia el método (`system/`) y los roles de su nivel (`.claude/agents/`).
   - Siembra los docs vivos (`docs/status.md`, `scratchpad.md`, etc.).
   - Instala los hooks.
   - Hace `git init` (opcional).

   Después abre una sesión nueva de Claude Code en la carpeta del proyecto: los roles que copió no se pueden despachar en la misma sesión que los copió (observado en una máquina, 2026-11-13).

### Con capa de dominio

Si el proyecto tiene un dominio propio (un tipo de trabajo con sus carpetas y su conocimiento), pasas `--domain`. La skill monta las carpetas y el routing del dominio **encima** del core agnóstico. El kit no trae ningún dominio: tú defines el tuyo.

Ejemplo: un dominio de operaciones de negocio podría sumar carpetas como `canonical/ sales/ analytics/ legal/ marketing/ ...` sobre el core.

---

## 3. Qué hay adentro (anatomía)

Solo necesitas saber esto si quieres tocar el kit; para usarlo, `init-project` se encarga.

| Ubicación | Qué es |
|---|---|
| `CLAUDE.md` | Guía para **mantener el kit** (no la sigues como proyecto). |
| `CLAUDE.md.template` | El `CLAUDE.md` que cada proyecto instancia. Agnóstico, < 200 líneas. |
| `system/agent-orchestration.md` | El cerebro del método: cuándo y cómo delegar a agentes (el 2x2). |
| `system/model-playbook.md` | Qué modelo y qué effort usar para cada trabajo (las decisiones). |
| `system/model-measurements.md` | La evidencia detrás del playbook: los A/B, la prueba de procedencia y el checklist para medir. |
| `system/verification-contract.md` | El contrato para agentes que revisan algo (locator + provenance + `falsified_by`). |
| `system/cross-validation-prompt.md` | Plantilla para que un sub-agente valide un cambio de riesgo medio+. |
| `system/claude-md-guide.md` | Cómo mantener un `CLAUDE.md` (best practices con fuentes). |
| `system/templates/research-template.md` | Schema + prefijo para research multi-agente. |
| `system/templates/parallel-sessions-protocol.md` | Protocolo para varias sesiones que se coordinan entre sí (roster, quién decide qué, buzón por archivos, handoff). Se instancia solo cuando se usa. |
| `system/scripts/` | Los hooks: salud de docs (`check-docs`), rastro de prompts (`capture-agent-prompt`), tokens por sub-agente (`log-subagent-usage`), líneas de cierre de los roles (`check-closing-lines`). |
| `agents/` | Los **7 roles reutilizables** (subagentes con modelo y effort fijados). |
| `skills/` | `init-project`, `cerebrate`, `cerbero`, `agent-dispatch`. |
| `docs-seed/` | Las semillas de los docs vivos con las que empieza un proyecto nuevo. |
| `setup.ps1` | Instala skills + graba la ruta del kit. |

---

## 4. El método (lo que Claude usa al trabajar)

No tienes que memorizarlo: Claude lo aplica leyendo `system/`. Pero entenderlo te deja pedir mejor.

### El 2x2 de delegación (`agent-orchestration.md`)

Antes de lanzar agentes, Claude clasifica la tarea en dos ejes:
- **Costo de error**: ¿es reversible o irreversible? ¿interno o de cara a alguien?
- **Necesidad de síntesis**: ¿alcanza una fuente, o hay que triangular fuentes que pueden contradecirse?

Eso da 4 modos de **rigor**: DIRECT (sin agentes), AGENTS LIGHT (1-2 en paralelo), VERIFIED (con spot-check), FULL SYSTEM (fan-out + ronda de escepticismo). El rigor es una cosa; el **vehículo** (subagentes, team, workflow) y el **modelo** son decisiones separadas.

La regla de oro: **el orquestador (la sesión principal) siempre integra y decide**. Los agentes solo producen hallazgos; nunca editan el artefacto que revisan.

**Se divide por contexto, no por rol** (guía de Anthropic, 2026-10-22). Un subagente o una sesión paralela recibe un pedazo que necesita poco del resto y devuelve algo compacto: una línea de investigación independiente, un componente con interfaz limpia, una revisión con contexto fresco. Repartir por rol (diseñador / implementador / tester sobre la misma funcionalidad) convierte cada traspaso en un resumen que pierde detalle.

**Sesiones paralelas**: una sesión principal conversa contigo y hace casi todo; abre otra sesión solo para un frente con sus propios archivos, para un revisor con contexto fresco o para una corrida larga. **Quién le escribe a quién** (propuesto, todavía sin evidencia de campo): un hallazgo técnico va directo a la sesión que lo necesita; los hitos, los bloqueos y lo que se sale del mandato van a la sesión líder; y solo la líder te habla a ti. Detalle en `agent-orchestration.md` sec 6 y en `system/templates/parallel-sessions-protocol.md`.

### La configuración de trabajo (cuándo Claude te propone otra forma de trabajar)

Un modelo dejado a su suerte tiende a resolver todo solo en una sesión. Por eso el kit fija **cuándo** se evalúa cómo organizar el trabajo, en vez de dejarlo a cada turno:

- **Al arrancar** un proyecto o un frente nuevo, Claude propone una configuración en dos o tres líneas (modelo de la sesión principal, una sesión o agentes, qué gate pasa un cambio riesgoso, advisor sí o no), con el porqué y lo que cuesta frente a la alternativa. Queda anotada en `docs/status.md`. "Una sola sesión, sin agentes" es una respuesta válida.
- **Se reevalúa solo ante seis eventos**: un plan más grande que una sesión o con un paso caro de deshacer, un supuesto que se cayó, una acción irreversible o hacia afuera, dos intentos fallidos sobre lo mismo, un contexto compactado o casi lleno, y el cierre de un bloque.
- **Si la configuración sigue sirviendo, Claude no dice nada.** Solo habla cuando la recomendación cambia, o antes de una acción irreversible cuyo gate no corrió.

Lo que compra el multiagente, según las evaluaciones de Anthropic: **tiempo de reloj y contexto limpio, no más acierto por token**. Si nadie está esperando y el contexto no corre riesgo, una sesión es más barata.

### El orquestador y el advisor

- **Tú eliges el modelo de la sesión principal por proyecto**: Opus para alcance definido, Fable para alcance abierto (arranque, arquitectura, causa raíz ambigua, orquestación multiagente, corridas largas). El kit no asume ninguno.
- **El advisor** (`/advisor fable` con Opus de principal) consulta a un modelo más fuerte en momentos clave. No reemplaza un gate: lee la misma conversación, con el mismo encuadre.
- **El bloque Environment del `CLAUDE.md`** de cada proyecto dice qué se puede gastar y usar. El default es conservador.

### Los 7 roles (`agents/`)

Cada uno fija sus herramientas, su familia de modelo y su effort. Los tres primeros forman el **mínimo de un gate de validación completo**. `executor` y `operator` solo se instalan en el nivel `build`.

- **fidelity-verifier** (`haiku`, effort `high`): ¿lo que dice el artefacto coincide con la verdad del proyecto? Solo lectura **por instrucción**: necesita `Bash` para correr chequeos, así que el harness no se lo impide.
- **domain-analyst** (`opus`): ¿calcula lo que el dominio quiere decir, qué outputs mueve el cambio y qué decisión (con su dueño) autoriza cada movimiento? Solo lectura por construcción.
- **adversarial-reviewer** (`opus`): abogado del diablo. Hipótesis rivales, supuestos ocultos, sobreinterpretación. Solo lectura por construcción.
- **web-researcher** (`sonnet`, effort `high`, máximo 30 turnos): una pregunta acotada de la web, o verificar claims externos. **No tiene herramientas de archivos.**
- **executor** (`opus`): el único que toca el sustrato. Persiste entre rondas.
- **operator** (`haiku`, effort `high`): checklist de pre-vuelo y post-vuelo. Todo dato secundario tiene que salir de un comando que corrió.
- **extractor** (`haiku`, effort `high`, máximo 40 turnos): saca campos de archivos nombrados en tabla, con `file:line` por fila y una línea `COVERAGE:`. Copia, no juzga.

Todos cierran con líneas fijas (`CHECKED:` / `NOT CHECKED:`). Si faltan, el hook devuelve el rol a trabajar (máximo dos veces); un rol en `haiku` que se niega, o sigue incompleto después de eso, se re-despacha desde cero en un modelo más fuerte en vez de reanudarse.

### Modelo y effort (`model-playbook.md` + skill `agent-dispatch`)

- **El effort es el dial principal**, no el modelo. Un subagente sin `effort:` hereda el de la sesión: uno lanzado desde una sesión en `max` quemó ~443k tokens en 25 minutos.
- **Las versiones de modelo viven en dos archivos**: `system/model-playbook.md` (las decisiones) y `system/model-measurements.md` (la evidencia). El resto del kit habla de familias (`opus`, `sonnet`, `haiku`), así que un lanzamiento nuevo se resuelve editando esos dos.
- **Lo medido** (A/B chicos, k = 3 como mucho, en `model-measurements.md`): `extractor`, `operator` y `fidelity-verifier` corren en `haiku` a `high`; `web-researcher` se queda en `sonnet` porque `haiku` fabricó procedencia en la prueba pre-registrada. Los roles de juicio, el executor y cualquier análisis de seguridad no van a `haiku`.
- **La skill `agent-dispatch`** es el procedimiento de 60 segundos antes de delegar.

### La verificación (lo que evita que Claude te mienta con confianza)

- **Convergencia no es evidencia**: que varios agentes coincidan no lo hace cierto. Solo el contraste con la realidad (grep, fetch, query) lo hace cierto.
- **La prueba de una verificación es la independencia**: ¿este paso puede fallar independientemente del primero? Si usa otra fuente u otro razonador, se queda.
- **Nunca le topes la severidad a un revisor** ("solo lo crítico"): reporta menos. Se acota el dominio, no el umbral.
- **Datos exactos (hashes, ids, nombres de settings) nunca a través de un modelo**: en un caso de campo, 10 de 10 hashes leídos con WebFetch eran falsos; `curl` lo atrapó.
- Todo claim con impacto lleva un `falsified_by:` (qué lo refutaría).
- El orquestador re-verifica **directamente** los 3-5 claims que más pesan.

---

## 5. Los hooks (la red de seguridad automática)

`init-project` instala estos hooks en cada proyecto (`.claude/settings.json`). Se disparan solos:

1. **Al abrir sesión (SessionStart)**: `check-docs.ps1` le reporta a Claude el estado de los docs (links rotos, fechas viejas, placeholders sin resolver).
2. **Antes de un `git commit`**: el mismo script en modo gate **bloquea el commit** si hay un error crítico. Hay un handler por herramienta de shell (Bash y PowerShell), porque una regla `if` nombra una sola herramienta.
3. **Antes de lanzar un sub-agente**: guarda el prompt despachado (más el modelo y el effort pedidos).
4. **Al terminar un sub-agente (SubagentStop)**: `log-subagent-usage.ps1` anota los tokens de cada request en `outputs/fanouts/_subagent-usage.jsonl`. Nunca bloquea.
5. **Al entregar un rol del kit**: `check-closing-lines.ps1` lo devuelve a trabajar (máximo dos veces) si su reporte no trae las líneas de cierre, o, en el `extractor`, si su línea `COVERAGE:` no trae números reales.

Además, el setting `blockWritesOutsideWorkingDirectories` le pide a Claude Code (v2.1.314 o superior) rechazar ediciones de archivos fuera del proyecto. No cubre comandos de shell, y el kit no lo ha vuelto a verificar en una versión actual (`system/scripts/README.md`).

Son texto plano en `.claude/settings.json` + scripts en `system/scripts/`. Los puedes leer, modificar o apagar.

**Ojo al mover una sesión de proyecto a mitad de camino** (`change_directory`): la sesión conserva el `CLAUDE_PROJECT_DIR` con el que arrancó, así que los hooks corren los scripts del proyecto anterior. Lo sano es abrir una sesión nueva. Detalle en `system/scripts/README.md`.

---

## 6. Las 4 skills

- **`init-project`**: crea un proyecto nuevo desde el kit. Escribe `/init-project` o pídelo con palabras; confirma los datos contigo antes de escribir.
- **`cerebrate`**: reflexión al cierre de un bloque o sesión: destila aprendizajes y actualiza los docs vivos. Puedes escribir `/cerebrate`, o Claude la arranca al cerrar un bloque; en ambos casos muestra su plan y espera tu aprobación antes de escribir.
- **`agent-dispatch`**: Claude la carga antes de delegar (subagente, fan-out, gate).
- **`cerbero`**: evaluación de seguridad de cualquier MCP o skill de terceros **antes** de instalarlo. Sus hooks se instalan aparte (ver `skills/cerbero/setup-guide.md`). `skills/cerbero/` se sincroniza desde [Cerbero](https://github.com/jppuche/Cerbero) (MIT, mismo autor): no se edita aquí, y `python skills/cerbero/tests/run_tests.py` falla si algo difiere del registro en `skills/cerbero/hooks/UPSTREAM.json`.

---

## 7. Actualizar y mejorar el kit

- **Actualizar:** `git pull` en el clon del kit. Los proyectos nuevos toman la versión nueva; los viejos quedan como snapshot. Para traer uno viejo al día, sigue [UPGRADING.md](UPGRADING.md).
- **Mejorar:** cuando descubras un patrón nuevo o un hueco del método en un proyecto, lo capturas ahí (`docs/lessons-learned.md`, o el `cerebrate` de cierre). Cuando se valida 2-3 veces, abre un issue (ver `CONTRIBUTING.md`).
- **Versionar:** el kit se versiona como producto (`CHANGELOG.md`). Versión actual: **v0.10.1**.

---

## 8. Si algo se rompe

- **`/init-project` no aparece en Claude Code:** corre `setup.ps1` desde el kit y, si es la primera instalación, reinicia Claude Code (cierra todas las ventanas).
- **El commit se bloquea por un "broken ref":** el hook encontró un link roto en un doc. Arréglalo.
- **check-docs se queja en el propio kit:** es esperado. El kit no tiene docs vivos (`docs/status.md` etc.), tiene semillas (`docs-seed/`). El checker está hecho para una instancia.

---

## Licencia y contribuciones

MIT (ver [LICENSE](LICENSE)); `skills/cerbero/` viene de Cerbero, también MIT, del mismo autor. Problemas de seguridad: [SECURITY.md](SECURITY.md). Los issues son bienvenidos, y los PR pequeños también; no hay garantía de respuesta.
