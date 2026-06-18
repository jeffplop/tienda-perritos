# Imagen base MySQL 8 oficial
FROM mysql:8

# La base de datos se crea automáticamente al primer arranque.
ENV MYSQL_DATABASE=tienda_perritos

# Credenciales NO hardcodeadas (IE5: gestión segura de secrets):
#  - En ECS Fargate: MYSQL_ROOT_PASSWORD se inyecta desde AWS SSM Parameter Store
#    (ver bloque "secrets" en ecs/taskdef-db.json).
#  - En local / docker-compose: pasar MYSQL_ROOT_PASSWORD como variable de entorno.

# Copiar el script de inicialización dentro de la imagen
# Se ejecuta automáticamente la primera vez que se levante el contenedor
COPY init.sql /docker-entrypoint-initdb.d/

# Exponer el puerto de MySQL
EXPOSE 3306
