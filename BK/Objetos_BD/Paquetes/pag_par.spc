create or replace package it.PAG_PAR as

--Author  : XPY0134 (SERGIO SERVÍN ARCE)
--Created : 07/05/2020 16:47:50 p.m.
--Purpose : Optmización de búsqueda de datos históricos para reversiones
--para manejo de parámetros para condición de vistas históricas
   G_REV_FECHA GE_MOVIMIENTOS.FECHA%type;
   G_REV_HORA GE_MOVIMIENTOS.HORA%type;
   G_REV_COD_USUARIO GE_MOVIMIENTOS.COD_USUARIO%TYPE;
   G_REV_REVERSADO GE_MOVIMIENTOS.REVERSADO%TYPE;
   G_REV_FECHA_INI GE_MOVIMIENTOS.FECHA%TYPE := to_date(nvl(fug_obt_pardinamico('FIL_FEC_GV_MOV'), sysdate-365), 'dd/mm/yyyy');
   G_REV_FECHA_INI_ATM GE_MOVIMIENTOS.FECHA%TYPE := to_date(nvl(fug_obt_pardinamico('FIL_FEC_GV_MOV_ATM'), sysdate-365), 'dd/mm/yyyy');
   
   
   procedure PR_SET_REV_COD_USUARIO(P_COD_USUARIO GE_MOVIMIENTOS.COD_USUARIO%type);
   procedure PR_SET_REV_FECHA(P_FECHA GE_MOVIMIENTOS.FECHA%type);
   procedure PR_SET_REV_HORA(P_HORA GE_MOVIMIENTOS.HORA%type);
   procedure PR_SET_REV_REVERSADO(P_REVERSADO GE_MOVIMIENTOS.REVERSADO%type);
   procedure PR_SET_REV_FECHA_INI(P_FECHA GE_MOVIMIENTOS.FECHA%type);
   procedure PR_SET_REV_FECHA_INI_ATM(P_FECHA GE_MOVIMIENTOS.FECHA%type);

   function FU_OBT_REV_COD_USUARIO return GE_MOVIMIENTOS.COD_USUARIO%type;
   function FU_OBT_REV_FECHA return GE_MOVIMIENTOS.FECHA%type;
   function FU_OBT_REV_HORA return GE_MOVIMIENTOS.HORA%type;
   function FU_OBT_REV_REVERSADO return GE_MOVIMIENTOS.REVERSADO%type;
   function FU_OBT_REV_FECHA_INI return GE_MOVIMIENTOS.FECHA%type;
   function FU_OBT_REV_FECHA_INI_ATM return GE_MOVIMIENTOS.FECHA%type;

end PAG_PAR;
/

