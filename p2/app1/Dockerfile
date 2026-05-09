FROM nginx:alpine

# Supprime la page nginx par défaut
RUN rm -rf /usr/share/nginx/html/*

# Copie ton site dans le serveur nginx
COPY index.html /usr/share/nginx/html/index.html
COPY style.css /usr/share/nginx/html/style.css

# Expose le port HTTP
EXPOSE 80

# Nginx tourne en premier plan (obligatoire en container)
CMD ["nginx", "-g", "daemon off;"]