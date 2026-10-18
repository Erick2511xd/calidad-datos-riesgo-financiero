-- Calidad de datos y riesgo financiero
-- Base de datos, staging, dimension, hechos y control de calidad

CREATE DATABASE DW_Riesgo_Financiero;
GO
USE DW_Riesgo_Financiero;
GO

-- Staging: espejo del CSV (18 columnas)
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

-- Dimension de clientes
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

-- Hechos de prestamos
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

-- Registro de calidad de datos
CREATE TABLE QA_Rechazos_Financieros (
    RechazoID INT IDENTITY(1,1) PRIMARY KEY,
    LoanID VARCHAR(100),
    ValorInvalido VARCHAR(250),
    FechaAuditoria DATETIME DEFAULT GETDATE(),
    ReglaCalidad VARCHAR(100),
    UsuarioSteward VARCHAR(50) DEFAULT 'Erick_Otoya'
);
GO

-- Carga masiva desde el CSV generado por Python
BULK INSERT STG_Loan_Default
FROM 'C:\KaggleData\csv\Loan_default_Limpio.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO

-- Reglas de calidad de datos

-- DQ_01: completitud del identificador
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT ISNULL(LoanID, 'NULO'), 'ID en blanco o nulo', 'DQ_01_COMPLETITUD_ID_REQUERIDO'
FROM STG_Loan_Default
WHERE LoanID IS NULL OR TRIM(LoanID) = '';

-- DQ_02: edad entre 18 y 75 anios
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT LoanID, 'Edad registrada: ' + Age, 'DQ_02_VALIDEZ_RANGO_EDAD'
FROM STG_Loan_Default
WHERE TRY_CAST(Age AS INT) IS NULL OR CAST(Age AS INT) < 18 OR CAST(Age AS INT) > 75;

-- DQ_03: score crediticio entre 300 y 850
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT LoanID, 'Score registrado: ' + CreditScore, 'DQ_03_CONSISTENCIA_SCORE_CREDIT_MERCADO'
FROM STG_Loan_Default
WHERE TRY_CAST(CreditScore AS INT) IS NULL OR CAST(CreditScore AS INT) < 300 OR CAST(CreditScore AS INT) > 850;

-- DQ_04: unicidad del identificador del prestamo
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT LoanID, 'ID repetido ' + CAST(COUNT(*) AS VARCHAR(10)) + ' veces', 'DQ_04_UNICIDAD_LOANID'
FROM STG_Loan_Default
GROUP BY LoanID
HAVING COUNT(*) > 1;

-- DQ_05: ingreso anual numerico y mayor a 0
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT LoanID, 'Ingreso registrado: ' + ISNULL(Income, 'NULO'), 'DQ_05_VALIDEZ_INGRESO_POSITIVO'
FROM STG_Loan_Default
WHERE TRY_CAST(Income AS DECIMAL(12,2)) IS NULL OR TRY_CAST(Income AS DECIMAL(12,2)) <= 0;

-- DQ_06: monto del prestamo numerico y mayor a 0
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT LoanID, 'Monto registrado: ' + ISNULL(LoanAmount, 'NULO'), 'DQ_06_VALIDEZ_MONTO_POSITIVO'
FROM STG_Loan_Default
WHERE TRY_CAST(LoanAmount AS DECIMAL(12,2)) IS NULL OR TRY_CAST(LoanAmount AS DECIMAL(12,2)) <= 0;

-- DQ_07: ratio deuda/ingreso (DTI) entre 0 y 1
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT LoanID, 'DTI registrado: ' + ISNULL(DTIRatio, 'NULO'), 'DQ_07_RANGO_DTI_0_A_1'
FROM STG_Loan_Default
WHERE TRY_CAST(DTIRatio AS DECIMAL(5,2)) IS NULL
   OR TRY_CAST(DTIRatio AS DECIMAL(5,2)) < 0 OR TRY_CAST(DTIRatio AS DECIMAL(5,2)) > 1;

-- DQ_08: tasa de interes entre 0 y 50 %
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT LoanID, 'Tasa registrada: ' + ISNULL(InterestRate, 'NULO'), 'DQ_08_RANGO_TASA_INTERES'
FROM STG_Loan_Default
WHERE TRY_CAST(InterestRate AS DECIMAL(5,2)) IS NULL
   OR TRY_CAST(InterestRate AS DECIMAL(5,2)) <= 0 OR TRY_CAST(InterestRate AS DECIMAL(5,2)) > 50;

-- DQ_09: estado de impago solo puede ser 0 o 1
INSERT INTO QA_Rechazos_Financieros (LoanID, ValorInvalido, ReglaCalidad)
SELECT LoanID, 'Estado registrado: ' + ISNULL(DefaultStatus, 'NULO'), 'DQ_09_DOMINIO_ESTADO_IMPAGO'
FROM STG_Loan_Default
WHERE REPLACE(REPLACE(ISNULL(DefaultStatus, ''), CHAR(13), ''), ' ', '') NOT IN ('0', '1');
GO

-- Carga de la dimension de clientes
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

-- Carga de la tabla de hechos
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

-- Llave foranea entre hechos y dimension
ALTER TABLE Fact_Prestamos
ADD CONSTRAINT FK_Prestamos_Clientes FOREIGN KEY (ClienteID) REFERENCES Dim_Clientes_Financieros(ClienteID);
GO

-- Validacion de conteos (deben salir 255,347 filas en ambas)
SELECT 'Dim_Clientes' AS Tabla, COUNT(*) AS Total_Filas FROM Dim_Clientes_Financieros
UNION ALL
SELECT 'Fact_Prestamos' AS Tabla, COUNT(*) AS Total_Filas FROM Fact_Prestamos;
GO

-- Resumen de reglas de calidad (muestra tambien las reglas con 0 rechazos)
SELECT r.Regla, COUNT(q.RechazoID) AS Registros_Rechazados
FROM (VALUES
    ('DQ_01_COMPLETITUD_ID_REQUERIDO'),
    ('DQ_02_VALIDEZ_RANGO_EDAD'),
    ('DQ_03_CONSISTENCIA_SCORE_CREDIT_MERCADO'),
    ('DQ_04_UNICIDAD_LOANID'),
    ('DQ_05_VALIDEZ_INGRESO_POSITIVO'),
    ('DQ_06_VALIDEZ_MONTO_POSITIVO'),
    ('DQ_07_RANGO_DTI_0_A_1'),
    ('DQ_08_RANGO_TASA_INTERES'),
    ('DQ_09_DOMINIO_ESTADO_IMPAGO')
) AS r(Regla)
LEFT JOIN QA_Rechazos_Financieros q ON q.ReglaCalidad = r.Regla
GROUP BY r.Regla
ORDER BY r.Regla;
GO

-- Hallazgos: morosidad por proposito del prestamo
SELECT PropisitoPrestamo,
       COUNT(*) AS Total,
       SUM(CAST(EstadoImpago AS INT)) AS Impagos,
       CAST(100.0 * SUM(CAST(EstadoImpago AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS Tasa_Pct
FROM Fact_Prestamos
GROUP BY PropisitoPrestamo
ORDER BY Tasa_Pct DESC;

-- Hallazgos: morosidad por tipo de empleo
SELECT d.TipoEmpleo,
       COUNT(*) AS Total,
       CAST(100.0 * SUM(CAST(f.EstadoImpago AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS Tasa_Pct
FROM Fact_Prestamos f
JOIN Dim_Clientes_Financieros d ON d.ClienteID = f.ClienteID
GROUP BY d.TipoEmpleo
ORDER BY Tasa_Pct DESC;
GO