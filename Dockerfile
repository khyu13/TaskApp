
# 1 — deps: instala dependencias base

FROM node:22-alpine AS deps

WORKDIR /app

# Copiamos solo los archivos de dependencias para aprovechar la caché de Docker
COPY package.json package-lock.json ./

RUN npm ci

#  2 — test: ejecuta los tests unitarios
#   Si fallan, el build se detiene aquí.

FROM deps AS test

# Copiamos el código fuente necesario para los tests
COPY src/ ./src/
COPY vite.config.js ./

RUN npm run test

#  3 — dev: servidor de desarrollo (hot-reload)
#   Uso: docker build --target dev -t taskapp:dev .
#        docker run -p 3000:3000 -v $(pwd)/src:/app/src taskapp:dev

FROM deps AS dev

COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev"]


#  4 — build: genera los archivos estáticos
#   Parte del stage "test" para garantizar que
#   los tests han pasado antes de construir.

FROM test AS build

COPY index.html ./
COPY public/ ./public/

RUN npm run build


# 5 — production: imagen final con Nginx
#   Solo contiene los estáticos + Nginx, sin Node.js

FROM nginx:stable-alpine AS production

# Eliminamos la configuración por defecto de Nginx
RUN rm /etc/nginx/conf.d/default.conf

# Copiamos nuestra configuración personalizada
COPY nginx.conf /etc/nginx/conf.d/app.conf

# Copiamos los archivos estáticos generados en el stage build
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
