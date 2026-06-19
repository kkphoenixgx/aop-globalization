# =============================================================================
# O Vidente Meteorológico — Dockerfile
# R statistical flood prediction client for Operação Dilúvio
# =============================================================================

FROM public.ecr.aws/docker/library/r-base:4.3.0

# Install jsonlite for JSON serialization/deserialization
RUN R -e 'install.packages("jsonlite", repos="https://cloud.r-project.org")'

WORKDIR /app

COPY client.R .

CMD ["Rscript", "client.R"]
