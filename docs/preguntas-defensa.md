# Guion de Defensa Técnica Individual — EP3
## Preguntas probables del/la docente y respuestas modelo

> La defensa es **individual** (IE8, IE9, IE10, IE11 = 25% c/u del 80% de la presentación).
> Debes poder defender **toda** la solución, aunque no la hayas programado tú.
> Estúdiate este documento + el `informe-tecnico.md`. Las respuestas están en lenguaje hablado,
> para que las digas con tus palabras, no para leerlas.

---

## Bloque 1 — Fundamentos de orquestación (IE8)

**P: ¿Qué es ECS y qué es Fargate? ¿Por qué los eligieron?**
R: ECS es el orquestador de contenedores de AWS: decide dónde y cómo corren los contenedores y
mantiene la cantidad que uno define. Fargate es el modo *serverless* de ECS: uno no administra
servidores EC2, solo dice cuánta CPU y memoria necesita cada contenedor y AWS pone la
infraestructura. Lo elegimos porque en el Learner Lab no podemos crear roles IAM ni usar `eksctl`
para EKS de forma fiable, y Fargate reutiliza el rol `LabRole` y nos evita administrar nodos.

**P: ¿Diferencia entre una Task Definition, una Task y un Servicio?**
R: La *Task Definition* es la plantilla (qué imagen, cuánta CPU/memoria, puertos, variables,
secrets, logs). Una *Task* es una instancia en ejecución de esa plantilla. El *Servicio* es el que
mantiene vivas N tasks (el `desiredCount`), las reemplaza si mueren y las conecta al balanceador.

**P: ¿Qué es un clúster en este contexto?**
R: Es la agrupación lógica donde corren nuestros servicios y tasks. El nuestro se llama
`tienda-cluster` y está en modo Fargate.

**P: ¿Cómo funciona el autoscaling que configuraron?**
R: Usamos Application Auto Scaling con una política de *Target Tracking* sobre la CPU promedio del
servicio, con objetivo 50%. Si la CPU pasa de 50%, ECS agrega tasks (hasta 4); si baja, las quita
(hasta un mínimo de 2). Pusimos *cooldowns* de 60 segundos para que no oscile.

**P: ¿Por qué 50% de CPU y no 80%?**
R: El 50% deja margen para absorber un pico de tráfico mientras se levantan tasks nuevas (que
tardan unos segundos). Con 80% nos arriesgaríamos a saturar antes de alcanzar a escalar. Es un
equilibrio entre disponibilidad y costo.

**P: ¿Qué balanceadores usan y por qué dos tipos?**
R: Un **ALB** (capa 7, HTTP) público para el frontend y el backend, que enruta por ruta: `/` va al
frontend y `/api/*` al backend. Y un **NLB** (capa 4, TCP) interno para la base de datos, porque
MySQL no es HTTP, es TCP en el puerto 3306.

**P: ¿Cómo dan alta disponibilidad y tolerancia a fallos?**
R: Cada servicio corre 2 tasks mínimo, repartidas y con health checks en el target group. Si una
task falla, ECS la reemplaza automáticamente. Y si un despliegue nuevo sale malo, el *circuit
breaker* de ECS hace rollback solo a la versión estable.

---

## Bloque 2 — Despliegue y redes

**P: ¿Cómo se comunican el frontend y el backend?**
R: El navegador llama a `/api/...`. El ALB tiene una regla de enrutamiento: las rutas `/api/*` las
manda al target group del backend, y el resto al frontend. Así el frontend no necesita saber la IP
del backend; lo resuelve el balanceador.

**P: ¿Y el backend con la base de datos?**
R: El backend usa como `DB_HOST` el DNS del NLB interno. El NLB expone MySQL en el puerto 3306
dentro de la VPC, con un nombre DNS estable aunque la task de la BD cambie de IP.

**P: ¿Por qué no usaron DNS interno (Cloud Map / Service Connect)?**
R: Porque el Learner Lab deniega la acción `servicediscovery:*`. Por eso resolvimos el
descubrimiento con balanceadores en lugar de DNS de servicio.

**P: ¿De dónde salen las imágenes de los contenedores?**
R: De Amazon ECR, nuestro registro privado. Tenemos tres repos: `tienda-frontend`,
`tienda-backend` y `tienda-db`. El pipeline construye y sube las imágenes ahí.

**P: ¿Qué variables de entorno usa el backend?**
R: `DB_HOST` (el NLB), `DB_USER`, `DB_NAME`, `DB_PORT`, y `DB_PASSWORD` que **no** es una variable
normal sino un *secret* inyectado desde SSM.

