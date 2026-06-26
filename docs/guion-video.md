# Guion del Video — EP3 "Tienda de Perritos"
## Explicación del proceso de construcción e implementación del proyecto

> **Formato sugerido:** screencast (graba pantalla + voz) con **OBS Studio**, **PowerPoint →
> Grabar**, **Zoom** (compartir pantalla y grabar) o **Loom**. Duración objetivo: **10–12 min**.
> Se puede narrar mostrando las **capturas** (carpeta `docs/evidencias/`), el **repositorio** en
> GitHub y la pestaña **Actions**. No se requiere AWS en vivo.
>
> **Defensa individual:** aunque el encargo es en pareja, cada quien debe dominar TODO. Si graban
> juntos, repártanse los segmentos, pero ambos deben poder explicar cualquier parte.

**Leyenda:** 🖥️ = qué mostrar en pantalla · 🎙️ = qué decir (libreto).

---

### Segmento 0 — Portada e introducción · ~40 s
🖥️ Diapositiva de título / repositorio en GitHub (captura `img20`).
🎙️ "Hola, somos [nombre] y [nombre]. En este video explicamos cómo construimos e implementamos la
Evaluación Parcial 3 del ramo Introducción a Herramientas DevOps: una aplicación de 3 capas
llamada *Tienda de Perritos*, orquestada en **AWS ECS Fargate** y con un pipeline de
**CI/CD automatizado en GitHub Actions**. El caso es la empresa Innovatech Chile, que después de
contenedorizar su app, avanza hacia la orquestación productiva en la nube."

---

### Segmento 1 — La aplicación y su contenedorización · ~1 min
🖥️ La app en el navegador (`ie2-app-navegador.png`) → luego el repo (carpetas `frontend/`,
`backend/`, `db/`) → ECR (`ie2-ecr-repos.png`).
🎙️ "La aplicación es un CRUD de productos con tres capas: un **frontend** en nginx que sirve el
HTML y JavaScript, un **backend** en Node.js con Express que expone una API REST, y una base de
datos **MySQL**. Cada capa tiene su propio **Dockerfile**, así que la empaquetamos como tres
imágenes de contenedor. Esas imágenes las subimos a **Amazon ECR**, que es el registro privado de
imágenes de AWS: aquí están los tres repositorios, `tienda-frontend`, `tienda-backend` y
`tienda-db`. ECR es la fuente desde donde el clúster va a descargar las imágenes."

---

### Segmento 2 — El clúster ECS Fargate y por qué lo elegimos · ~1 min 15 s
🖥️ Clúster con los servicios (`ie1-cluster-servicios.png`) → tareas en ejecución (`img02`).
🎙️ "Para orquestar los contenedores creamos un **clúster de ECS** llamado `tienda-cluster`, en
modo **Fargate**. Elegimos Fargate y no EKS por dos razones: primero, es **serverless**, o sea no
tenemos que administrar servidores EC2; y segundo, en el laboratorio de AWS Academy **no se pueden
crear roles de IAM nuevos** ni usar herramientas como `eksctl`, así que Fargate, que reutiliza el
rol preexistente `LabRole`, era la opción viable. Aquí vemos el clúster con sus **tres servicios
activos** —frontend, backend y base de datos— y las **tareas corriendo** en Fargate. Cada servicio
mantiene viva una cantidad de tareas y las reemplaza solas si se caen."

---

