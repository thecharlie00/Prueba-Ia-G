# Modelo de negocio de Tablerama (7 de noviembre de 2026)

Versión editable y con gráfico: [documento en Claude](https://claude.ai/artifact/XiuNH1ppyG4x5LJGWxHees).
No es asesoramiento fiscal ni legal: consultar con un gestor antes de facturar.

## Resumen

Juego de **pago único a 9,99 € en Steam, para Windows y Linux**, todo offline en la 1.0 y
sin servidores. El único gasto obligatorio es el alta de Steam (100 $, que se recuperan al
pasar de 1.000 $ de ventas).

- Solo Steam el primer año; itch.io para la demo gratuita y versiones de prueba.
- Sin macOS (Apple cobra 99 $ al año por firmar) ni móvil. Linux da Steam Deck gratis.
- Online (fase 3) después, como actualización gratuita.
- Contenido extra sin coste: Steam Workshop (mazos importados de imágenes) y un pack de apoyo opcional.

## Tiendas

| Tienda | Alta | Comisión | Papel |
|---|---|---|---|
| Steam | 100 $, devueltos al pasar de 1.000 $ | 30 % hasta 10 M$ | Venta principal, deseados, Next Fest, Workshop |
| itch.io | Gratis | La que se elija (0–100 %) + 0,30 $ y 2,9 % del pago | Demo y versiones de prueba |
| Epic Games Store | 100 $ | 0 % el primer millón al año, luego 12 % | Segundo año, si compensa; pide juego cruzado con el online |
| Microsoft Store | Gratis (particulares) | 12 % en juegos | Opcional |

## Productos

| Producto | Precio | Qué lleva |
|---|---|---|
| Tablerama | 9,99 € (12,99 € tras el primer año) | Todas las mesas, reglas y bots |
| Demo | Gratis | Mesa libre y dos juegos, sin guardar mesas |
| Pack de apoyo | 3,99 € | Banda sonora, fondos, tapetes y dorsos extra (sin ventaja de juego) |
| Workshop | Gratis | Mazos y mesas de la comunidad |

Lanzamiento con 10–15 % de descuento, precios regionales activados, rebajas de temporada al
20–40 %. Sin anuncios, microtransacciones ni suscripción. El «pack de 4» vuelve con el online.

## Gastos

| Gasto | Cuánto | Obligatorio |
|---|---|---|
| Alta en Steam | 100 $ (recuperables) | Sí |
| Autónomo, tarifa plana | 80 €/mes 12 meses | Cuando la venta sea habitual (gestor) |
| Marca OEPM, una clase | 125,36 € | Recomendado antes de anunciar |
| Identidad fiscal itch.io | 3 $ | Solo si se cobra allí |

No se paga: macOS, certificado de firma de Windows, servidores, publicidad, distribuidora,
motor (Godot) ni CI (GitHub Actions).

## Cuentas (estimación)

Unos **3,78 € por copia**: 9,99 € × 65 % de precio medio (rebajas y regiones) → sin IVA (~19 %)
→ −5 % devoluciones → −30 % Steam = 3,63 €, más 0,15 € del pack de apoyo (1 de cada 10).

| Copias el primer año | Ingreso neto | Gastos (peor caso) | Beneficio antes de IRPF |
|---|---|---|---|
| 1.000 | 3.780 € | 1.180 € | 2.600 € |
| 5.000 | 18.900 € | 1.180 € | 17.720 € |
| 20.000 | 75.600 € | 1.180 € | 74.420 € |

Regla aproximada: 5.000 copias el primer año piden unas 10.000 listas de deseados.

## Calendario

| Fecha | Hito |
|---|---|
| nov 2026 – feb 2027 | Contenido offline (brisca, parchís, mazos propios, manos ordenables) |
| 16 nov – 15 dic 2026 | Marca en la OEPM y página de Steam («Próximamente») |
| 15 ene 2027 | Demo en itch.io |
| 1 feb – 15 mar 2027 | Prueba con 3 personas (docs/PRUEBAS.md), Windows y Steam Deck reales |
| 25 abr 2027 | Cierre de inscripción del Next Fest de junio |
| 14 – 21 jun 2027 | Next Fest con la demo |
| 6 jul 2027 | Lanzamiento 1.0 |

## Impuestos (España)

- Persona física, sin SL al principio.
- Formulario fiscal de Steam con NIF: el convenio España–EE. UU. evita la retención del 30 %.
- Steam cobra y declara el IVA de cada país.
- Tarifa plana de autónomo 80 €/mes, ampliable 12 meses más si no se llega al SMI.
- Gastos del juego deducibles en el IRPF.

## Fuentes

- https://presskit.gg/field-guides/how-much-does-steam-take
- https://store.epicgames.com/distribution/revenue-programs/revenue-share
- https://www.pcgamer.com/epic-games-store-self-publishing/
- https://itch.io/docs/creators/payments
- https://presskit.gg/field-guides/steam-next-fest-guide
- https://www.oie.es/cuotas-de-autonomos/
- https://www.cohenyaguirre.es/cuanto-cuesta-registrar-una-marca-comercial-tasas/
- https://www.trolley.com/learning-center/understanding-us-spain-tax-treaty
