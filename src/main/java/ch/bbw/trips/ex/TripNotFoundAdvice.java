package ch.bbw.trips.ex;

import ch.bbw.trips.storage.StorageException;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.ResponseStatus;

@ControllerAdvice
public class TripNotFoundAdvice {

	@ResponseBody
	@ExceptionHandler(TriptNotFoundException.class)
	@ResponseStatus(HttpStatus.NOT_FOUND)
	String productNotFoundHandler(TriptNotFoundException ex) {
		return ex.getMessage();
	}

	@ResponseBody
	@ExceptionHandler(IllegalArgumentException.class)
	@ResponseStatus(HttpStatus.BAD_REQUEST)
	String badRequestHandler(IllegalArgumentException ex) {
		return ex.getMessage();
	}

	/** Storage nicht erreichbar oder Zugriff verweigert (z. B. fehlende S3-Rechte): 502 statt 500. */
	@ResponseBody
	@ExceptionHandler(StorageException.class)
	@ResponseStatus(HttpStatus.BAD_GATEWAY)
	String storageHandler(StorageException ex) {
		return ex.getMessage();
	}
}