**P: ¿Qué Security Groups configuraron?**
R: Uno para el ALB que acepta el puerto 80 desde Internet, y otro para las tasks de ECS que acepta
los puertos 80 y 3001 solo desde el ALB, y el 3306 solo desde dentro de la VPC. Así la BD nunca
queda expuesta a Internet.

---

## Bloque 3 — Pipeline CI/CD (IE9)

**P: Explica el pipeline paso a paso.**
R: Está en GitHub Actions y se dispara con cada push a `main`. Hace: checkout del código →
configura credenciales de AWS desde los secrets → login a ECR → arma un tag con los primeros 7
caracteres del commit → build y push de las imágenes de frontend y backend a ECR → renderiza la
task definition con la imagen nueva → hace deploy en ECS esperando a que el servicio estabilice.

**P: ¿Qué significa `wait-for-service-stability`?**
R: Que el paso de deploy no se da por exitoso hasta que ECS confirma que las tasks nuevas están
corriendo y sanas. Si no estabilizan, el pipeline falla, y así nos enteramos.

**P: ¿Por qué etiquetan la imagen con el SHA del commit?**
R: Para tener trazabilidad: cada imagen queda asociada a un commit exacto, y si hay que volver
atrás sabemos qué versión desplegar.

**P: ¿Cómo manejan las credenciales en el pipeline?**
R: Como *GitHub Actions Secrets*: el access key, el secret key y el session token del Learner Lab.
El workflow los lee con `${{ secrets.* }}` y nunca quedan escritos en el código.

**P: Tuvieron fallas en el pipeline, ¿qué pasó?** *(pregunta muy probable)*
R: Sí, dos. La primera ejecución falló en segundos porque todavía no habíamos cargado los secrets
de AWS en el repo ("Could not load credentials"). La solución fue cargarlos. Otra falló en el
deploy: el *circuit breaker* de ECS hizo rollback porque las tasks nuevas no estabilizaron a
tiempo; al relanzar quedó estable. Las fallas no fueron del código sino de configuración y de
estabilización, y las diagnosticamos desde los logs de Actions.

**P: ¿Cuánto se demora el pipeline?**
R: Entre 10 y 16 minutos; la mayor parte es la espera de estabilización del servicio en ECS.

---

## Bloque 4 — Secrets y seguridad (IE10)

**P: ¿Cómo protegen la contraseña de la base de datos?**
R: Está en AWS SSM Parameter Store como *SecureString*, en `/tienda/db_password`. La task
definition la referencia en el bloque `secrets`, así que el contenedor la recibe como variable de
entorno en tiempo de ejecución, pero no queda en la imagen ni en el repositorio.

**P: ¿Por qué eso es más seguro que ponerla en el Dockerfile?**
R: Porque si está en el Dockerfile o en el código, queda en el historial de git y en la imagen, y
cualquiera con acceso la ve. Con SSM la contraseña vive cifrada en AWS y se inyecta solo al
contenedor que la necesita.

---

## Bloque 5 — Análisis crítico y proyección (IE10)

**P: ¿Cuál fue el mayor problema y cómo lo resolvieron?**
R: La restricción del Learner Lab de no poder usar DNS interno de servicios. Lo resolvimos
rediseñando la comunicación con balanceadores: ALB por ruta para front-back y NLB para la BD.

**P: ¿Qué aprendieron?**
R: A adaptar la arquitectura a las restricciones reales del entorno (IAM, service discovery), a
automatizar despliegues de punta a punta y a diagnosticar fallas leyendo logs en vez de adivinar.

**P: Si esto fuera a producción real, ¿qué cambiarían?**
R: Separaríamos los roles IAM con privilegio mínimo, moveríamos la BD a Amazon RDS gestionada,
pondríamos HTTPS en el ALB con un dominio propio, usaríamos OIDC entre GitHub y AWS para no
depender de claves que caducan, y agregaríamos alarmas de CloudWatch y un entorno de staging.

---

## Preguntas "trampa" frecuentes

- **¿Esto es Kubernetes?** No. Es ECS, el orquestador propio de AWS. Hay carpeta `k8s/` en el repo
  pero es de una exploración previa de EKS que **no** se usa en la solución final (que es ECS Fargate).
- **¿Fargate usa EC2?** Por debajo sí hay cómputo, pero **nosotros no administramos** esas máquinas;
  esa es la gracia de Fargate.
- **¿El NLB es público?** No, es **interno** a la VPC; solo lo usa el backend para llegar a la BD.
- **¿Dónde se guardan los datos si se reinicia la task de MySQL?** Punto honesto: en esta entrega
  la BD corre en contenedor sin volumen persistente, así que los datos se reinician con la task.
  En producción usaríamos RDS o EFS. (Mejor decir la verdad si lo preguntan.)
