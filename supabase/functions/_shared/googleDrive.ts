export type DriveFileMetadata = {
  id: string;
  name: string;
  mimeType: string;
  parents?: string[];
  size?: string;
};

type UploadSessionParams = {
  filename: string;
  mimeType: string;
  parentFolderId: string;
  fileSizeBytes: number;
};

type UploadFileParams = UploadSessionParams & {
  bytes: Uint8Array;
};

export async function getGoogleAccessToken() {
  const clientId = Deno.env.get("GOOGLE_DRIVE_CLIENT_ID");
  const clientSecret = Deno.env.get("GOOGLE_DRIVE_CLIENT_SECRET");
  const refreshToken = Deno.env.get("GOOGLE_DRIVE_REFRESH_TOKEN");

  if (!clientId || !clientSecret || !refreshToken) {
    throw new Error("Missing Google Drive credentials.");
  }

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });

  if (!response.ok) {
    throw new Error("Failed to get Google access token.");
  }

  const data = await response.json();

  if (typeof data.access_token !== "string") {
    throw new Error("Google access token missing.");
  }

  return data.access_token;
}

export async function getDriveFileMetadata(fileId: string): Promise<DriveFileMetadata> {
  const accessToken = await getGoogleAccessToken();
  const params = new URLSearchParams({
    fields: "id,name,mimeType,parents,size",
  });

  const response = await fetch(
    `https://www.googleapis.com/drive/v3/files/${fileId}?${params.toString()}`,
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  );

  if (!response.ok) {
    throw new Error("Failed to get Google Drive file metadata.");
  }

  return await response.json();
}

export async function createDriveFolder(name: string, parentId: string): Promise<DriveFileMetadata> {
  const accessToken = await getGoogleAccessToken();

  const response = await fetch("https://www.googleapis.com/drive/v3/files", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      name,
      mimeType: "application/vnd.google-apps.folder",
      parents: [parentId],
    }),
  });

  if (!response.ok) {
    throw new Error("Failed to create Google Drive folder.");
  }

  return await response.json();
}

export async function findDriveFolderByName(name: string, parentId: string) {
  const accessToken = await getGoogleAccessToken();
  const q = [
    `'${escapeDriveQueryValue(parentId)}' in parents`,
    `name = '${escapeDriveQueryValue(name)}'`,
    "mimeType = 'application/vnd.google-apps.folder'",
    "trashed = false",
  ].join(" and ");
  const params = new URLSearchParams({
    q,
    fields: "files(id,name,mimeType,parents)",
    pageSize: "1",
  });

  const response = await fetch(
    `https://www.googleapis.com/drive/v3/files?${params.toString()}`,
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  );

  if (!response.ok) {
    throw new Error("Failed to find Google Drive folder.");
  }

  const data = await response.json();
  const folder = Array.isArray(data.files) ? data.files[0] : null;

  return folder as DriveFileMetadata | null;
}

export async function getOrCreateDriveFolder(name: string, parentId: string) {
  const existingFolder = await findDriveFolderByName(name, parentId);
  if (existingFolder) return existingFolder;

  return await createDriveFolder(name, parentId);
}

export async function createResumableUploadSession(params: UploadSessionParams) {
  const accessToken = await getGoogleAccessToken();

  const response = await fetch(
    "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json; charset=UTF-8",
        "X-Upload-Content-Type": params.mimeType,
        "X-Upload-Content-Length": String(params.fileSizeBytes),
      },
      body: JSON.stringify({
        name: params.filename,
        mimeType: params.mimeType,
        parents: [params.parentFolderId],
      }),
    },
  );

  if (!response.ok) {
    throw new Error("Failed to create Google Drive upload session.");
  }

  const uploadUrl = response.headers.get("Location");

  if (!uploadUrl) {
    throw new Error("Google upload session URL missing.");
  }

  return uploadUrl;
}

export async function uploadFileBytesToDrive(params: UploadFileParams): Promise<DriveFileMetadata> {
  const uploadUrl = await createResumableUploadSession(params);

  const response = await fetch(uploadUrl, {
    method: "PUT",
    headers: {
      "Content-Type": params.mimeType,
      "Content-Length": String(params.fileSizeBytes),
    },
    body: params.bytes,
  });

  if (!response.ok) {
    throw new Error("Failed to upload file bytes to Google Drive.");
  }

  const metadata = await response.json();

  if (typeof metadata.id !== "string") {
    throw new Error("Google Drive upload response missing file id.");
  }

  return metadata as DriveFileMetadata;
}

function escapeDriveQueryValue(value: string) {
  return value.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
}
