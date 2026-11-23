package ch.bbw.trips.storage;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;

/** Baut den S3-Client nur, wenn S3 als Storage aktiv ist. Credentials: Default Provider Chain (Task-Rolle). */
@Configuration
@ConditionalOnProperty(name = "app.storage.type", havingValue = "s3")
@EnableConfigurationProperties(S3Properties.class)
public class S3Config {

	@Bean(destroyMethod = "close")
	S3Client s3Client(S3Properties properties) {
		if (properties.bucket() == null || properties.bucket().isBlank()) {
			throw new IllegalStateException("app.storage.s3.bucket (APP_STORAGE_S3_BUCKET) ist nicht gesetzt");
		}
		return S3Client.builder().region(Region.of(properties.region())).build();
	}
}
