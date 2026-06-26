# Guion del Video — EP3 "Tienda de Perritos"
## Explicación del proceso de construcción e implementación del proyecto

**Integrantes:** Gabriel Molina · Jefferson Rojas

> **Formato sugerido:** screencast (graba pantalla + voz) con **OBS Studio**, **PowerPoint →
> Grabar**, **Zoom** o **Loom**. **Duración objetivo: ~7 minutos (máx. 8).** Se narra mostrando las
> **capturas** (`docs/evidencias/`), el **repositorio** y la pestaña **Actions**. No requiere AWS en vivo.
>
> **Defensa individual:** aunque el encargo es en pareja, cada uno debe dominar TODO. Si graban
> juntos, repártanse segmentos, pero ambos deben poder explicar cualquier parte.

**Leyenda:** 🖥️ = qué mostrar · 🎙️ = qué decir. *(Tip: habla con tus palabras, no leas de corrido.)*

---

### Segmento 0 — Introducción · ~30 s
🖥️ Diapositiva de título o repo en GitHub.
🎙️ "Hola, somos **Gabriel Molina** y **Jefferson Rojas**. En este video mostramos cómo
construimos la EP3: la aplicación *Tienda de Perritos*, de tres capas, orquestada en **AWS ECS
Fargate** con **CI/CD en GitHub Actions**, para el caso de Innovatech Chile."

---

### Segmento 1 — La app y su contenedorización · ~40 s
🖥️ App en el navegador (`ie2-app-navegador.png`) → ECR (`ie2-ecr-repos.png`).
🎙️ "La aplicación es un CRUD de productos con tres capas: **frontend** en nginx, **backend** en
Node.js con Express y base de datos **MySQL**. Cada capa tiene su Dockerfile; las empaquetamos como
imágenes y las subimos a **Amazon ECR**, el registro privado de AWS desde donde el clúster las
descarga."

---

### Segmento 2 — Clúster ECS Fargate · ~40 s
🖥️ Clúster con servicios (`ie1-cluster-servicios.png`).
🎙️ "Para orquestar usamos un clúster **ECS en modo Fargate**, que es *serverless*: no
administramos servidores. Elegimos Fargate y no EKS porque el laboratorio de AWS Academy no permite
crear roles IAM ni usar `eksctl`; Fargate reutiliza el rol `LabRole`. Aquí está el clúster con sus
**tres servicios activos**, y cada servicio repone solo las tareas que se caen."

---

### Segmento 3 — Redes, balanceadores y seguridad · ~55 s
🖥️ Balanceadores (`img08`) → regla de ruta (`ie2-alb-routing.png`) → Security Groups
(`ie1-sg-ecs.png`, `ie1-sg-alb.png`).
🎙️ "La comunicación la resolvimos con **balanceadores**, porque el lab deniega el descubrimiento
de servicios. Un **ALB** público enruta por ruta: lo que va a `/api/*` lo manda al backend y el
resto al frontend, así el front no necesita la IP del back. Para la base de datos usamos un **NLB
interno**, porque MySQL es TCP. En seguridad, dos **Security Groups**: el del ALB solo abre el
puerto 80 a Internet, y el de las tareas solo acepta tráfico desde el ALB y el 3306 dentro de la
VPC, así la base de datos **nunca queda expuesta**."

---

### Segmento 4 — Task Definitions y secrets · ~45 s
🖥️ Task definition (`img03`) → SSM Parameter Store (`ie5-ssm.png`).
🎙️ "Cada contenedor se describe en una **Task Definition**: imagen de ECR, CPU, memoria, puertos,
variables y secrets. El backend recibe como variables el host, usuario y nombre de la base; la
**contraseña no está en el código**: vive cifrada en **SSM Parameter Store** como *SecureString* y
se inyecta al contenedor solo en ejecución."

---

