# graphic-monitor

App de **barra de menú** para macOS que muestra mini-gráficos en tiempo real de CPU, GPU, RAM y red. Sin icono en el Dock: vive en la barra superior junto al reloj y los demás indicadores del sistema.

## Índice

- [Qué puedes hacer](#qué-puedes-hacer)
- [Métricas](#métricas)
- [Requisitos](#requisitos)
- [Build e instalación](#build-e-instalación)
- [Uso](#uso)
- [Atajos y menú](#atajos-y-menú)
- [Persistencia](#persistencia)
- [Estructura del proyecto](#estructura-del-proyecto)

## Qué puedes hacer

| Acción | Dónde | Resultado |
|--------|-------|-----------|
| Ver uso en vivo | Barra de menú | Cuatro sparklines (38×18 px): CPU, GPU, RAM y red |
| Consultar valor exacto | Hover sobre un mini-gráfico | Tooltip instantáneo con porcentaje o velocidad de red |
| Ampliar una métrica | Clic en un mini-gráfico | Panel flotante con gráfico grande y valor animado |
| Cambiar estilo del gráfico | Panel expandido (icono de línea/barras) | Alterna entre **línea** y **barras** por métrica |
| Cambiar de métrica en el panel | Swipe horizontal o flechas al hover | Navega CPU → GPU → RAM → Network (carrusel) |
| Mantener el panel visible | Botón de pin en el panel | El panel no se cierra al hacer clic fuera |
| Salir de la app | Clic derecho en la barra o ⌘Q | Menú **Quit** o cierre con atajo de teclado |

La app muestrea el sistema **cada segundo** y mantiene un historial de **30 muestras** (últimos 30 s) para dibujar las curvas.

## Métricas

| Métrica | Qué muestra | En la barra | En el panel |
|---------|-------------|-------------|-------------|
| **CPU** | Uso agregado del procesador | Sparkline verde + tooltip `%` | Gráfico ampliado + valor |
| **GPU** | Uso de la GPU (IOKit) | Sparkline naranja + tooltip `%` | Igual |
| **RAM** | Memoria en uso vs total | Sparkline azul + tooltip `%` | Igual |
| **Network** | Tráfico de red | Dos series: ↓ descarga (azul) y ↑ subida (naranja) | Velocidad en Mbps y unidades legibles |

Los valores se normalizan a `[0, 1]` para el dibujo; el formateo legible (porcentajes, MB/s, etc.) lo hace `SystemMonitor`.

## Requisitos

- macOS con Xcode (para compilar)
- Cuenta de desarrollador **no** necesaria para instalar localmente con el script de abajo
- Permisos estándar de usuario; lectura vía Mach e IOKit (sin agentes externos ni dependencias de terceros)

## Build e instalación

Compila la app en **Release**, la copia a `/Applications/graphic-monitor.app`, cierra una instancia previa si estaba abierta y la lanza.

```bash
./scripts/build-and-install.sh
```

Artefactos intermedios en `build/DerivedData/Build/Products/Release/graphic-monitor.app` (directorio `build/` ignorado por git).

Alternativa manual desde Xcode: abrir `graphic-monitor.xcodeproj`, esquema **graphic-monitor**, configuración **Release**, Product → Run o Archive.

## Uso

1. Tras instalar, aparecen **cuatro mini-gráficos** en la barra de menú.
2. **Pasa el cursor** sobre uno para ver el valor actual sin abrir nada.
3. **Haz clic** en un mini-gráfico para abrir el panel expandido anclado a ese gráfico.
4. En el panel:
   - Usa el icono de gráfico para cambiar entre línea y barras (se guarda por métrica).
   - Arrastra horizontalmente o usa las flechas (visibles al hover) para ver otra métrica.
   - Fija el panel con el pin si quieres dejarlo abierto mientras usas otras apps.
5. Clic fuera del panel lo cierra (salvo que esté fijado).

## Atajos y menú

| Entrada | Acción |
|---------|--------|
| Clic derecho en la zona de los gráficos | Menú contextual con **Quit** |
| ⌘Q (app activa) | Cerrar la aplicación |
| ⌘Q (panel visible, foco en otra app) | Cerrar la aplicación |

## Persistencia

Solo se guarda en `UserDefaults` el **estilo de gráfico** (línea o barras) **por métrica**. No hay historial ni preferencias de panel entre sesiones más allá de eso.

## Estructura del proyecto

```
graphic-monitor/
├── graphic_monitorApp.swift      # Arranque, app de barra de menú (sin Dock)
├── Services/
│   ├── SystemMonitor.swift       # Muestreo CPU/GPU/RAM/red (Mach, IOKit)
│   └── StatusBarController.swift # NSStatusItem y menú Quit
└── Views/                        # SwiftUI + paneles/tooltips AppKit
    ├── MenuBarMonitorView.swift  # Los cuatro mini-gráficos
    ├── MiniGraphView.swift
    ├── ExpandedGraphView.swift   # Panel flotante
    ├── GraphMetric.swift         # Dominio: colores, textos, historial
    └── GraphStyleStore.swift     # Estilos persistidos por métrica

scripts/
├── build-and-install.sh          # Build Release + instalar en /Applications
└── README.md                     # Este archivo
```

Stack: Swift, SwiftUI, AppKit (`NSPanel`, tooltips nativos). Sin dependencias externas.

---

**Nota:** Este proyecto es código abierto para uso local y aprendizaje. No está publicado en la Mac App Store.
