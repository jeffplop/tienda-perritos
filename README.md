# 🐶 Tienda de Perritos — Orquestación en AWS ECS Fargate (EP3)

Aplicación CRUD de 3 capas (Frontend + Backend + Base de datos) desplegada como
**contenedores orquestados en AWS ECS Fargate**, con **CI/CD automatizado** mediante
GitHub Actions. Proyecto de la Evaluación Parcial N°3 — *Introducción a Herramientas DevOps*.

---

## 1. Arquitectura

```
                    Internet
                       │
            ┌──────────▼───────────┐
            │   ALB público :80    │   tienda-alb-1107170895.us-east-1.elb.amazonaws.com
            │  (Application LB)    │
            │   /        → frontend│
            │   /api/*   → backend │
            └─────┬──────────┬─────┘
                  │          │
        ┌─────────▼──┐   ┌───▼─────────┐
        │  FRONTEND  │   │   BACKEND   │   (Fargate, awsvpc)
        │  nginx :80 │   │ node :3001  │   autoscaling CPU 50% (2→4)
        │  (2 tasks) │   │  (2 tasks)  │
        └────────────┘   └──────┬──────┘
                                │  DB_HOST = NLB interno
                         ┌──────▼───────┐
                         │  NLB interno │  (Network LB, TCP 3306)
                         │   :3306      │
                         └──────┬───────┘
                                │
                         ┌──────▼───────┐
                         │   MySQL DB   │  (1 task, secret desde SSM)
                         │  :3306       │
                         └──────────────┘
```

### ¿Por qué esta arquitectura?
- **ECS Fargate** (no EKS): en AWS Academy Learner Lab no se pueden crear roles IAM ni
  usar `eksctl` de forma fiable; Fargate usa el rol preexistente `LabRole` y es serverless.
- **Sin DNS interno (Cloud Map / Service Connect)**: el lab **deniega** `servicediscovery:*`.
  Por eso la comunicación entre servicios se resuelve con balanceadores:
  - **Front → Back**: el **ALB público** enruta por ruta. El navegador llama a `/api/*`
    y el propio ALB lo manda al backend. No hace falta DNS interno.
  - **Back → DB**: un **NLB interno** (capa 4, TCP) expone MySQL en un DNS estable que el
    backend usa como `DB_HOST`.

---

## 2. Componentes

| Carpeta | Contenido |
|---|---|
| `frontend/` | nginx + HTML/JS (CRUD de productos). Sirve estáticos; las `/api/*` las enruta el ALB. |
| `backend/`  | API Node.js/Express + MySQL2. Endpoints `/api/productos` (CRUD) y `/api/health`. |
| `db/`       | Imagen MySQL 8 con `init.sql` (crea BD `tienda_perritos` y carga productos). |
| `ecs/`      | Task Definitions (`taskdef-*.json`), política de autoscaling y `infra-vars.txt`. |
| `.github/workflows/deploy-ecs.yml` | Pipeline CI/CD: build → push (ECR) → deploy (ECS). |

---

## 3. Recursos AWS creados

| Recurso | Nombre / ID |
|---|---|
| Región | `us-east-1` · Cuenta `471112880379` |
| Repos ECR | `tienda-frontend`, `tienda-backend`, `tienda-db` |
| Clúster ECS | `tienda-cluster` (Fargate) |
| Servicios | `tienda-db` (1), `tienda-backend` (2→4), `tienda-frontend` (2→4) |
| ALB público | `tienda-alb` → http://tienda-alb-1107170895.us-east-1.elb.amazonaws.com |
| NLB interno | `tienda-nlb` (TCP 3306) |
| Security Groups | `tienda-alb-sg` (80 público), `tienda-ecs-sg` (80/3001 desde ALB, 3306 desde VPC) |
| Secret | SSM Parameter Store `/tienda/db_password` (SecureString) |
| Logs | CloudWatch `/ecs/tienda-frontend`, `/ecs/tienda-backend`, `/ecs/tienda-db` |
| Rol IAM | `LabRole` (execution + task role) |

---

## 4. Despliegue manual desde cero (resumen de comandos)

> Requisitos: AWS CLI configurado con credenciales del Learner Lab, Docker Desktop, región `us-east-1`.

