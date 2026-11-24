create or replace package body it.PAG_PAR as

   --SETEOS DE LOS PARAMETROS--
   procedure PR_SET_REV_COD_USUARIO(P_COD_USUARIO GE_MOVIMIENTOS.COD_USUARIO%type) as
   begin
      PAG_PAR.G_REV_COD_USUARIO := P_COD_USUARIO;
   end;

   procedure PR_SET_REV_FECHA(P_FECHA GE_MOVIMIENTOS.FECHA%type) as
   begin
      PAG_PAR.G_REV_FECHA := P_FECHA;
   end;

   procedure PR_SET_REV_HORA(P_HORA GE_MOVIMIENTOS.HORA%type) as
   begin
      PAG_PAR.G_REV_HORA := P_HORA;
   end;

   procedure PR_SET_REV_REVERSADO(P_REVERSADO GE_MOVIMIENTOS.REVERSADO%type) as
   begin
      PAG_PAR.G_REV_REVERSADO := P_REVERSADO;
   end;

   procedure PR_SET_REV_FECHA_INI(P_FECHA GE_MOVIMIENTOS.FECHA%type) as
   begin
      PAG_PAR.G_REV_FECHA_INI := P_FECHA;
   end;
   
   procedure PR_SET_REV_FECHA_INI_ATM(P_FECHA GE_MOVIMIENTOS.FECHA%type) as
   begin
      PAG_PAR.G_REV_FECHA_INI_ATM := P_FECHA;
   end;

   --GETTERS DE LOS PARÁMETROS--
   function FU_OBT_REV_COD_USUARIO return GE_MOVIMIENTOS.COD_USUARIO%type is
   begin
      return PAG_PAR.G_REV_COD_USUARIO;
   end;

   function FU_OBT_REV_FECHA return GE_MOVIMIENTOS.FECHA%type is
   begin
      return PAG_PAR.G_REV_FECHA;
   end;

   function FU_OBT_REV_HORA return GE_MOVIMIENTOS.HORA%type is
   begin
      return PAG_PAR.G_REV_HORA;
   end;

   function FU_OBT_REV_REVERSADO return GE_MOVIMIENTOS.REVERSADO%type is
   begin
      return PAG_PAR.G_REV_REVERSADO;
   end;

   function FU_OBT_REV_FECHA_INI return GE_MOVIMIENTOS.FECHA%type is
   begin
      return PAG_PAR.G_REV_FECHA_INI;
   end;
   
   function FU_OBT_REV_FECHA_INI_ATM return GE_MOVIMIENTOS.FECHA%type is
   begin
      return PAG_PAR.G_REV_FECHA_INI_ATM;
   end;
end PAG_PAR;
/

