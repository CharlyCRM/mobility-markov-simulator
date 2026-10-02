# Una flota en movimiento

¿Cómo se reparte una flota de bicicletas cuando cada viaje puede terminar en una estación distinta? ¿Y qué cambia si algunas se averían o vuelven al servicio después de repararse?

Este simulador nació de un trabajo de álgebra lineal de la UOC. Lo convertí en una aplicación con R y Shiny para experimentar con esas preguntas: modificar probabilidades, observar la flota y comparar escenarios de movilidad y mantenimiento.

[Abrir la aplicación](https://mobility-markov-simulator-production.up.railway.app) · [Ver el proyecto en mi portfolio](https://carlos-ramirez-martin.up.railway.app/es/projects/mobility-markov-simulator/)

## Qué puedes probar

La flota se mueve entre tres estaciones, A, B y C. Puedes cambiar su distribución inicial y la probabilidad de ir de una estación a otra. Después, compara lo que ocurre sin averías, con averías que retiran bicicletas del servicio o con un taller que las repara y devuelve a una estación.

Puedes animar los pasos, comparar el cálculo matemático con una simulación Monte Carlo y consultar la distribución estacionaria, los viajes esperados hasta una avería y la disponibilidad. También puedes asignar costes por viaje, avería y reparación, y descargar matrices y resultados en JSON.

Cada fila de la matriz debe sumar uno y contener probabilidades entre 0 y 1. Si no se cumple, la aplicación avisa en lugar de corregirlas sin explicarlo. La flota inicial admite cantidades enteras no negativas hasta un total de 300.000 bicicletas.

La interfaz está en español e inglés. La demo se suspende cuando no se utiliza y puede tardar en arrancar al volver a abrirla.

## El modelo detrás de la aplicación

Uso una cadena de Markov: cada fila de `P` describe desde qué estación sale una bicicleta y dónde puede acabar. Si `n` es el vector fila de la flota actual, `nP` da su distribución esperada en el siguiente paso.

Para representar averías añado el estado `T`. Una bicicleta activa entra en él con probabilidad `f`; el resto de sus probabilidades se multiplica por `1-f`. Con mantenimiento, una bicicleta en `T` vuelve a la estación elegida con probabilidad `r`.

Un paso representa una oportunidad de transición, no una hora. Las bicicletas activas hacen un viaje; las del taller esperan o salen reparadas. Los costes cuentan esos eventos a lo largo del horizonte seleccionado.

Con una probabilidad de avería de `0,05`, el escenario sin reparación da 20 viajes esperados hasta la avería desde cualquiera de las estaciones. Con reparación de `0,25`, la disponibilidad estacionaria es `r / (r + f)`, aproximadamente un 83,33 %. Son consecuencias de los supuestos, no mediciones de una flota real.

## Qué conviene tener en cuenta

Las probabilidades son constantes. No contemplo capacidad de estaciones, vehículos de redistribución, demanda variable, compra de bicicletas ni ingresos. Los costes permiten comparar esos escenarios, no recomendar una política económica real.

La simulación conserva exactamente el número entero de bicicletas; el cálculo analítico puede dar cantidades fraccionarias porque son valores esperados. Una simulación con semilla fija es reproducible, pero no es un intervalo de confianza.

Una distribución estacionaria tampoco garantiza que todas las trayectorias converjan: las cadenas periódicas pueden oscilar. Cuando no hay una distribución estacionaria única, la aplicación lo indica.

[reports/evaluation.json](reports/evaluation.json) recoge el escenario de referencia: 1.500 bicicletas, 40 pasos, probabilidades de avería y reparación de 0,05 y 0,25, y retorno a A.

## Ejecutarlo en local

El proyecto se preparó con R 4.4.2. Desde la carpeta del repositorio:

```sh
Rscript setup.R
Rscript tests/run.R
Rscript run.R
```

Abre http://127.0.0.1:8505/; añade `/?lang=en` para entrar en inglés. El servidor solo escucha en tu equipo. `setup.R` instala los paquetes necesarios. Para restaurar las versiones registradas, instala `renv` y ejecuta:

```r
renv::restore(lockfile = "renv.lock", library = ".library", prompt = FALSE)
```

Las pruebas comprueban las matrices, la conservación de la flota, la simulación reproducible, los viajes hasta la avería, los casos límite de reparación y los costes. Para recalcular el informe, ejecuta `Rscript scripts/evaluate.R`.

## Origen del trabajo y licencia

El punto de partida fue mi PEC5 de álgebra lineal. El código se reconstruyó por separado y no distribuye enunciados ni materiales docentes. El original se conserva sin modificar y su SHA-256 figura en `provenance/source-manifest.json`.

Si tienes acceso a mis originales, puedes comprobar su integridad con `Rscript scripts/verify-originals.R /ruta/a/UOC`. La copia de archivo queda fuera de Git; dependencias y resultados se guardan aquí, no en la carpeta académica.

El código propio tiene licencia MIT. La aplicación no admite subidas de archivos ni recoge datos personales. `PORTFOLIO_URL` cambia el enlace de regreso al portfolio; por defecto usa `http://localhost:4322`.

Carlos Ramírez Martín
