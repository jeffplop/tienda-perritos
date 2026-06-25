# Evidencias EP3 — Pruebas dinámicas (Tienda Perritos · ECS Fargate)

Cuenta AWS: `666586747120` · Región: `us-east-1` · App: http://tienda-alb-93590141.us-east-1.elb.amazonaws.com

Estas pruebas complementan el despliegue con la evidencia **dinámica** que pide la rúbrica
(autoscaling bajo carga, recuperación, análisis de tiempos).

---

## IE7 — Autorecuperación de tareas ✅ DEMOSTRADO
Archivo: `IE7-recuperacion.txt`

- Se detuvo **a la fuerza** 1 tarea del frontend (`aws ecs stop-task`) → el servicio bajó de **2 → 1**.
- ECS **reprogramó automáticamente** una tarea nueva → volvió a **2/2 healthy en ~2.5 min**, sin intervención manual.
- Eventos que lo prueban: *"has started 1 tasks"*, *"registered 1 targets"*, *"deployment completed"*, *"has reached a steady state"*.

## IE3 — Autoscaling ✅ MECANISMO DEMOSTRADO
Archivo: `IE3-autoscaling.txt`

- **Política de producción:** TargetTracking **CPU 50%**, min 2 / max 4 (`ecs/scaling-cpu.json`). Verificada activa.
- **Prueba de carga real** (120 hilos): la CPU del backend llegó a **95% pico / ~44% promedio**.
  > Honestidad técnica: desde **un solo PC** no se alcanzó a sostener el **promedio > 50%** (el valor que mira el autoscaling) durante los 3 min que requiere la alarma. Más hilos (480) bajaron el rendimiento porque el cuello de botella pasó a ser el cliente.
- **Demo del mecanismo** (con transparencia): se bajó **temporalmente** el umbral a 10%, la carga llevó la CPU a ~17–27% promedio, y ECS **escaló el backend de 2 → 3 → 4 tareas** (*"Successfully set desired count to 4"*). Luego se **restauró el umbral a 50%**.
- **Conclusión:** el autoscaling funciona de punta a punta (métrica → alarma → scale-out → tareas nuevas → scale-in). Para disparar al 50% real haría falta una herramienta de carga distribuida (k6 / JMeter desde varios orígenes).

## IE6 — Análisis de tiempos del pipeline ✅ ANALIZADO
Archivo: `IE6-pipeline-tiempos.txt`

- Run exitoso `28144024385`: duración total **8.2 min**.
- Desglose: `build & push` ≈ **16 s** (capas base cacheadas en ECR); el **95% del tiempo** son los 2 pasos *"Desplegar en ECS"* (238 s + 232 s) por `wait-for-service-stability`.
- **Conclusión:** el cuello de botella NO es la construcción de imágenes, sino la **estabilización del rolling update** (ECS esperando a que las tareas nuevas pasen health checks).

---

## Archivos de evidencia
| Archivo | Contenido |
|---|---|
| `IE7-recuperacion.txt` | Log con timestamps de la autorecuperación (2→1→2) |
| `IE3-autoscaling.txt` | Carga real (CPU→95%) + demo de scale-out (2→4) + CPU CloudWatch |
| `IE6-pipeline-tiempos.txt` | Duración por paso del pipeline |
| `load_test.py` | Generador de carga usado (hilos concurrentes a /api/productos) |
| `scaling-cpu-demo.json` | Umbral temporal (10%) usado solo para la demo del mecanismo |

> Capturas tipo gráfico (CPU vs. tareas, recuperación) se generaron a partir de estos datos reales.
