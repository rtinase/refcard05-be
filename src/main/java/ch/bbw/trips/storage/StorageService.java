package ch.bbw.trips.storage;

import org.springframework.core.io.Resource;
import org.springframework.http.MediaType;
import org.springframework.web.multipart.MultipartFile;

/**
 * Speichert Mitarbeiterfotos. Implementierungen: {@link LocalStorageService} (Dateisystem, lokale
 * Entwicklung/Docker Compose) und {@link S3StorageService} (Amazon S3, AWS).
 * Ausgewählt wird per {@code app.storage.type=local|s3}.
 */
public interface StorageService {

	/** Validiert und speichert die Datei, liefert den generierten Dateinamen. */
	String store(MultipartFile file);

	/** Lädt die Datei; {@code exists()} der Resource ist false, wenn sie nicht vorhanden ist. */
	Resource load(String filename);

	/** Content-Type anhand der Dateiendung. */
	default MediaType contentTypeOf(String filename) {
		return StorageRules.contentTypeOf(filename);
	}
}