### Segmento 3 — Redes, balanceadores y seguridad · ~1 min 30 s
🖥️ Balanceadores (`img08`) → regla del listener (`ie2-alb-routing.png`) → SG ecs
(`ie1-sg-ecs.png`) → SG alb (`ie1-sg-alb.png`).
🎙️ "La comunicación fue el punto más interesante. Como el laboratorio **deniega el descubrimiento
de servicios** (Cloud Map), resolvimos todo con **balanceadores de carga**. Tenemos un **ALB**, que
es un balanceador de capa 7 (HTTP), público: el navegador entra por él, y mediante una **regla de
ruta** lo que va a `/api/*` se enruta al backend y el resto al frontend. Así el frontend nunca
necesita saber la IP del backend. Para la base de datos usamos un **NLB interno**, de capa 4 (TCP),
porque MySQL no es HTTP: el backend le habla por el puerto 3306 a través de un DNS estable. En
cuanto a seguridad, tenemos dos **Security Groups**: el del ALB solo abre el puerto 80 a Internet,
y el de las tareas solo acepta tráfico desde el ALB y el 3306 dentro de la VPC, así la base de
datos **nunca queda expuesta** a Internet."

---

### Segmento 4 — Task Definitions y variables/secrets · ~1 min 15 s
🖥️ Task definition del backend (`img03`) → SSM Parameter Store (`ie5-ssm.png`).
🎙️ "Cada contenedor se describe en una **Task Definition**: qué imagen usar de ECR, cuánta CPU y
memoria, los puertos, las variables de entorno y los secrets. Por ejemplo, el backend recibe el
host de la base de datos, el usuario y el nombre de la base como variables, y la **contraseña la
recibe como secret**. La contraseña no está escrita en ningún lado del código: vive cifrada en
**AWS Systems Manager Parameter Store**, como un *SecureString*, y se inyecta al contenedor solo
en tiempo de ejecución. Esto es clave para la seguridad: nada de credenciales en el repositorio."

---

### Segmento 5 — El pipeline CI/CD en GitHub Actions (el corazón) · ~2 min
🖥️ El archivo `.github/workflows/deploy-ecs.yml` en el repo → la pestaña **Actions** con el run en
verde (`ie4-pipeline-verde.png`) → GitHub Secrets (`ie5-github-secrets.png`).
🎙️ "Esta es la parte central del proyecto: el **pipeline de CI/CD**. Está en GitHub Actions, en el
archivo `deploy-ecs.yml`, y se ejecuta automáticamente **cada vez que hacemos push a la rama main**.
El flujo es **build → push → deploy**: primero hace el **build** de las imágenes de frontend y
backend; luego las **sube a ECR** etiquetadas con el hash del commit, para tener trazabilidad;
después **renderiza la task definition** con la imagen nueva; y finalmente hace el **deploy en
ECS**, esperando a que el servicio quede estable con `wait-for-service-stability`. Eso significa
que el pipeline **no se da por exitoso hasta que ECS confirma** que las tareas nuevas están sanas.
Las credenciales de AWS las guardamos como **secrets del repositorio** en GitHub, nunca en el
código. Aquí vemos una ejecución completa **en verde**: build, push y deploy de los dos servicios,
todo automático tras un commit."

🎙️ *(Opcional, si pueden hacer demo):* "Si hago un cambio y un commit, el pipeline arranca solo y
en unos 10–15 minutos la nueva versión queda desplegada en el clúster, sin tocar nada a mano."

---

### Segmento 6 — Autoscaling · ~1 min
🖥️ Política de autoscaling (`ie3-autoscaling.png`) → métrica de CPU en CloudWatch
(`ie3-cpu-metric.png`).
🎙️ "Para que la aplicación **escale sola**, configuramos **Application Auto Scaling** con una
política de *Target Tracking* sobre la **CPU**, con objetivo del **50%**. Esto quiere decir que si
la CPU promedio del servicio pasa de 50%, ECS **agrega tareas** automáticamente, hasta un máximo de
4; y cuando baja la carga, las **quita**, hasta un mínimo de 2. Elegimos 50% para dejar margen y
absorber picos antes de saturar. En CloudWatch vemos la métrica de CPU que dispara este
comportamiento, y en la consola quedan registradas las **actividades de escalado**."

---

