FROM postgres:15

RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-15 \
    git \
    clang \
    llvm \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --branch v0.4.0 https://github.com/pgvector/pgvector.git /pgvector \
    && cd /pgvector \
    && make \
    && make install

CMD ["postgres"]
