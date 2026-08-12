package com.foodaicamera.plugin;

import android.Manifest;
import android.app.Activity;
import android.content.ContentResolver;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Environment;
import android.provider.MediaStore;
import android.webkit.MimeTypeMap;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public class FoodPhotoPickerPlugin extends GodotPlugin {
    private static final int REQ_CAMERA_PERMISSION = 4101;
    private static final int REQ_TAKE_PHOTO = 4102;
    private static final int REQ_PICK_PHOTO = 4103;

    @Nullable
    private String pendingCameraPath;

    public FoodPhotoPickerPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "FoodPhotoPicker";
    }

    @NonNull
    @Override
    public List<String> getPluginMethods() {
        return Arrays.asList("takePhoto", "pickPhoto");
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("photo_selected", String.class, String.class));
        signals.add(new SignalInfo("photo_cancelled", String.class));
        signals.add(new SignalInfo("photo_failed", String.class, String.class));
        return signals;
    }

    @UsedByGodot
    public void takePhoto() {
        Activity activity = getActivity();
        if (activity == null) {
            emitSignal("photo_failed", "camera", "Android Activity를 찾을 수 없습니다.");
            return;
        }

        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(activity, new String[]{Manifest.permission.CAMERA}, REQ_CAMERA_PERMISSION);
            return;
        }

        launchCamera(activity);
    }

    @UsedByGodot
    public void pickPhoto() {
        Activity activity = getActivity();
        if (activity == null) {
            emitSignal("photo_failed", "gallery", "Android Activity를 찾을 수 없습니다.");
            return;
        }

        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("image/*");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        activity.startActivityForResult(intent, REQ_PICK_PHOTO);
    }

    private void launchCamera(Activity activity) {
        try {
            Intent intent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
            if (intent.resolveActivity(activity.getPackageManager()) == null) {
                emitSignal("photo_failed", "camera", "카메라 앱을 찾을 수 없습니다.");
                return;
            }

            File imageFile = createCameraImageFile(activity);
            pendingCameraPath = imageFile.getAbsolutePath();
            Uri photoUri = FileProvider.getUriForFile(
                    activity,
                    activity.getPackageName() + ".fileprovider",
                    imageFile
            );

            intent.putExtra(MediaStore.EXTRA_OUTPUT, photoUri);
            intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            activity.startActivityForResult(intent, REQ_TAKE_PHOTO);
        } catch (Exception ex) {
            pendingCameraPath = null;
            emitSignal("photo_failed", "camera", "카메라를 실행할 수 없습니다: " + ex.getMessage());
        }
    }

    private File createCameraImageFile(Activity activity) throws Exception {
        File parent = activity.getExternalFilesDir(Environment.DIRECTORY_PICTURES);
        if (parent == null) {
            parent = activity.getFilesDir();
        }

        File dir = new File(parent, "FoodAI");
        if (!dir.exists() && !dir.mkdirs()) {
            throw new IllegalStateException("사진 저장 폴더를 만들 수 없습니다.");
        }

        String stamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(System.currentTimeMillis());
        return new File(dir, "food_" + stamp + ".jpg");
    }

    @Override
    public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        super.onMainActivityResult(requestCode, resultCode, data);

        if (requestCode == REQ_TAKE_PHOTO) {
            if (resultCode == Activity.RESULT_OK && pendingCameraPath != null) {
                emitSignal("photo_selected", pendingCameraPath, "camera");
            } else {
                emitSignal("photo_cancelled", "camera");
            }
            pendingCameraPath = null;
            return;
        }

        if (requestCode == REQ_PICK_PHOTO) {
            if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
                emitSignal("photo_cancelled", "gallery");
                return;
            }

            try {
                Activity activity = getActivity();
                if (activity == null) {
                    emitSignal("photo_failed", "gallery", "Android Activity를 찾을 수 없습니다.");
                    return;
                }

                Uri uri = data.getData();
                int flags = data.getFlags() & Intent.FLAG_GRANT_READ_URI_PERMISSION;
                if (flags != 0) {
                    activity.getContentResolver().takePersistableUriPermission(uri, flags);
                }

                String copiedPath = copyUriToCache(activity, uri);
                emitSignal("photo_selected", copiedPath, "gallery");
            } catch (Exception ex) {
                emitSignal("photo_failed", "gallery", "갤러리 사진을 읽을 수 없습니다: " + ex.getMessage());
            }
        }
    }

    @Override
    public void onMainRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onMainRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQ_CAMERA_PERMISSION) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Activity activity = getActivity();
                if (activity != null) {
                    launchCamera(activity);
                } else {
                    emitSignal("photo_failed", "camera", "Android Activity를 찾을 수 없습니다.");
                }
            } else {
                emitSignal("photo_failed", "camera", "카메라 권한이 거부되었습니다.");
            }
        }
    }

    private String copyUriToCache(Activity activity, Uri uri) throws Exception {
        ContentResolver resolver = activity.getContentResolver();
        String extension = getExtension(resolver, uri);
        File dir = new File(activity.getCacheDir(), "food_photos");
        if (!dir.exists() && !dir.mkdirs()) {
            throw new IllegalStateException("캐시 폴더를 만들 수 없습니다.");
        }

        String stamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(System.currentTimeMillis());
        File output = new File(dir, "gallery_" + stamp + extension);

        try (InputStream input = resolver.openInputStream(uri);
             FileOutputStream out = new FileOutputStream(output)) {
            if (input == null) {
                throw new IllegalStateException("선택한 사진을 읽을 수 없습니다.");
            }
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
        }

        return output.getAbsolutePath();
    }

    private String getExtension(ContentResolver resolver, Uri uri) {
        String mime = resolver.getType(uri);
        if (mime != null) {
            String ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime);
            if (ext != null && !ext.isEmpty()) {
                return "." + ext;
            }
        }

        String name = queryDisplayName(resolver, uri);
        if (name != null && name.contains(".")) {
            return name.substring(name.lastIndexOf("."));
        }
        return ".jpg";
    }

    @Nullable
    private String queryDisplayName(ContentResolver resolver, Uri uri) {
        try (Cursor cursor = resolver.query(uri, null, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int index = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME);
                if (index >= 0) {
                    return cursor.getString(index);
                }
            }
        } catch (Exception ignored) {
        }
        return null;
    }
}
