package ch.bbw.trips.storage;

import org.springframework.http.MediaType;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Locale;
import java.util.UUID;
import java.util.regex.Pattern;

/** Regeln, die für jede Storage-Implementierung gleich gelten. */
final class StorageRules {

	private static final List<String> ALLOWED_TYPES = List.of("image/png", "image/jpeg", "image/webp");
	private static final Pattern SAFE_NAME = Pattern.compile("[0-9a-f-]{36}\\.(png|jpg|webp)");

	private StorageRules() {
	}

	/** Prüft die Datei und erzeugt einen Zufallsnamen. Die Endung stammt vom geprüften Content-Type. */
	static String newFilename(MultipartFile file) {
		if (file.isEmpty()) {
			throw new IllegalArgumentException("Datei ist leer");
		}
		if (!ALLOWED_TYPES.contains(file.getContentType())) {
			throw new IllegalArgumentException("Nicht unterstützter Dateityp: " + file.getContentType());
		}
		return UUID.randomUUID() + "." + extensionFor(file.getContentType());
	}

	/** Schützt vor Path Traversal bzw. fremden S3-Keys: nur selbst erzeugte Namen sind erlaubt. */
	static String requireSafeName(String filename) {
		if (filename == null || !SAFE_NAME.matcher(filename).matches()) {
			throw new IllegalArgumentException("Ungültiger Dateiname");
		}
		return filename;
	}

	static MediaType contentTypeOf(String filename) {
		String ext = StringUtils.getFilenameExtension(filename);
		if (ext == null) {
			return MediaType.APPLICATION_OCTET_STREAM;
		}
		return switch (ext.toLowerCase(Locale.ROOT)) {
			case "png" -> MediaType.IMAGE_PNG;
			case "jpg" -> MediaType.IMAGE_JPEG;
			case "webp" -> MediaType.parseMediaType("image/webp");
			default -> MediaType.APPLICATION_OCTET_STREAM;
		};
	}

	private static String extensionFor(String contentType) {
		return switch (contentType) {
			case "image/png" -> "png";
			case "image/webp" -> "webp";
			default -> "jpg";
		};
	}
}
