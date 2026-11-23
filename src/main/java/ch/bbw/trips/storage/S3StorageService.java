package ch.bbw.trips.storage;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

import java.io.IOException;

/**
 * Speichert Fotos in einem S3-Bucket. Die Zugangsdaten kommen aus der Default-Credentials-Kette,
 * im ECS-Task also von der Task-Rolle: im Code und im Image stehen keine Schlüssel.
 */
@Service
@ConditionalOnProperty(name = "app.storage.type", havingValue = "s3")
public class S3StorageService implements StorageService {

	private final S3Client s3;
	private final String bucket;

	public S3StorageService(S3Client s3, S3Properties properties) {
		this.s3 = s3;
		this.bucket = properties.bucket();
	}

	@Override
	public String store(MultipartFile file) {
		String key = StorageRules.newFilename(file);
		try {
			s3.putObject(
					PutObjectRequest.builder().bucket(bucket).key(key).contentType(file.getContentType()).build(),
					RequestBody.fromBytes(file.getBytes()));
		} catch (S3Exception e) {
			throw translate("speichern", e);
		} catch (IOException e) {
			throw new StorageException("Datei konnte nicht gelesen werden", e);
		}
		return key;
	}

	@Override
	public Resource load(String filename) {
		String key = StorageRules.requireSafeName(filename);
		try {
			byte[] bytes = s3.getObjectAsBytes(GetObjectRequest.builder().bucket(bucket).key(key).build())
					.asByteArray();
			return new ByteArrayResource(bytes);
		} catch (NoSuchKeyException e) {
			// Resource.exists() ist für ein leeres Marker-Objekt immer true, daher eigene Resource
			return new MissingResource();
		} catch (S3Exception e) {
			throw translate("laden", e);
		}
	}

	private static StorageException translate(String action, S3Exception e) {
		if (e.statusCode() == 403) {
			return new StorageException("Zugriff auf den Bildspeicher verweigert (fehlende S3-Rechte?), Aktion: " + action, e);
		}
		return new StorageException("Bildspeicher nicht erreichbar, Aktion: " + action, e);
	}

	/** Resource für einen nicht vorhandenen Key: exists() ist false, Controller liefert 404. */
	private static final class MissingResource extends ByteArrayResource {
		MissingResource() {
			super(new byte[0]);
		}

		@Override
		public boolean exists() {
			return false;
		}
	}
}
