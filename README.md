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
- Los eventos cercanos (`nearbyEventsProvider`, radio de 3 km) se dibujan como círculos del color de su categoría en
  una fuente GeoJSON, para que SCRUM-77 pueda agruparlos en clústeres en la misma fuente. Al tocar uno aparece su
  tarjeta, y desde ella se abre `EventDetailScreen` (`/events/:id`, que lee `GET /api/events/:id`).
- Clústeres (SCRUM-77): la fuente agrupa los eventos que quedan a menos de 50 px entre sí hasta el zoom 14. El círculo
  magenta muestra cuántos eventos agrupa, y al tocarlo el mapa se acerca justo hasta donde se separan. El mapa abre en
  zoom 13 (barrio, con clústeres) y al elegir un evento se acerca a 15, para que no quede dentro de un clúster.
- **Pendiente de SCRUM-74:** `EventsApi.nearby` usa el contrato propuesto
  `GET /api/events/nearby?lat=&lng=&radiusKm=` → `{"items": [Evento]}`. Hasta que event-service lo publique, el mapa
  muestra el aviso «No pudimos cargar los eventos».

## Comercio (RF3)

- Una cuenta registrada como «Comercio» no entra a la app hasta que el equipo Festa verifica su perfil. El router la
  lleva al formulario si aún no lo envió (`MerchantFormScreen`, pasos 2 y 3 del registro en el Figma) y después a
  `MerchantStatusScreen`: «Estamos revisando tu perfil» o, si lo rechazaron, el motivo y «Corregir y reenviar».
- El perfil se guarda en user-service (`/api/users/me/merchant`): `POST` la primera vez y `PATCH` para corregirlo, que
  lo devuelve a pendiente. Ya verificado, el comercio ve las pestañas Mapa y «Mi comercio».
- La ubicación se elige tocando un mapa pequeño (`LocationPickerField`), así que se guardan las coordenadas exactas sin
  geocodificar la dirección escrita.
- El teléfono y el NIT del Figma están marcados como «Propuesta»: user-service todavía no los recibe.

## Eventos del organizador (RF4)

- Un comercio verificado entra a «Mis eventos» (`MyEventsScreen`, `GET /api/events/mine`), con las pestañas Publicados
  y Cancelados. Los borradores del Figma aún no existen en event-service.
- «Crear evento» (`CreateEventScreen`): datos y vista previa antes de publicar (`POST /api/events`, como el comercio).
  El lugar arranca en el del comercio. El paso de descripción con IA del Figma llega con SCRUM-101.
- Editar (`EditEventScreen`, SCRUM-67): desde «Mis eventos», un evento publicado y vigente abre la edición. Solo se
  envían los campos que cambiaron (`PATCH /api/events/:id`) y después se vuelven a pedir la lista, el detalle y el mapa.
  «Cancelar evento» pide el motivo, que les llega a quienes confirmaron (`POST /api/events/:id/cancel`).
- `EventForm` tiene los campos y sus validaciones, y lo usan crear y editar. El evento empieza y termina el mismo día.
- La app está en español (`flutter_localizations`), así que el calendario y el reloj salen en español.
