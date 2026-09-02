# Android dedicated-device provisioning

**Kiosk шугам энэ байрлуулалт дээр АСААГҮЙ** (`shared/device_lines.json` →
`provisioned: false`). Доорх нь тэр шугамыг асаасны дараа хэрэгтэй болох алхам.

Component нэрний хоёр тал өөр package-тай нь зөв: эхнийх нь `applicationId`
(`mn.gerege.eid` + flavor suffix), хоёр дахь нь класс өөрийн package
(`namespace` = `mn.gerege.nexus`). Богиносгосон `.GeregeDeviceAdminReceiver`
бичлэг энд ажиллахгүй — тэр нь applicationId-аас тайлагддаг.

Factory-reset kiosk төхөөрөмж дээр kiosk flavor суулгасны дараа:

```sh
adb shell dpm set-device-owner mn.gerege.eid.kiosk/mn.gerege.nexus.GeregeDeviceAdminReceiver
```

App нь device-owner эрхийг шалгаж өөрийн package-ийг Lock Task allowlist-д
оруулна. Production fleet дээр энэ үйлдлийг Android Enterprise zero-touch/QR
provisioning болон EMM managed configuration-аар хийнэ.
