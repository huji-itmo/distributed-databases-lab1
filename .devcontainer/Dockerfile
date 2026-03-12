FROM postgres:16-bookworm

# Обновляем пакеты на этапе сборки
RUN apt update && \
    apt upgrade -y && \
    apt install -y curl wget git nano && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*


RUN sed -i 's/^# *\(ru_RU\.CP.*\)/\1/' /etc/locale.gen && \
    locale-gen

USER postgres