### Segmento 5 — Pipeline CI/CD (lo central) · ~1 min 20 s
🖥️ Archivo `.github/workflows/deploy-ecs.yml` → run en verde (`ie4-pipeline-verde.png`) → GitHub
Secrets (`ie5-github-secrets.png`).
🎙️ "Esta es la parte central: el **pipeline de CI/CD** en GitHub Actions, que corre en cada
**push a main**. El flujo es **build → push → deploy**: construye las imágenes de frontend y
backend, las **sube a ECR** con el hash del commit, **renderiza la task definition** con la imagen
nueva y hace **deploy en ECS** esperando estabilidad con `wait-for-service-stability` — o sea, no
se da por exitoso hasta que las tareas nuevas están sanas. Las credenciales de AWS van como
**secrets de GitHub**, nunca en el código. Aquí vemos una **ejecución completa en verde**: build,
push y deploy de los dos servicios, todo automático tras un commit."

---

### Segmento 6 — Autoscaling · ~40 s
🖥️ Política de escalado (`ie3-autoscaling.png`) → CPU en CloudWatch (`ie3-cpu-metric.png`).
🎙️ "Para que escale solo, configuramos **Application Auto Scaling** con *Target Tracking* sobre la
**CPU**, objetivo **50%**: si la CPU sube de 50%, ECS agrega tareas hasta 4; cuando baja, las quita
hasta 2. En CloudWatch se ve la métrica de CPU y en la consola las actividades de escalado."

---

### Segmento 7 — Logs y validación funcional · ~45 s
🖥️ CloudWatch Logs (`ie6-cloudwatch-logs.png`) → app (`ie2-app-navegador.png`).
🎙️ "Los tres contenedores envían **logs a CloudWatch**; aquí el backend inicializa el pool de
MySQL y escucha en el 3001, lo que confirma la conexión. Y la prueba final es la app: al abrir la
URL del ALB, el frontend carga, pide los productos, el backend consulta MySQL y los devuelve. Toda
la cadena **front → back → base de datos** funciona, y si una tarea se cae, ECS levanta otra sola."

---

### Segmento 8 — Problemas y soluciones · ~40 s
🖥️ Diapositiva de bullets (o tabla §10 del informe).
🎙️ "Tuvimos problemas reales: el lab no permite descubrimiento de servicios, así que usamos
balanceadores; no podíamos crear roles IAM, por eso Fargate con `LabRole`; y el pipeline falló una
vez por no tener cargados los secrets, y otra por un **rollback automático del circuit breaker** de
ECS cuando las tareas no estabilizaron. Todo lo diagnosticamos **leyendo los logs**."

---

### Segmento 9 — Conclusión · ~25 s
🖥️ Diapositiva de cierre / diagrama de arquitectura.
🎙️ "En resumen, la app quedó **orquestada, escalable, tolerante a fallos y con despliegue
automático**. Para producción real separaríamos los roles IAM, usaríamos **Amazon RDS**, **HTTPS**
y **OIDC** entre GitHub y AWS. ¡Gracias!"

---

**Duración total estimada: ~7 minutos.**

## Checklist antes de grabar
- [ ] Capturas abiertas y en orden (`docs/evidencias/`).
- [ ] Probar micrófono (graba 10 s de prueba).
- [ ] Hablar pausado; usar el guion como apoyo, no leerlo textual.
- [ ] Exportar en 1080p y revisar que se lea el texto de las capturas.
- [ ] Subir a AVA dentro del plazo.

## Mapa rápido capturas → segmento
| Captura | Segmento |
|---|---|
| `ie2-app-navegador.png` | 1, 7 |
| `ie2-ecr-repos.png` | 1 |
| `ie1-cluster-servicios.png` | 2 |
| `img08` (balanceadores) | 3 |
| `ie2-alb-routing.png` | 3 |
| `ie1-sg-ecs.png` / `ie1-sg-alb.png` | 3 |
| `img03` (task def) | 4 |
| `ie5-ssm.png` | 4 |
| `ie4-pipeline-verde.png` | 5 |
| `ie5-github-secrets.png` | 5 |
| `ie3-autoscaling.png` / `ie3-cpu-metric.png` | 6 |
| `ie6-cloudwatch-logs.png` | 7 |
