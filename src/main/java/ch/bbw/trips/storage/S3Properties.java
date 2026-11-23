package ch.bbw.trips.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** {@code app.storage.s3.*}: Bucket und Region kommen aus Umgebungsvariablen (APP_STORAGE_S3_BUCKET, ...). */
@ConfigurationProperties(prefix = "app.storage.s3")
public record S3Properties(String bucket, String region) {
}
