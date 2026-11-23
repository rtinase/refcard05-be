package ch.bbw.trips.storage;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.core.io.Resource;
import org.springframework.mock.web.MockMultipartFile;
import software.amazon.awssdk.awscore.exception.AwsServiceException;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

import java.io.IOException;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class S3StorageServiceTest {

	private static final String BUCKET = "test-bucket";
	private static final String KEY = "11111111-2222-3333-4444-555555555555.png";

	private S3Client s3;
	private S3StorageService service;

	@BeforeEach
	void setUp() {
		s3 = mock(S3Client.class);
		service = new S3StorageService(s3, new S3Properties(BUCKET, "us-east-1"));
	}

	@Test
	void storesObjectInConfiguredBucketUnderRandomKey() {
		String key = service.store(new MockMultipartFile("file", "../x.png", "image/png", new byte[]{1, 2, 3}));

		ArgumentCaptor<PutObjectRequest> request = ArgumentCaptor.forClass(PutObjectRequest.class);
		verify(s3).putObject(request.capture(), any(RequestBody.class));
		assertEquals(BUCKET, request.getValue().bucket());
		assertEquals(key, request.getValue().key());
		assertEquals("image/png", request.getValue().contentType());
		assertTrue(key.endsWith(".png"));
		assertFalse(key.contains("x.png"));
	}

	@Test
	void loadsExistingObject() {
		ResponseBytes<GetObjectResponse> bytes = ResponseBytes.fromByteArray(GetObjectResponse.builder().build(), new byte[]{9, 8});
		when(s3.getObjectAsBytes(any(GetObjectRequest.class))).thenReturn(bytes);

		Resource r = service.load(KEY);

		assertTrue(r.exists());
		assertDoesNotThrow(() -> assertArrayEquals(new byte[]{9, 8}, r.getContentAsByteArray()));
	}

	@Test
	void missingObjectIsReportedAsNotExisting() {
		when(s3.getObjectAsBytes(any(GetObjectRequest.class))).thenThrow(NoSuchKeyException.builder().build());

		assertFalse(service.load(KEY).exists());
	}

	@Test
	void missingPermissionsGiveClearStorageException() {
		AwsServiceException denied = S3Exception.builder().statusCode(403).message("Access Denied").build();
		doThrow(denied).when(s3).putObject(any(PutObjectRequest.class), any(RequestBody.class));

		StorageException ex = assertThrows(StorageException.class,
				() -> service.store(new MockMultipartFile("file", "a.png", "image/png", new byte[]{1})));

		assertTrue(ex.getMessage().contains("verweigert"));
	}

	@Test
	void otherS3ErrorsAreReportedAsUnreachable() {
		when(s3.getObjectAsBytes(any(GetObjectRequest.class)))
				.thenThrow(S3Exception.builder().statusCode(500).message("boom").build());

		StorageException ex = assertThrows(StorageException.class, () -> service.load(KEY));

		assertTrue(ex.getMessage().contains("nicht erreichbar"));
	}

	@Test
	void rejectsKeysThatAreNotGeneratedNames() {
		assertThrows(IllegalArgumentException.class, () -> service.load("../../other-bucket-object"));
		verifyNoInteractions(s3);
	}

	@Test
	void rejectsUnsupportedContentTypeBeforeCallingS3() throws IOException {
		assertThrows(IllegalArgumentException.class,
				() -> service.store(new MockMultipartFile("file", "a.txt", "text/plain", new byte[]{1})));
		verifyNoInteractions(s3);
	}
}