```bash
# 1) Login a ECR (en PowerShell usar -p para evitar el bug de stdin)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 471112880379.dkr.ecr.us-east-1.amazonaws.com

# 2) Build & push de las 3 imágenes
docker build -t 471112880379.dkr.ecr.us-east-1.amazonaws.com/tienda-db:v1 ./db
docker build -t 471112880379.dkr.ecr.us-east-1.amazonaws.com/tienda-backend:v1 ./backend
docker build -t 471112880379.dkr.ecr.us-east-1.amazonaws.com/tienda-frontend:v1 ./frontend
docker push 471112880379.dkr.ecr.us-east-1.amazonaws.com/tienda-db:v1
docker push 471112880379.dkr.ecr.us-east-1.amazonaws.com/tienda-backend:v1
docker push 471112880379.dkr.ecr.us-east-1.amazonaws.com/tienda-frontend:v1

# 3) Registrar task definitions
aws ecs register-task-definition --cli-input-json file://ecs/taskdef-db.json
aws ecs register-task-definition --cli-input-json file://ecs/taskdef-backend.json
aws ecs register-task-definition --cli-input-json file://ecs/taskdef-frontend.json

# 4) Crear servicios (ver ecs/infra-vars.txt para los ARNs de target groups/subnets/SG)
#    db -> tg-db (NLB) | backend -> tg-backend (ALB) | frontend -> tg-frontend (ALB)
```

(La creación de VPC SGs, ALB/NLB, target groups, listeners y autoscaling está en el historial
de comandos; los IDs quedaron guardados en `ecs/infra-vars.txt`.)

---

## 5. CI/CD (GitHub Actions)

El pipeline `.github/workflows/deploy-ecs.yml` se ejecuta en cada `push` a `main`:

1. **Build** de las imágenes frontend y backend.
2. **Push** a ECR con tag = primeros 7 del commit SHA (+ `latest`).
3. **Deploy**: registra una nueva revisión de la task definition con la imagen nueva y
   actualiza el servicio ECS (`wait-for-service-stability`).

### Secrets requeridos en el repositorio (Settings → Secrets → Actions)
| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID` | del Learner Lab |
| `AWS_SECRET_ACCESS_KEY` | del Learner Lab |
| `AWS_SESSION_TOKEN` | del Learner Lab |

> ⚠️ **Importante (Learner Lab):** las credenciales **caducan** al reiniciar el lab.
> Antes de ejecutar el pipeline, actualizar los 3 secrets con las credenciales nuevas
> (AWS Details → AWS CLI: Show).

---

## 6. Uso de la aplicación

Abrir en el navegador: **http://tienda-alb-1107170895.us-east-1.elb.amazonaws.com**

- **Cargar Productos**: lista los productos (GET `/api/productos`).
- **Guardar**: crea o actualiza (POST/PUT).
- **Editar / Eliminar**: por fila.

Endpoints del backend:
- `GET  /api/health` — healthcheck.
- `GET  /api/productos` — listar.
- `POST /api/productos` — crear `{nombre, descripcion, precio, stock}`.
- `PUT  /api/productos/:id` — actualizar.
- `DELETE /api/productos/:id` — eliminar.

---

## 7. Autoscaling, logs y autorecuperación

- **Autoscaling** (IE3): Application Auto Scaling con *Target Tracking* a **50% CPU**
  (min 2, max 4) en frontend y backend. Umbral 50% = margen para picos sin sobre-aprovisionar.
- **Logs** (IE6): driver `awslogs` → CloudWatch. Ver con
  `aws logs tail /ecs/tienda-backend --follow`.
- **Autorecuperación** (IE7): si una task muere, el servicio ECS la reemplaza
  automáticamente para mantener el `desiredCount`.

---

## 8. Troubleshooting (problemas reales del Learner Lab)

| Síntoma | Causa | Solución |
|---|---|---|
| `explicit deny ... voc-cancel-cred` | El lab está **detenido** o sin presupuesto | Reiniciar el lab (punto verde) y pegar credenciales nuevas |
| `docker login ... 400 Bad Request` | PowerShell corrompe el token por stdin | Usar `docker login -u AWS -p <token>` |
| `ExpiredToken` | Sesión del lab caducó | Pegar credenciales nuevas en `~/.aws/credentials` |
| `servicediscovery ... AccessDenied` | Cloud Map denegado en el lab | Usar ALB (front-back) y NLB (back-db) en vez de DNS interno |
