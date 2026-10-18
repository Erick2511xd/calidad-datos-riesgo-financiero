from pathlib import Path
import pandas as pd

carpeta_csv = Path(__file__).resolve().parent.parent / "csv"
ruta_origen = carpeta_csv / "Loan_default.csv"
ruta_destino = carpeta_csv / "Loan_default_Limpio.csv"

print("Iniciando limpieza con pandas...")

if not ruta_origen.exists():
    print(f"Error: no se encontró el archivo original en {ruta_origen}")
else:
    df = pd.read_csv(ruta_origen)
    df.to_csv(ruta_destino, sep='|', index=False)
    print("Proceso completado.")
    print(f"Archivo guardado en: {ruta_destino}")