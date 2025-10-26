FROM nginx:stable-alpine
COPY ../website-src/ /usr/share/nginx/html
ENV FIRST_NAME="John"
CMD ["nginx", "-g", "daemon off;"]
