# Calidad de datos y dashboard de riesgo financiero

Proyecto de portafolio que lleva un dataset real de préstamos de Kaggle desde el CSV original hasta un dashboard en Power BI, pasando por limpieza en Python y un Data Warehouse en SQL Server con reglas de calidad de datos.

**Resultado:** 255,347 préstamos cargados sin pérdida de filas, una tasa de morosidad de **11.61 %** y **4,285 millones** en monto de préstamos en impago.

![Dashboard de riesgo financiero](docs/capturas/06_powerbi_dashboard.png)

## Datos

- **Fuente:** dataset *Loan Default* de Kaggle (`Loan_default.csv`). [Enlace al dataset: completar]
- **Tamaño:** 255,347 filas y 18 columnas.
- El CSV no está en este repositorio por su tamaño y porque no es de mi autoría. Se descarga desde Kaggle.

## Flujo del proyecto

```
Loan_default.csv ──► Python (pandas) ──► SQL Server ──► Power BI
                     limpieza y          staging, DW      medidas DAX
                     separador |         y reglas DQ      y dashboard
```

### 1. Python: limpieza del archivo
`limpiar_data.py` lee el CSV original con pandas y lo guarda con `|` como separador. Así se evita el desajuste de columnas (*schema mismatch*) al cargarlo en SQL Server.

![Ejecución del script de Python](docs/capturas/01_python_limpieza.png)

### 2. SQL Server: staging, Data Warehouse y calidad de datos
`script_sql.sql` crea la base `DW_Riesgo_Financiero` con cuatro tablas:

| Tabla | Rol | Filas |
|---|---|---|
| `STG_Loan_Default` | Staging, espejo del CSV (18 columnas) | 255,347 |
| `Dim_Clientes_Financieros` | Dimensión de clientes | 255,347 |
| `Fact_Prestamos` | Hechos de préstamos | 255,347 |
| `QA_Rechazos_Financieros` | Registro de registros rechazados | 0 |

Pasos del script:

1. Carga masiva del CSV con `BULK INSERT`.
2. Tres reglas de calidad de datos, con los rechazos registrados en `QA_Rechazos_Financieros`:
   - `DQ_01`: completitud del identificador del préstamo.
   - `DQ_02`: edad entre 18 y 75 años.
   - `DQ_03`: score crediticio entre 300 y 850.
3. Transformación con `TRY_CAST`, `TRIM` y conversión de Yes/No a bit, y carga a la dimensión y a la tabla de hechos.
4. Llave foránea `FK_Prestamos_Clientes` entre hechos y dimensión.

Todas las reglas dieron **0 rechazos**: los datos de este dataset cumplen los rangos definidos.

![Tablas del Data Warehouse](docs/capturas/02_ssms_objetos.png)
![Validación de conteos](docs/capturas/03_ssms_validacion_conteo.png)

### 3. Power BI: modelo y dashboard
`dashboard_riesgo_financiero.pbix` importa las tres tablas del DW. La relación es de varios a uno (`Fact_Prestamos[ClienteID]` hacia `Dim_Clientes_Financieros[ClienteID]`) con filtro cruzado único.

![Modelo de datos](docs/capturas/05_powerbi_modelo.png)

Medidas DAX:

```dax
Total_Creditos = COUNT(Fact_Prestamos[LoanID])

Monto_En_Riesgo =
CALCULATE(SUM(Fact_Prestamos[MontoPrestamo]), Fact_Prestamos[EstadoImpago] = TRUE)

Tasa_Morosidad_% =
DIVIDE(
    CALCULATE(COUNT(Fact_Prestamos[LoanID]), Fact_Prestamos[EstadoImpago] = TRUE),
    [Total_Creditos],
    0
)
```

El dashboard muestra tres tarjetas (total de créditos, monto en riesgo y tasa de morosidad) y un gráfico de columnas con la distribución de créditos por propósito y estado de impago.

## Cifras de control

| Indicador | Valor |
|---|---|
| Total de créditos | 255,347 |
| Créditos en impago | 29,653 |
| Tasa de morosidad | 11.61 % |
| Monto en riesgo | 4,285,312,531 |

Los números se verificaron entre el CSV original, SQL Server y Power BI.

## Cómo reproducirlo

1. Descargar `Loan_default.csv` desde Kaggle y colocarlo en `C:\KaggleData\`.
2. Ejecutar `python limpiar_data.py` para generar `Loan_default_Limpio.csv`.
3. Ejecutar `script_sql.sql` en SQL Server Management Studio.
4. Abrir `dashboard_riesgo_financiero.pbix` en Power BI Desktop y actualizar el origen de datos hacia tu servidor local.

## Herramientas

Python (pandas) · SQL Server y SSMS · T-SQL · Power BI y DAX · Git y GitHub

## Autor

**Erick Otoya**, Lima, Perú.
