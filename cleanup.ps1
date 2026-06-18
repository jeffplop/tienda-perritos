# ============================================================
#  cleanup.ps1  -  Borra TODOS los recursos AWS de Tienda Perritos (EP3)
# ------------------------------------------------------------
#  USO (terminal de VS Code, PowerShell, dentro de la carpeta del repo):
#     powershell -ExecutionPolicy Bypass -File .\cleanup.ps1
#  Requiere: AWS CLI con credenciales del Learner Lab ACTIVAS.
#  Nota: ejecutar DESPUES de la presentacion. Esto es destructivo.
# ============================================================

$ErrorActionPreference = "Continue"
$region   = "us-east-1"
$cluster  = "tienda-cluster"
$services = @("tienda-frontend","tienda-backend","tienda-db")

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " LIMPIEZA Tienda Perritos (EP3)  -  region $region" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$ok = Read-Host "Esto BORRARA todos los recursos del proyecto. Escribe SI para continuar"
if ($ok -ne "SI") { Write-Host "Cancelado." -ForegroundColor Yellow; exit }

# 1) Autoscaling: dar de baja los scalable targets
Write-Host "`n[1/9] Quitando autoscaling..." -ForegroundColor Yellow
foreach ($s in @("tienda-backend","tienda-frontend")) {
  aws application-autoscaling deregister-scalable-target --service-namespace ecs `
    --resource-id "service/$cluster/$s" --scalable-dimension ecs:service:DesiredCount --region $region 2>$null
}

# 2) Borrar servicios ECS (forzado) y esperar a que queden inactivos
Write-Host "`n[2/9] Borrando servicios ECS..." -ForegroundColor Yellow
foreach ($s in $services) {
  aws ecs delete-service --cluster $cluster --service $s --force --region $region --query "service.serviceName" --output text 2>$null
}
Write-Host "  Esperando a que los servicios drenen (1-3 min)..."
aws ecs wait services-inactive --cluster $cluster --services $services --region $region 2>$null

# 3) Borrar balanceadores (ALB publico + NLB interno)
Write-Host "`n[3/9] Borrando balanceadores..." -ForegroundColor Yellow
$albArn = aws elbv2 describe-load-balancers --names tienda-alb --region $region --query "LoadBalancers[0].LoadBalancerArn" --output text 2>$null
$nlbArn = aws elbv2 describe-load-balancers --names tienda-nlb --region $region --query "LoadBalancers[0].LoadBalancerArn" --output text 2>$null
foreach ($arn in @($albArn,$nlbArn)) {
  if ($arn -and $arn -ne "None") { aws elbv2 delete-load-balancer --load-balancer-arn $arn --region $region 2>$null }
}
Write-Host "  Esperando a que se borren los balanceadores..."
foreach ($arn in @($albArn,$nlbArn)) {
  if ($arn -and $arn -ne "None") { aws elbv2 wait load-balancers-deleted --load-balancer-arns $arn --region $region 2>$null }
}

# 4) Borrar target groups
Write-Host "`n[4/9] Borrando target groups..." -ForegroundColor Yellow
foreach ($tg in @("tg-frontend","tg-backend","tg-db")) {
  $arn = aws elbv2 describe-target-groups --names $tg --region $region --query "TargetGroups[0].TargetGroupArn" --output text 2>$null
  if ($arn -and $arn -ne "None") { aws elbv2 delete-target-group --target-group-arn $arn --region $region 2>$null; Write-Host "  $tg borrado." }
}

# 5) Borrar cluster ECS
Write-Host "`n[5/9] Borrando cluster ECS..." -ForegroundColor Yellow
aws ecs delete-cluster --cluster $cluster --region $region --query "cluster.status" --output text 2>$null

# 6) Borrar log groups de CloudWatch
Write-Host "`n[6/9] Borrando log groups..." -ForegroundColor Yellow
foreach ($lg in @("/ecs/tienda-frontend","/ecs/tienda-backend","/ecs/tienda-db")) {
  aws logs delete-log-group --log-group-name $lg --region $region 2>$null; Write-Host "  $lg"
}

# 7) Borrar secret de SSM
Write-Host "`n[7/9] Borrando secret SSM /tienda/db_password..." -ForegroundColor Yellow
aws ssm delete-parameter --name "/tienda/db_password" --region $region 2>$null

# 8) Borrar security groups (reintentos: las ENIs tardan en liberarse)
Write-Host "`n[8/9] Borrando security groups (puede requerir reintentos)..." -ForegroundColor Yellow
foreach ($sg in @("tienda-ecs-sg","tienda-alb-sg")) {
  $id = aws ec2 describe-security-groups --filters "Name=group-name,Values=$sg" --region $region --query "SecurityGroups[0].GroupId" --output text 2>$null
  if (-not $id -or $id -eq "None") { Write-Host "  $sg ya no existe."; continue }
  $done = $false
  for ($i=1; $i -le 6; $i++) {
    aws ec2 delete-security-group --group-id $id --region $region 2>$null
    $check = aws ec2 describe-security-groups --filters "Name=group-name,Values=$sg" --region $region --query "SecurityGroups[0].GroupId" --output text 2>$null
    if (-not $check -or $check -eq "None") { $done = $true; break }
    Write-Host "  $sg en uso (ENIs liberandose), reintento $i/6 en 20s..."
    Start-Sleep 20
  }
  if ($done) { Write-Host "  $sg ($id) borrado." -ForegroundColor Green }
  else { Write-Host "  No se pudo borrar $sg ($id). Vuelve a correr el script en unos minutos." -ForegroundColor Red }
}

# 9) (OPCIONAL) Borrar repos ECR + imagenes.
#    Se CONSERVAN por defecto (por si quieres re-desplegar). Descomenta para borrarlos:
Write-Host "`n[9/9] Repos ECR: se CONSERVAN (edita el script para borrarlos)." -ForegroundColor Yellow
# foreach ($r in @("tienda-frontend","tienda-backend","tienda-db")) {
#   aws ecr delete-repository --repository-name $r --force --region $region 2>$null
# }

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host " LIMPIEZA TERMINADA. Verifica en la consola AWS." -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
