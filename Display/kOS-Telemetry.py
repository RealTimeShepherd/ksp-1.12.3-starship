import turtle
import pandas as pd

data = pd.read_csv("C:\\KSP_1.12.3\\Ships\\Script\\ksp-1.12.3-starship\\Telemetry\\sls_lto_earth_log.csv")
print(data.index)

pen = turtle.Turtle()

pen.setpos(50, 50)
pen.down()
pen.setpos(50, 100)
