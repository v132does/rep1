CREATE OR REPLACE TYPE IT."TYP_SNPPERIODO"                                          AS OBJECT
(
--Número de Tipo de Operación.
   codigoPeriodo NUMBER(2),
--Descripción del horario  
   descripcion VARCHAR2(50),
--Estado del horario. A=Abierto, C=Cerrado  
   estado VARCHAR2(1),
--Fecha del horario  
   fecha DATE,
--  Hora del Inicio del horario
   horaInicio VARCHAR2(8),
--  Hora del Fin del horario
   horaFin VARCHAR2(8),

   CONSTRUCTOR FUNCTION typ_SnpPeriodo RETURN SELF AS RESULT
)
/

