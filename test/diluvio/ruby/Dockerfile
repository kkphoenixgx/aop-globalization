FROM public.ecr.aws/docker/library/ruby:3.2
WORKDIR /app
COPY sdk sdk
COPY client.rb .
CMD ["ruby", "client.rb"]