### Segmento 7 — Logs y validación funcional · ~1 min 15 s
🖥️ CloudWatch Logs (`ie6-cloudwatch-logs.png`) → app funcionando (`ie2-app-navegador.png`) →
eventos del servicio (`ie7-eventos-steady.png`).
🎙️ "Para observabilidad, los tres contenedores envían sus **logs a CloudWatch**. Aquí vemos los
logs del backend: inicializa el pool de conexiones a MySQL y queda escuchando en el puerto 3001,
lo que confirma que se conectó bien a la base de datos. Y la prueba final es la app misma: al abrir
la URL del ALB, el frontend carga, y al pedir los productos, el frontend llama al backend, el
backend consulta MySQL y devuelve los datos. Toda la cadena **Front → Back → Base de datos**
funciona. En los eventos del servicio se ve cómo los despliegues alcanzan el *steady state* y se
registran los destinos en el balanceador. Si una tarea se cae, ECS **levanta otra automáticamente**
para mantener la disponibilidad."

---

### Segmento 8 — Problemas que enfrentamos y cómo los resolvimos · ~1 min 15 s
🖥️ Diapositiva de bullets (o la tabla §10 del informe).
🎙️ "Durante la implementación tuvimos varios problemas reales y aprendimos de ellos:
- El laboratorio **no permite descubrimiento de servicios**, así que rediseñamos la comunicación
  con balanceadores: ALB para front-back y NLB para la base de datos.
- No podíamos crear roles de IAM, por eso usamos Fargate con el rol `LabRole`.
- En el pipeline, una primera ejecución **falló porque todavía no habíamos cargado los secrets** de
  AWS; el log decía *'Could not load credentials'*. Lo solucionamos cargándolos.
- Otra ejecución hizo **rollback automático por el circuit breaker** de ECS cuando las tareas
  nuevas no estabilizaron; al relanzar, quedó estable.
- Y como el laboratorio se reinicia, las **credenciales caducan** y hay que refrescarlas. De hecho,
  a uno de nosotros se le agotaron los créditos y continuamos en otra cuenta de Learner Lab.
Todos estos problemas los diagnosticamos **leyendo los logs**, no adivinando."

---

### Segmento 9 — Conclusión y proyección · ~45 s
🖥️ Diapositiva de cierre / diagrama de arquitectura.
🎙️ "En resumen, logramos una aplicación **orquestada, escalable, tolerante a fallos y con
despliegue automático**. Si esto fuera a producción real para Innovatech Chile, separaríamos los
roles de IAM con privilegio mínimo, moveríamos la base de datos a **Amazon RDS**, pondríamos
**HTTPS** con un dominio propio, y usaríamos autenticación por **OIDC** entre GitHub y AWS en vez
de claves que caducan. Eso es todo, ¡gracias!"

---

## Checklist antes de grabar
- [ ] Tener abiertas las pestañas/capturas en orden (carpeta `docs/evidencias/`).
- [ ] Probar el micrófono y grabar 10 s de prueba.
- [ ] Hablar pausado; no leer de corrido (usa este guion como apoyo, no palabra por palabra).
- [ ] Si es individual, cada uno graba su propia versión cubriendo TODOS los segmentos.
- [ ] Exportar en 1080p y revisar que se lea el texto de las capturas.
- [ ] Subir a AVA dentro del plazo (o el formato que indique el profesor).

## Mapa rápido capturas → segmento
| Captura | Segmento |
|---|---|
| `ie2-app-navegador.png` | 1, 7 |
| `ie2-ecr-repos.png` | 1 |
| `ie1-cluster-servicios.png` | 2 |
| `ie1-sg-ecs.png` / `ie1-sg-alb.png` | 3 |
| `ie2-alb-routing.png` | 3 |
| `ie2-target-group.png` | 7 |
| `img03` (task def) | 4 |
| `ie5-ssm.png` | 4 |
| `ie4-pipeline-verde.png` | 5 |
| `ie5-github-secrets.png` | 5 |
| `ie3-autoscaling.png` / `ie3-cpu-metric.png` | 6 |
| `ie6-cloudwatch-logs.png` | 7 |
| `ie7-eventos-steady.png` | 7 |
