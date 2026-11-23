package ch.bbw.trips.storage;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.Resource;
import org.springframework.core.io.FileSystemResource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;

/** Speichert Fotos im lokalen Dateisystem (Standard für lokale Entwicklung und Docker Compose). */
@Service
@ConditionalOnProperty(name = "app.storage.type", havingValue = "local", matchIfMissing = true)
public class LocalStorageService implements StorageService {

	private final Path root;

	public LocalStorageService(@Value("${app.storage.location:./uploads}") String location) {
		this.root = Paths.get(location).toAbsolutePath().normalize();
		try {
			Files.createDirectories(root);
		} catch (IOException e) {
			throw new UncheckedIOException("Upload-Verzeichnis nicht anlegbar: " + root, e);
		}
	}

	@Override
	public String store(MultipartFile file) {
		String filename = StorageRules.newFilename(file);
		try {
			Files.copy(file.getInputStream(), root.resolve(filename), StandardCopyOption.REPLACE_EXISTING);
		} catch (IOException e) {
			throw new StorageException("Datei konnte nicht gespeichert werden", e);
		}
		return filename;
	}

	@Override
	public Resource load(String filename) {
		Path file = root.resolve(StorageRules.requireSafeName(filename)).normalize();
		return new FileSystemResource(file);
	}
}
