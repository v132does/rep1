CREATE OR REPLACE TYPE IT.typ_ge_par_dinamicos AS OBJECT (
    parametro        VARCHAR2(100),
    cod_modulo       NUMBER,
    cod_modalidad    NUMBER,
    cod_moneda       VARCHAR2(10),
    cod_oficina      NUMBER,
    cod_sub_modalidad NUMBER,
    val_parametro    VARCHAR2(4000)
)
/
