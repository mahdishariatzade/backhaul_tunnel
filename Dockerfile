# مرحله اول: Builder برای دانلود و استخراج باینری
FROM alpine:latest AS builder

# ARG برای نسخه و معماری (برای GitLab CI مفید است)
ARG BACKHAUL_VERSION=latest
ARG ARCH_NAME

# تنظیم متغیرهای محیطی
ENV BACKHAUL_CONFIG="/app/config.toml"

# نصب پیش‌نیازها برای دانلود
RUN apk add --no-cache curl ca-certificates tar

# تشخیص معماری اگر ARG داده نشده باشد
RUN if [ -z "$ARCH_NAME" ]; then \
        ARCH=$(uname -m); \
        case $ARCH in \
            x86_64) ARCH_NAME="amd64" ;; \
            aarch64) ARCH_NAME="arm64" ;; \
            armv7l) ARCH_NAME="armv7" ;; \
            *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
        esac; \
    fi && \
    echo "Downloading Backhaul version $BACKHAUL_VERSION for $ARCH_NAME" && \
    curl -L "https://github.com/Musixal/Backhaul/releases/download/$BACKHAUL_VERSION/backhaul_linux_${ARCH_NAME}.tar.gz" -o /tmp/backhaul.tar.gz && \
    tar -xzf /tmp/backhaul.tar.gz -C /tmp && \
    mv /tmp/backhaul /tmp/backhaul-bin && \
    chmod +x /tmp/backhaul-bin && \
    rm /tmp/backhaul.tar.gz

# مرحله نهایی: Runtime image
FROM alpine:latest

# ARG برای نسخه (برای metadata)
ARG BACKHAUL_VERSION=latest

# تنظیم متغیرهای محیطی
ENV BACKHAUL_CONFIG="/app/config.toml"

# نصب پیش‌نیازهای runtime
RUN apk add --no-cache ca-certificates tzdata

# کپی باینری از مرحله builder
COPY --from=builder /tmp/backhaul-bin /usr/local/bin/backhaul

# ایجاد دایرکتوری اپلیکیشن
WORKDIR /app

# کپی کردن فایل کانفیگ (اگر موجود باشد)
COPY config.toml ${BACKHAUL_CONFIG}

# ایجاد کاربر غیر root برای امنیت
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

# تنظیم پورت‌های پیش‌فرض
EXPOSE 3080 2060

# تنظیم health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep backhaul || exit 1

# اجرای Backhaul
CMD ["backhaul", "server", "--config", "${BACKHAUL_CONFIG}"]

# افزودن labels برای GitLab CI و metadata
LABEL org.opencontainers.image.version="${BACKHAUL_VERSION}" \
      org.opencontainers.image.source="https://github.com/Musixal/Backhaul" \
      org.opencontainers.image.description="Backhaul reverse tunneling in Docker" 