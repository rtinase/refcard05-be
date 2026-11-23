package ch.bbw.trips.storage;

/** Der Storage ist nicht erreichbar oder der Zugriff wurde verweigert (z. B. fehlende S3-Rechte). */
public class StorageException extends RuntimeException {

	public StorageException(String message, Throwable cause) {
		super(message, cause);
	}
}
