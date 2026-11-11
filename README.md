# festa-mobile

App de Festa para iOS y Android (Flutter): la de los usuarios y el panel simple para comercios (RF15).

## Correr

Primero levanta el backend desde `festa-infra` (ver su README):

```bash
docker compose --profile auth --profile gateway up -d --build
```

Luego corre la app:

```bash
flutter pub get
cp config/dev.example.json config/dev.json                    # pon tu token público de Mapbox (pk.…)
flutter run --dart-define-from-file=config/dev.json           # emulador Android → http://10.0.2.2:8000
flutter run --dart-define-from-file=config/dev.json --dart-define=API_BASE_URL=http://localhost:8000  # simulador iOS
```

`config/dev.json` está en `.gitignore`: el token nunca se sube. El token se crea en la cuenta de Mapbox
(Tokens → público, solo con los scopes por defecto); en el CD sale del secreto `MAPBOX_ACCESS_TOKEN`.

`API_BASE_URL` es la URL del gateway. En producción debe ser `https://`: el tráfico HTTP sin cifrar solo está permitido en los builds de debug de Android.

## Calidad

```bash
flutter analyze   # lints estrictos (analysis_options.yaml)
dart format .     # ancho de línea 120
flutter test
```

## Estructura

Se organiza por funcionalidad. Cada una tiene cuatro capas:

```
lib/
  app/            # MaterialApp, router (go_router), rutas y tema
  core/           # Piezas compartidas por todas las funcionalidades
    config/       # Configuración por entorno (--dart-define)
    network/      # Clientes Dio, interceptor JWT y ApiException
  features/
    auth/
      domain/        # Modelos (Account, AuthSession)
      data/          # Llamadas a la API, almacenamiento seguro y repositorio
      application/   # Estado con Riverpod (SessionController)
      presentation/  # Pantallas, widgets y validaciones
    home/
```

- **Estado e inyección de dependencias:** Riverpod. En los tests se sobreescriben los providers (`authApiProvider`, `tokenStorageProvider`), sin mocks globales.
- **Errores de la API:** todos se convierten en `ApiException`, que trae un `message` listo para mostrar y `fieldErrors` para los `VALIDATION_ERROR`.
- **Llamadas con JWT:** usa `authenticatedDioProvider`. Este cliente agrega el token y, si recibe un 401, renueva la sesión una vez y repite la petición.

## Sesión (RF1)

- El **access token** (15 min) vive solo en memoria.
- El **refresh token** (30 días) se guarda en Keychain/Keystore con `flutter_secure_storage`.
- Al abrir la app se renueva la sesión con el refresh token, así que no hay que iniciar sesión cada vez.
- El refresh **rota** en cada uso. Por eso las renovaciones simultáneas comparten una sola petición: si se usara dos veces, el servidor revocaría la sesión.
- El logout borra la sesión del dispositivo aunque el servidor no responda.

## Ubicación (RNF5, Ley 1581)

- Después de iniciar sesión, la app pide el **consentimiento en la propia app** (`LocationConsentScreen`) antes de tocar la ubicación. El diálogo de permiso del sistema solo aparece si el usuario elige «Permitir ubicación».
- La decisión se guarda por cuenta en el dispositivo y se registra en user-service (`POST /api/users/me/consents`). Si no hay conexión, se respeta igual y se vuelve a enviar al abrir la app.
- `userLocationProvider` entrega la ubicación real del dispositivo. Si el usuario dijo «Ahora no», el sistema negó el permiso, el GPS está apagado o no hay señal, usa la ubicación del piloto (la Escuela) y dice el motivo, para que la UI lo informe (`LocationFallbackBanner`).

## Mapa (RF5)

- `MapScreen` es la pestaña «Mapa» de la barra inferior (`AppShell`). Se centra en `userLocationProvider` y solo
  muestra el punto del usuario cuando hay consentimiento y permiso; si no, se centra en la Escuela con el aviso.
- Solo `MapboxMapView` conoce el SDK de Mapbox. Las pantallas mueven la cámara con `MapCameraController`, y las pruebas
  cambian la vista con `mapViewBuilderProvider`, porque el mapa nativo no se dibuja en `flutter test`.
