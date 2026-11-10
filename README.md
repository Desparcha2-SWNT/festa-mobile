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
flutter run                                                   # emulador Android → http://10.0.2.2:8000
flutter run --dart-define=API_BASE_URL=http://localhost:8000  # simulador iOS o web
```

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
