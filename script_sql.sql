-- =========================================================================
-- PROYECTO: Calidad de Datos y Dashboard de Riesgo Financiero
-- Dataset: Loan_default.csv (Kaggle) - 255,347 filas x 18 columnas
-- =========================================================================

-- =========================================================================
-- STEP 2.1: CREACIÓN DE LA BASE DE DATOS Y ARQUITECTURA STAGE / DW
-- =========================================================================
CREATE DATABASE DW_Riesgo_Financiero;
GO
USE DW_Riesgo_Financiero;
GO

-- Tabla Staging Espejo (18 columnas alineadas al esquema real de Kaggle)
CREATE TABLE STG_Loan_Default (
    LoanID VARCHAR(100),
    Age VARCHAR(50),
    Income VARCHAR(100),
    LoanAmount VARCHAR(100),
    CreditScore VARCHAR(50),
    MonthsInJob VARCHAR(50),
    NumCreditLines VARCHAR(50),
    InterestRate VARCHAR(50),
    LoanTerm VARCHAR(50),
    DTIRatio VARCHAR(50),
    Education VARCHAR(100),
    EmploymentType VARCHAR(100),
    MaritalStatus VARCHAR(100),
    HasMortgage VARCHAR(50),
    HasDependents VARCHAR(50),
    LoanPurpose VARCHAR(100),
    HasCoSigner VARCHAR(50),
    DefaultStatus VARCHAR(100)
);

-- Tabla de Destino: Dimensión Clientes
CREATE TABLE Dim_Clientes_Financieros (
    ClienteID VARCHAR(50) PRIMARY KEY,
    Edad INT,
    IngresoAnual DECIMAL(12,2),
    ScoreCrediticio INT,
    MesesEmpleado INT,
    Educacion VARCHAR(50),
    TipoEmpleo VARCHAR(50),
    EstadoCivil VARCHAR(50),
    TieneHipoteca BIT,
    TieneDependientes BIT
);

-- Tabla de Destino: Hechos Préstamos
CREATE TABLE Fact_Prestamos (
    LoanID VARCHAR(50) PRIMARY KEY,
    ClienteID VARCHAR(50),
    MontoPrestamo DECIMAL(12,2),
    TasaInteres DECIMAL(5,2),
    PlazoMeses INT,
    RatioDTI DECIMAL(5,2),
    PropisitoPrestamo VARCHAR(50),
    TieneCodeudor BIT,
    EstadoImpago BIT
);

-- Tabla de Control de Calidad (Data Quality Log)
CREATE TABLE QA_Rechazos_Financieros (
    RechazoID INT IDENTITY(1,1) PRIMARY KEY,
    LoanID VARCHAR(100),
    ValorInvalido VARCHAR(250),
    FechaAuditoria DATETIME DEFAULT GETDATE(),
    ReglaCalidad VARCHAR(100),
    UsuarioSteward VARCHAR(50) DEFAULT 'Erick_Otoya'
);
GO

-- =========================================================================
-- STEP 2.2: INGESTA MASIVA DE ALTO RENDIMIENTO (BULK INSERT)
-- =========================================================================
BULK INSERT STG_Loan_Default
FROM 'C:\KaggleData\Loan_default_Limpio.csv'
WITH (
    FIRSTROW = 2,            -- Omitir cabecera
    FIELDTERMINATOR = '|',   -- Separador por tuberías generado por Python
    ROWTERMINATOR = '0x0a',  -- Salto de línea estricto
    TABLOCK
);
GO

-- =========================================================================
-- STEP 2.3: MOTOR DE REGLAS DE CALIDAD DE DATOS (DAMA-DMBOK2)
-- =========================================================================
-- DQ_01: Completitud de identificadores de negocio
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT ISNULL(LoanID, 'NULO'), 'ID en blanco o nulo', 'DQ_01_COMPLETITUD_ID_REQUERIDO'
FROM STG_Loan_Default WHERE LoanID IS NULL OR TRIM(LoanID) = '';

-- DQ_02: Validez de rangos de edad para políticas bancarias (18 a 75 años)
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT LoanID, 'Edad registrada: ' + Age, 'DQ_02_VALIDEZ_RANGO_EDAD'
FROM STG_Loan_Default
WHERE TRY_CAST(Age AS INT) IS NULL OR CAST(Age AS INT) < 18 OR CAST(Age AS INT) > 75;

