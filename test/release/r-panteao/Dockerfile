FROM r-base:4.3.2
WORKDIR /app
COPY . .
RUN R -e \"install.packages('panteao', repos='http://cran.us.r-project.org')\"
CMD ["Rscript", "main.R"]
