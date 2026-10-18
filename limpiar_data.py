import pandas as pd

# 1. Leyendo el archivo imperfecto de Kaggle
print("Leyendo archivo original...")
df = pd.read_csv(r'C:\KaggleData\Loan_default.csv')

# 2. Guardando el nuevo archivo limpio separado por tuberías (|)
print("Alineando columnas y guardando...")
df.to_csv(r'C:\KaggleData\Loan_default_Limpio.csv', sep='|', index=False)

print("¡Proceso terminado con éxito!")
print("Archivo guardado en: C:\\KaggleData\\Loan_default_Limpio.csv")