-- DQ_03: Consistencia de Scores Crediticios bajo estándar internacional (300-850)
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT LoanID, 'Score registrado: ' + CreditScore, 'DQ_03_CONSISTENCIA_SCORE_CREDIT_MERCADO'
FROM STG_Loan_Default
WHERE TRY_CAST(CreditScore AS INT) IS NULL OR CAST(CreditScore AS INT) < 300 OR CAST(CreditScore AS INT) > 850;
GO

-- =========================================================================
-- STEP 2.4: TRANSFORMACIÓN Y CARGA COMPLETA AL DATA WAREHOUSE
-- =========================================================================
-- Carga de Dim_Clientes_Financieros
INSERT INTO Dim_Clientes_Financieros (
    ClienteID, Edad, IngresoAnual, ScoreCrediticio, MesesEmpleado,
    Educacion, TipoEmpleo, EstadoCivil, TieneHipoteca, TieneDependientes
)
SELECT
    LoanID AS ClienteID,
    ISNULL(TRY_CAST(Age AS INT), 0),
    ISNULL(TRY_CAST(Income AS DECIMAL(12,2)), 0.00),
    ISNULL(TRY_CAST(CreditScore AS INT), 0),
    ISNULL(TRY_CAST(TRY_CAST(MonthsInJob AS DECIMAL(10,2)) AS INT), 0),
    TRIM(Education), TRIM(EmploymentType), TRIM(MaritalStatus),
    CASE WHEN UPPER(TRIM(HasMortgage)) = 'YES' THEN 1 ELSE 0 END,
    CASE WHEN UPPER(TRIM(HasDependents)) = 'YES' THEN 1 ELSE 0 END
FROM STG_Loan_Default;

-- Carga de Fact_Prestamos
INSERT INTO Fact_Prestamos (
    LoanID, ClienteID, MontoPrestamo, TasaInteres, PlazoMeses,
    RatioDTI, PropisitoPrestamo, TieneCodeudor, EstadoImpago
)
SELECT
    LoanID, LoanID AS ClienteID,
    ISNULL(TRY_CAST(LoanAmount AS DECIMAL(12,2)), 0.00),
    ISNULL(TRY_CAST(InterestRate AS DECIMAL(5,2)), 0.00),
    ISNULL(TRY_CAST(TRY_CAST(LoanTerm AS DECIMAL(10,2)) AS INT), 0),
    ISNULL(TRY_CAST(DTIRatio AS DECIMAL(5,2)), 0.00),
    TRIM(LoanPurpose),
    CASE WHEN UPPER(TRIM(HasCoSigner)) = 'YES' THEN 1 ELSE 0 END,
    CASE WHEN TRIM(DefaultStatus) = '1' OR TRIM(DefaultStatus) LIKE '1%' THEN 1 ELSE 0 END
FROM STG_Loan_Default;

-- Restricción física FK para asegurar la integridad referencial en el DWH
ALTER TABLE Fact_Prestamos
ADD CONSTRAINT FK_Prestamos_Clientes FOREIGN KEY (ClienteID) REFERENCES Dim_Clientes_Financieros(ClienteID);
GO

-- =========================================================================
-- STEP 2.5: VALIDACIÓN FINAL
-- =========================================================================
SELECT 'STG' AS Tabla, COUNT(*) AS Filas FROM STG_Loan_Default
UNION ALL SELECT 'Dim', COUNT(*) FROM Dim_Clientes_Financieros
UNION ALL SELECT 'Fact', COUNT(*) FROM Fact_Prestamos
UNION ALL SELECT 'QA_Rechazos', COUNT(*) FROM QA_Rechazos_Financieros;
-- Esperado: 255347 / 255347 / 255347 / 0

SELECT COUNT(*) AS Impagos, SUM(MontoPrestamo) AS MontoEnRiesgo
FROM Fact_Prestamos WHERE EstadoImpago = 1;
-- Esperado: 29653 / 4285312531.00

SELECT COUNT(*) AS Dim_con_ceros FROM Dim_Clientes_Financieros
WHERE Edad = 0 OR ScoreCrediticio = 0 OR IngresoAnual = 0;
-- Esperado: 0

SELECT name FROM sys.foreign_keys;
-- FK_Prestamos_Clientes