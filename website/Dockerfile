FROM nginx:1.25-alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Custom nginx config for SPA + static site
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy pre-built Astro site
COPY dist/ /usr/share/nginx/html/

# App Runner uses port 8080
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
